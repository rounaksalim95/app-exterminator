import Testing
import Foundation
@testable import app_exterminator

struct DeletedFileRecordTests {
    
    @Test func initializesFromDiscoveredFile() {
        let url = URL(fileURLWithPath: "/Applications/Test.app")
        let discovered = DiscoveredFile(url: url, category: .application, size: 1024)
        let record = DeletedFileRecord(from: discovered)
        
        #expect(record.id == discovered.id)
        #expect(record.originalPath == discovered.url.path)
        #expect(record.category == discovered.category)
        #expect(record.size == discovered.size)
    }
    
    @Test func formattedSizeReturnsHumanReadable() {
        let record = DeletedFileRecord(
            originalPath: "/test",
            category: .application,
            size: 1_048_576
        )
        
        #expect(record.formattedSize.contains("MB") || record.formattedSize.contains("1"))
    }
    
    @Test func codableConformance() throws {
        let original = DeletedFileRecord(
            originalPath: "/Applications/Test.app",
            category: .application,
            size: 2048
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeletedFileRecord.self, from: encoded)
        
        #expect(decoded.originalPath == original.originalPath)
        #expect(decoded.category == original.category)
        #expect(decoded.size == original.size)
    }
}

struct DeletionRecordTests {
    
    @Test func calculatesTotalSizeReclaimed() {
        let files = [
            DeletedFileRecord(originalPath: "/test1", category: .application, size: 1000),
            DeletedFileRecord(originalPath: "/test2", category: .caches, size: 2000),
            DeletedFileRecord(originalPath: "/test3", category: .preferences, size: 500)
        ]
        
        let record = DeletionRecord(
            appName: "Test App",
            bundleID: "com.test.app",
            deletedFiles: files
        )
        
        #expect(record.totalSizeReclaimed == 3500)
    }
    
    @Test func fileCountReturnsCorrectNumber() {
        let files = [
            DeletedFileRecord(originalPath: "/test1", category: .application, size: 1000),
            DeletedFileRecord(originalPath: "/test2", category: .caches, size: 2000)
        ]
        
        let record = DeletionRecord(
            appName: "Test App",
            bundleID: "com.test.app",
            deletedFiles: files
        )
        
        #expect(record.fileCount == 2)
    }
    
    @Test func formattedDateReturnsNonEmptyString() {
        let record = DeletionRecord(
            appName: "Test App",
            bundleID: "com.test.app",
            deletedFiles: []
        )
        
        #expect(!record.formattedDate.isEmpty)
    }
    
    @Test func formattedTotalSizeReturnsHumanReadable() {
        let files = [
            DeletedFileRecord(originalPath: "/test1", category: .application, size: 1_073_741_824)
        ]
        
        let record = DeletionRecord(
            appName: "Test App",
            bundleID: "com.test.app",
            deletedFiles: files
        )
        
        #expect(record.formattedTotalSize.contains("GB") || record.formattedTotalSize.contains("1"))
    }
    
    @Test func codableConformance() throws {
        let files = [
            DeletedFileRecord(originalPath: "/test", category: .application, size: 1024)
        ]
        
        let original = DeletionRecord(
            date: Date(),
            appName: "Test App",
            bundleID: "com.test.app",
            appIconData: nil,
            deletedFiles: files
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeletionRecord.self, from: encoded)
        
        #expect(decoded.appName == original.appName)
        #expect(decoded.bundleID == original.bundleID)
        #expect(decoded.deletedFiles.count == original.deletedFiles.count)
    }
    
    @Test @MainActor func equatableConformance() {
        let id = UUID()
        let files = [DeletedFileRecord(originalPath: "/test", category: .application, size: 100)]
        
        let record1 = DeletionRecord(id: id, appName: "Test", bundleID: "com.test", deletedFiles: files)
        let record2 = DeletionRecord(id: id, appName: "Test", bundleID: "com.test", deletedFiles: files)
        
        #expect(record1 == record2)
    }
}
