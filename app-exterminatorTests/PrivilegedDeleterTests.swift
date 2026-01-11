import Testing
import Foundation
@testable import app_exterminator

struct PrivilegedDeletionResultTests {
    
    @Test func calculatesCorrectCounts() {
        let result = PrivilegedDeletionResult(
            successfulDeletions: [
                DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .launchDaemons, size: 1000, requiresAdmin: true),
                DiscoveredFile(url: URL(fileURLWithPath: "/test2"), category: .launchAgents, size: 2000, requiresAdmin: true),
            ],
            failedDeletions: [
                (file: DiscoveredFile(url: URL(fileURLWithPath: "/test3"), category: .extensions, size: 500, requiresAdmin: true), 
                 error: PrivilegedDeletionError.deletionFailed(path: "/test3", reason: "test"))
            ]
        )
        
        #expect(result.totalDeleted == 2)
        #expect(result.totalFailed == 1)
    }
    
    @Test func calculatesSizeReclaimed() {
        let result = PrivilegedDeletionResult(
            successfulDeletions: [
                DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .launchDaemons, size: 1000, requiresAdmin: true),
                DiscoveredFile(url: URL(fileURLWithPath: "/test2"), category: .launchAgents, size: 2500, requiresAdmin: true),
            ],
            failedDeletions: []
        )
        
        #expect(result.sizeReclaimed == 3500)
    }
}

struct PrivilegedDeletionErrorTests {
    
    @Test func authorizationFailedErrorDescription() {
        let error = PrivilegedDeletionError.authorizationFailed
        #expect(error.errorDescription?.contains("administrator privileges") == true)
    }
    
    @Test func authorizationCancelledErrorDescription() {
        let error = PrivilegedDeletionError.authorizationCancelled
        #expect(error.errorDescription?.contains("cancelled") == true)
    }
    
    @Test func deletionFailedErrorDescription() {
        let error = PrivilegedDeletionError.deletionFailed(path: "/Library/test.plist", reason: "Permission denied")
        #expect(error.errorDescription?.contains("/Library/test.plist") == true)
        #expect(error.errorDescription?.contains("Permission denied") == true)
    }
    
    @Test func scriptExecutionFailedErrorDescription() {
        let error = PrivilegedDeletionError.scriptExecutionFailed("Script error")
        #expect(error.errorDescription?.contains("Script") == true)
    }
}

struct DeletionResultCombinedTests {
    
    @Test func combinesTwoResults() {
        let result1 = DeletionResult(
            successfulDeletions: [
                DiscoveredFile(url: URL(fileURLWithPath: "/user/file1"), category: .caches, size: 1000),
            ],
            failedDeletions: [],
            skippedAdminFiles: []
        )
        
        let result2 = DeletionResult(
            successfulDeletions: [
                DiscoveredFile(url: URL(fileURLWithPath: "/user/file2"), category: .preferences, size: 500),
            ],
            failedDeletions: [
                (file: DiscoveredFile(url: URL(fileURLWithPath: "/user/file3"), category: .logs, size: 100), 
                 error: NSError(domain: "test", code: 1))
            ],
            skippedAdminFiles: []
        )
        
        let combined = result1.combined(with: result2)
        
        #expect(combined.totalDeleted == 2)
        #expect(combined.totalFailed == 1)
        #expect(combined.sizeReclaimed == 1500)
    }
}

struct DeleterAdminIntegrationTests {
    
    @Test func separatesUserAndAdminFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let userFile = tempDir.appendingPathComponent("user_file_\(UUID().uuidString).txt")
        
        try "user content".write(to: userFile, atomically: true, encoding: .utf8)
        
        let userDiscovered = DiscoveredFile(url: userFile, category: .caches, size: 12, requiresAdmin: false)
        let adminDiscovered = DiscoveredFile(
            url: URL(fileURLWithPath: "/Library/FakeAdmin/file.plist"),
            category: .launchDaemons,
            size: 100,
            requiresAdmin: true
        )
        
        let deleter = Deleter()
        let result = await deleter.delete(files: [userDiscovered, adminDiscovered], includeAdminFiles: false)
        
        #expect(result.totalDeleted == 1)
        #expect(result.totalSkipped == 1)
        #expect(!FileManager.default.fileExists(atPath: userFile.path))
    }
}
