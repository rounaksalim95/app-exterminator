import Testing
import Foundation
@testable import app_exterminator

struct HistoryManagerTests {
    
    @Test func addsAndRetrievesRecords() async {
        let manager = HistoryManager.shared
        
        await manager.clearHistory()
        
        let record = DeletionRecord(
            appName: "Test App",
            bundleID: "com.test.app",
            deletedFiles: [
                DeletedFileRecord(originalPath: "/test/path", category: .application, size: 1000)
            ]
        )
        
        await manager.addRecord(record)
        
        let records = await manager.getAllRecords()
        #expect(records.count >= 1)
        #expect(records.first?.appName == "Test App")
        
        await manager.clearHistory()
    }
    
    @Test func getMostRecentRecordReturnsLatest() async {
        let manager = HistoryManager.shared
        
        await manager.clearHistory()
        
        let record1 = DeletionRecord(
            date: Date().addingTimeInterval(-100),
            appName: "Old App",
            bundleID: "com.old.app",
            deletedFiles: []
        )
        
        let record2 = DeletionRecord(
            date: Date(),
            appName: "New App",
            bundleID: "com.new.app",
            deletedFiles: []
        )
        
        await manager.addRecord(record1)
        await manager.addRecord(record2)
        
        let mostRecent = await manager.getMostRecentRecord()
        #expect(mostRecent?.appName == "New App")
        
        await manager.clearHistory()
    }
    
    @Test func deletesRecordById() async {
        let manager = HistoryManager.shared
        
        await manager.clearHistory()
        
        let record = DeletionRecord(
            appName: "Delete Me",
            bundleID: "com.delete.me",
            deletedFiles: []
        )
        
        await manager.addRecord(record)
        
        var records = await manager.getAllRecords()
        #expect(records.contains { $0.id == record.id })
        
        await manager.deleteRecord(by: record.id)
        
        records = await manager.getAllRecords()
        #expect(!records.contains { $0.id == record.id })
    }
    
    @Test func clearsAllHistory() async {
        let manager = HistoryManager.shared
        
        let record = DeletionRecord(
            appName: "Test",
            bundleID: "com.test",
            deletedFiles: []
        )
        
        await manager.addRecord(record)
        await manager.clearHistory()
        
        let records = await manager.getAllRecords()
        #expect(records.isEmpty)
    }
    
    @Test func createsRecordFromDeletionResult() async {
        let manager = HistoryManager.shared
        
        await manager.clearHistory()
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test App",
            bundleID: "com.test.app"
        )
        
        let deletionResult = DeletionResult(
            successfulDeletions: [
                DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .application, size: 1000),
                DiscoveredFile(url: URL(fileURLWithPath: "/test2"), category: .caches, size: 500)
            ],
            failedDeletions: [],
            skippedAdminFiles: []
        )
        
        let record = await manager.createRecord(from: app, deletionResult: deletionResult)
        
        #expect(record.appName == "Test App")
        #expect(record.bundleID == "com.test.app")
        #expect(record.deletedFiles.count == 2)
        #expect(record.totalSizeReclaimed == 1500)
        
        await manager.clearHistory()
    }
    
    @Test func persistsAcrossLoadCycles() async {
        let manager = HistoryManager.shared
        
        await manager.clearHistory()
        
        let record = DeletionRecord(
            appName: "Persistent App",
            bundleID: "com.persistent.app",
            deletedFiles: []
        )
        
        await manager.addRecord(record)
        
        await manager.load()
        
        let records = await manager.getAllRecords()
        #expect(records.contains { $0.appName == "Persistent App" })
        
        await manager.clearHistory()
    }
}
