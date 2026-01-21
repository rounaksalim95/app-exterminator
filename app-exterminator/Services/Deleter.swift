import Foundation
import os.log

private enum Log: Sendable {
    nonisolated static let logger = Logger(subsystem: "com.appexterminator", category: "Deleter")
}

enum DeletionError: LocalizedError {
    case verificationFailed(path: String, reason: String)
    case trashFailed(path: String, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .verificationFailed(let path, let reason):
            return "Failed to verify deletion of \(path): \(reason)"
        case .trashFailed(let path, let underlyingError):
            return "Failed to move \(path) to trash: \(underlyingError.localizedDescription)"
        }
    }
}

struct DeletionResult {
    let successfulDeletions: [DiscoveredFile]
    let failedDeletions: [(file: DiscoveredFile, error: Error)]
    let skippedAdminFiles: [DiscoveredFile]

    var totalDeleted: Int {
        successfulDeletions.count
    }

    var totalFailed: Int {
        failedDeletions.count
    }

    var totalSkipped: Int {
        skippedAdminFiles.count
    }

    var sizeReclaimed: Int64 {
        successfulDeletions.reduce(0) { $0 + $1.size }
    }

    var formattedSizeReclaimed: String {
        ByteCountFormatter.string(fromByteCount: sizeReclaimed, countStyle: .file)
    }

    var isComplete: Bool {
        failedDeletions.isEmpty && skippedAdminFiles.isEmpty
    }

    func combined(with other: DeletionResult) -> DeletionResult {
        DeletionResult(
            successfulDeletions: successfulDeletions + other.successfulDeletions,
            failedDeletions: failedDeletions + other.failedDeletions,
            skippedAdminFiles: skippedAdminFiles + other.skippedAdminFiles
        )
    }
}

actor Deleter {

    private let fileManager = FileManager.default
    private let privilegedDeleter = PrivilegedDeleter()

    func delete(
        files: [DiscoveredFile],
        includeAdminFiles: Bool = false
    ) async -> DeletionResult {
        let userFiles = files.filter { !$0.requiresAdmin }
        let adminFiles = files.filter { $0.requiresAdmin }

        var successfulDeletions: [DiscoveredFile] = []
        var failedDeletions: [(file: DiscoveredFile, error: Error)] = []
        var skippedAdminFiles: [DiscoveredFile] = []

        for file in userFiles {
            do {
                try await trashFile(file)
                successfulDeletions.append(file)
                Log.logger.info("Successfully trashed: \(file.url.path)")
            } catch {
                Log.logger.error("Failed to trash \(file.url.path): \(error.localizedDescription)")
                failedDeletions.append((file: file, error: error))
            }
        }

        if includeAdminFiles && !adminFiles.isEmpty {
            do {
                let privilegedResult = try await privilegedDeleter.deleteWithPrivileges(files: adminFiles)
                successfulDeletions.append(contentsOf: privilegedResult.successfulDeletions)
                failedDeletions.append(contentsOf: privilegedResult.failedDeletions)
            } catch {
                Log.logger.error("Privileged deletion failed: \(error.localizedDescription)")
                for file in adminFiles {
                    failedDeletions.append((file: file, error: error))
                }
            }
        } else {
            skippedAdminFiles = adminFiles
        }

        Log.logger.info("Deletion complete: \(successfulDeletions.count) succeeded, \(failedDeletions.count) failed, \(skippedAdminFiles.count) skipped")

        return DeletionResult(
            successfulDeletions: successfulDeletions,
            failedDeletions: failedDeletions,
            skippedAdminFiles: skippedAdminFiles
        )
    }

    private func trashFile(_ file: DiscoveredFile) async throws {
        let originalPath = file.url.path

        // Verify the file exists before attempting to trash
        guard fileManager.fileExists(atPath: originalPath) else {
            throw DeletionError.verificationFailed(path: originalPath, reason: "File does not exist")
        }

        var resultingURL: NSURL?
        do {
            try fileManager.trashItem(at: file.url, resultingItemURL: &resultingURL)
        } catch {
            throw DeletionError.trashFailed(path: originalPath, underlyingError: error)
        }

        // Verify the file was actually moved
        guard let trashURL = resultingURL as URL? else {
            throw DeletionError.verificationFailed(
                path: originalPath,
                reason: "Trash operation returned no destination URL"
            )
        }

        // Verify file exists at new location
        guard fileManager.fileExists(atPath: trashURL.path) else {
            throw DeletionError.verificationFailed(
                path: originalPath,
                reason: "File not found at trash location"
            )
        }

        // Verify file no longer exists at original location
        guard !fileManager.fileExists(atPath: originalPath) else {
            throw DeletionError.verificationFailed(
                path: originalPath,
                reason: "File still exists at original location after trash"
            )
        }
    }
}
