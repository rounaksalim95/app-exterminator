import Foundation

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
            } catch {
                failedDeletions.append((file: file, error: error))
            }
        }
        
        if includeAdminFiles && !adminFiles.isEmpty {
            do {
                let privilegedResult = try await privilegedDeleter.deleteWithPrivileges(files: adminFiles)
                successfulDeletions.append(contentsOf: privilegedResult.successfulDeletions)
                failedDeletions.append(contentsOf: privilegedResult.failedDeletions)
            } catch {
                for file in adminFiles {
                    failedDeletions.append((file: file, error: error))
                }
            }
        } else {
            skippedAdminFiles = adminFiles
        }
        
        return DeletionResult(
            successfulDeletions: successfulDeletions,
            failedDeletions: failedDeletions,
            skippedAdminFiles: skippedAdminFiles
        )
    }
    
    private func trashFile(_ file: DiscoveredFile) async throws {
        var resultingURL: NSURL?
        try fileManager.trashItem(at: file.url, resultingItemURL: &resultingURL)
    }
}
