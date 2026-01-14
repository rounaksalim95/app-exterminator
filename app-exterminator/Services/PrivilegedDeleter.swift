import Foundation
import Security
import os.log

private nonisolated(unsafe) let logger = Logger(subsystem: "com.appexterminator", category: "PrivilegedDeleter")

enum PrivilegedDeletionError: LocalizedError {
    case authorizationFailed
    case authorizationCancelled
    case deletionFailed(path: String, reason: String)
    case scriptExecutionFailed(String)
    case pathValidationFailed(String)
    case trashDirectoryNotFound

    var errorDescription: String? {
        switch self {
        case .authorizationFailed:
            return "Failed to obtain administrator privileges"
        case .authorizationCancelled:
            return "Administrator authentication was cancelled"
        case .deletionFailed(let path, let reason):
            return "Failed to delete \(path): \(reason)"
        case .scriptExecutionFailed(let reason):
            return "Script execution failed: \(reason)"
        case .pathValidationFailed(let reason):
            return "Path validation failed: \(reason)"
        case .trashDirectoryNotFound:
            return "Could not locate Trash directory"
        }
    }
}

struct PrivilegedDeletionResult {
    let successfulDeletions: [DiscoveredFile]
    let failedDeletions: [(file: DiscoveredFile, error: Error)]

    var totalDeleted: Int { successfulDeletions.count }
    var totalFailed: Int { failedDeletions.count }

    var sizeReclaimed: Int64 {
        successfulDeletions.reduce(0) { $0 + $1.size }
    }
}

actor PrivilegedDeleter {

    private let fileManager = FileManager.default

    // Whitelist of allowed directory prefixes for privileged deletion
    private var allowedPrefixes: [String] {
        let home = NSHomeDirectory()
        return [
            "/Applications/",
            "/Library/Application Support/",
            "/Library/Caches/",
            "/Library/Preferences/",
            "/Library/LaunchAgents/",
            "/Library/LaunchDaemons/",
            "/Library/Logs/",
            "/Library/Cookies/",
            "\(home)/Library/",
            "\(home)/Applications/"
        ]
    }

    func deleteWithPrivileges(files: [DiscoveredFile]) async throws -> PrivilegedDeletionResult {
        guard !files.isEmpty else {
            return PrivilegedDeletionResult(successfulDeletions: [], failedDeletions: [])
        }

        let authRef = try await requestAuthorization()
        defer {
            AuthorizationFree(authRef, [])
        }

        return await deleteFilesWithAuth(files: files, authRef: authRef)
    }

    private func requestAuthorization() async throws -> AuthorizationRef {
        var authRef: AuthorizationRef?

        var rights = AuthorizationRights(count: 0, items: nil)
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

        let status = AuthorizationCreate(&rights, nil, flags, &authRef)

        guard status == errAuthorizationSuccess, let auth = authRef else {
            if status == errAuthorizationCanceled {
                throw PrivilegedDeletionError.authorizationCancelled
            }
            throw PrivilegedDeletionError.authorizationFailed
        }

        return auth
    }

    private func deleteFilesWithAuth(files: [DiscoveredFile], authRef: AuthorizationRef) async -> PrivilegedDeletionResult {
        var successfulDeletions: [DiscoveredFile] = []
        var failedDeletions: [(file: DiscoveredFile, error: Error)] = []

        for file in files {
            do {
                try await deleteFileWithAuth(file: file, authRef: authRef)
                successfulDeletions.append(file)
            } catch {
                logger.error("Failed to delete \(file.url.path): \(error.localizedDescription)")
                failedDeletions.append((file: file, error: error))
            }
        }

        return PrivilegedDeletionResult(
            successfulDeletions: successfulDeletions,
            failedDeletions: failedDeletions
        )
    }

    private func deleteFileWithAuth(file: DiscoveredFile, authRef: AuthorizationRef) async throws {
        let path = file.url.path

        // Validate the path is safe before proceeding
        try validatePath(path)

        // Get trash directory safely (no force unwrap)
        guard let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first else {
            throw PrivilegedDeletionError.trashDirectoryNotFound
        }
        let trashPath = trashURL.path

        let fileName = file.url.lastPathComponent

        // Use base64 encoding for paths to avoid shell interpretation entirely
        guard let sourceBase64 = path.data(using: .utf8)?.base64EncodedString(),
              let fileNameBase64 = fileName.data(using: .utf8)?.base64EncodedString(),
              let trashBase64 = trashPath.data(using: .utf8)?.base64EncodedString() else {
            throw PrivilegedDeletionError.pathValidationFailed("Failed to encode paths")
        }

        // Build AppleScript that decodes base64 paths - this prevents any shell injection
        // The script finds a unique name in trash and moves the file atomically
        let script = """
        do shell script "
            src=\\\"$(echo '\(sourceBase64)' | base64 -d)\\\"
            trash=\\\"$(echo '\(trashBase64)' | base64 -d)\\\"
            fname=\\\"$(echo '\(fileNameBase64)' | base64 -d)\\\"
            dest=\\\"$trash/$fname\\\"
            counter=1
            name_no_ext=\\\"${fname%.*}\\\"
            ext=\\\"${fname##*.}\\\"
            if [ \\\"$name_no_ext\\\" = \\\"$fname\\\" ]; then ext=''; fi
            while [ -e \\\"$dest\\\" ]; do
                if [ -z \\\"$ext\\\" ] || [ \\\"$ext\\\" = \\\"$fname\\\" ]; then
                    dest=\\\"$trash/${fname} $counter\\\"
                else
                    dest=\\\"$trash/${name_no_ext} ${counter}.${ext}\\\"
                fi
                counter=$((counter + 1))
                if [ $counter -gt 1000 ]; then exit 1; fi
            done
            mv \\\"$src\\\" \\\"$dest\\\"
        " with administrator privileges
        """

        try await runAppleScriptWithAuth(script: script)
    }

    /// Validates that a path is safe for privileged deletion
    private func validatePath(_ path: String) throws {
        // Check for null bytes (can cause truncation attacks)
        guard !path.contains("\0") else {
            throw PrivilegedDeletionError.pathValidationFailed("Path contains null byte")
        }

        // Check for newlines (can break shell commands)
        guard !path.contains("\n") && !path.contains("\r") else {
            throw PrivilegedDeletionError.pathValidationFailed("Path contains newline")
        }

        // Resolve symlinks and normalize the path
        let resolvedPath = (path as NSString).resolvingSymlinksInPath
        let normalizedPath = (resolvedPath as NSString).standardizingPath

        // Check for path traversal attempts after normalization
        guard !normalizedPath.contains("/../") && !normalizedPath.hasSuffix("/..") else {
            throw PrivilegedDeletionError.pathValidationFailed("Path traversal detected")
        }

        // Verify the resolved path is under an allowed prefix
        let isAllowed = allowedPrefixes.contains { prefix in
            normalizedPath.hasPrefix(prefix)
        }

        guard isAllowed else {
            throw PrivilegedDeletionError.pathValidationFailed("Path is not in an allowed directory")
        }

        // Additional check: make sure the file actually exists
        guard fileManager.fileExists(atPath: path) else {
            throw PrivilegedDeletionError.deletionFailed(path: path, reason: "File does not exist")
        }
    }

    private func runAppleScriptWithAuth(script: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                throw PrivilegedDeletionError.scriptExecutionFailed("Failed to create AppleScript")
            }

            appleScript.executeAndReturnError(&error)

            if let error = error {
                let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0

                if errorNumber == -128 {
                    throw PrivilegedDeletionError.authorizationCancelled
                }
                throw PrivilegedDeletionError.scriptExecutionFailed(errorMessage)
            }
        }.value
    }
}
