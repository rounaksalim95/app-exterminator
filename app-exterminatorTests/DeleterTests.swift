import Testing
import Foundation
@testable import app_exterminator

struct DeletionResultTests {
    
    @Test func calculatesCorrectCounts() {
        let result = DeletionResult(
            successfulDeletions: [
                DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .application, size: 1000),
                DiscoveredFile(url: URL(fileURLWithPath: "/test2"), category: .caches, size: 2000),
            ],
            failedDeletions: [
                (file: DiscoveredFile(url: URL(fileURLWithPath: "/test3"), category: .preferences, size: 500), error: NSError(domain: "test", code: 1))
            ],
            skippedAdminFiles: [
                DiscoveredFile(url: URL(fileURLWithPath: "/test4"), category: .launchDaemons, size: 100, requiresAdmin: true)
            ]
        )
        
        #expect(result.totalDeleted == 2)
        #expect(result.totalFailed == 1)
        #expect(result.totalSkipped == 1)
    }
    
    @Test func calculatesSizeReclaimed() {
        let result = DeletionResult(
            successfulDeletions: [
                DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .application, size: 1000),
                DiscoveredFile(url: URL(fileURLWithPath: "/test2"), category: .caches, size: 2500),
            ],
            failedDeletions: [],
            skippedAdminFiles: []
        )
        
        #expect(result.sizeReclaimed == 3500)
    }
    
    @Test func isCompleteWhenNoFailuresOrSkips() {
        let completeResult = DeletionResult(
            successfulDeletions: [
                DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .application, size: 1000),
            ],
            failedDeletions: [],
            skippedAdminFiles: []
        )
        
        #expect(completeResult.isComplete == true)
        
        let incompleteResult = DeletionResult(
            successfulDeletions: [
                DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .application, size: 1000),
            ],
            failedDeletions: [],
            skippedAdminFiles: [
                DiscoveredFile(url: URL(fileURLWithPath: "/test2"), category: .launchDaemons, size: 100, requiresAdmin: true)
            ]
        )
        
        #expect(incompleteResult.isComplete == false)
    }
    
    @Test func formattedSizeReclaimedReturnsHumanReadable() {
        let result = DeletionResult(
            successfulDeletions: [
                DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .application, size: 1_048_576),
            ],
            failedDeletions: [],
            skippedAdminFiles: []
        )
        
        #expect(result.formattedSizeReclaimed.contains("MB") || result.formattedSizeReclaimed.contains("1"))
    }
}

struct DeleterTests {
    
    @Test func deletesFileSuccessfully() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_delete_\(UUID().uuidString).txt")
        
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: testFile.path))
        
        let file = DiscoveredFile(url: testFile, category: .other, size: 12)
        
        let deleter = Deleter()
        let result = await deleter.delete(files: [file])
        
        #expect(result.totalDeleted == 1)
        #expect(result.totalFailed == 0)
        #expect(!FileManager.default.fileExists(atPath: testFile.path))
    }
    
    @Test func skipsAdminFilesWhenRequested() async {
        let adminFile = DiscoveredFile(
            url: URL(fileURLWithPath: "/Library/LaunchDaemons/fake.plist"),
            category: .launchDaemons,
            size: 100,
            requiresAdmin: true
        )
        
        let deleter = Deleter()
        let result = await deleter.delete(files: [adminFile], skipAdminFiles: true)
        
        #expect(result.totalDeleted == 0)
        #expect(result.totalSkipped == 1)
        #expect(result.skippedAdminFiles.first?.url == adminFile.url)
    }
    
    @Test func handlesNonExistentFile() async {
        let nonExistent = DiscoveredFile(
            url: URL(fileURLWithPath: "/nonexistent/path/file.txt"),
            category: .other,
            size: 0
        )
        
        let deleter = Deleter()
        let result = await deleter.delete(files: [nonExistent])
        
        #expect(result.totalDeleted == 0)
        #expect(result.totalFailed == 1)
    }
    
    @Test func deletesDirectorySuccessfully() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_delete_dir_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let testFile = testDir.appendingPathComponent("file.txt")
        try "content".write(to: testFile, atomically: true, encoding: .utf8)
        
        #expect(FileManager.default.fileExists(atPath: testDir.path))
        
        let file = DiscoveredFile(url: testDir, category: .caches, size: 100)
        
        let deleter = Deleter()
        let result = await deleter.delete(files: [file])
        
        #expect(result.totalDeleted == 1)
        #expect(!FileManager.default.fileExists(atPath: testDir.path))
    }
    
    @Test func deletesMultipleFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile1 = tempDir.appendingPathComponent("multi_delete_1_\(UUID().uuidString).txt")
        let testFile2 = tempDir.appendingPathComponent("multi_delete_2_\(UUID().uuidString).txt")
        
        try "content1".write(to: testFile1, atomically: true, encoding: .utf8)
        try "content2".write(to: testFile2, atomically: true, encoding: .utf8)
        
        let files = [
            DiscoveredFile(url: testFile1, category: .other, size: 8),
            DiscoveredFile(url: testFile2, category: .other, size: 8),
        ]
        
        let deleter = Deleter()
        let result = await deleter.delete(files: files)
        
        #expect(result.totalDeleted == 2)
        #expect(!FileManager.default.fileExists(atPath: testFile1.path))
        #expect(!FileManager.default.fileExists(atPath: testFile2.path))
    }
}
