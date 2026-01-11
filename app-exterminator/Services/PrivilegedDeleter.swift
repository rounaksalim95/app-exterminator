import Foundation
import Security

enum PrivilegedDeletionError: LocalizedError {
    case authorizationFailed
    case authorizationCancelled
    case deletionFailed(path: String, reason: String)
    case scriptExecutionFailed(String)
    
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
        let escapedPath = path.replacingOccurrences(of: "'", with: "'\\''")
        
        let trashPath = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first!.path
        let fileName = file.url.lastPathComponent
        let destinationName = generateUniqueTrashName(fileName: fileName, trashPath: trashPath)
        let escapedDestination = "\(trashPath)/\(destinationName)".replacingOccurrences(of: "'", with: "'\\''")
        
        let script = "do shell script \"mv '\(escapedPath)' '\(escapedDestination)'\" with administrator privileges"
        
        try await runAppleScriptWithAuth(script: script)
    }
    
    private func generateUniqueTrashName(fileName: String, trashPath: String) -> String {
        let fileManager = FileManager.default
        var destinationName = fileName
        var counter = 1
        
        while fileManager.fileExists(atPath: "\(trashPath)/\(destinationName)") {
            let nameWithoutExt = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            if ext.isEmpty {
                destinationName = "\(nameWithoutExt) \(counter)"
            } else {
                destinationName = "\(nameWithoutExt) \(counter).\(ext)"
            }
            counter += 1
        }
        
        return destinationName
    }
    
    private func runAppleScriptWithAuth(script: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)
                    
                    if let error = error {
                        let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                        let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
                        
                        if errorNumber == -128 {
                            continuation.resume(throwing: PrivilegedDeletionError.authorizationCancelled)
                        } else {
                            continuation.resume(throwing: PrivilegedDeletionError.scriptExecutionFailed(errorMessage))
                        }
                    } else {
                        continuation.resume()
                    }
                } else {
                    continuation.resume(throwing: PrivilegedDeletionError.scriptExecutionFailed("Failed to create AppleScript"))
                }
            }
        }
    }
}
