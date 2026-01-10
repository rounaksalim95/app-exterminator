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
}

actor Deleter {
    
    private let fileManager = FileManager.default
    
    func delete(
        files: [DiscoveredFile],
        skipAdminFiles: Bool = true
    ) async -> DeletionResult {
        var successfulDeletions: [DiscoveredFile] = []
        var failedDeletions: [(file: DiscoveredFile, error: Error)] = []
        var skippedAdminFiles: [DiscoveredFile] = []
        
        for file in files {
            if file.requiresAdmin && skipAdminFiles {
                skippedAdminFiles.append(file)
                continue
            }
            
            do {
                try await trashFile(file)
                successfulDeletions.append(file)
            } catch {
                failedDeletions.append((file: file, error: error))
            }
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
