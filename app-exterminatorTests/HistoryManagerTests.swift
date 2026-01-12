import Testing
import Foundation
@testable import app_exterminator

@Suite(.serialized)
struct HistoryManagerTests {
    
    @Test @MainActor func addsAndRetrievesRecords() async {
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
    
    @Test @MainActor func getMostRecentRecordReturnsLatest() async {
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
    
    @Test @MainActor func deletesRecordById() async {
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
    
    @Test @MainActor func clearsAllHistory() async {
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
    
    @Test @MainActor func createsRecordFromDeletionResult() async {
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
    
    @Test @MainActor func persistsAcrossLoadCycles() async {
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
    
    @Test @MainActor func getRecordByIdReturnsCorrectRecord() async {
        let manager = HistoryManager.shared
        
        await manager.clearHistory()
        
        let record1 = DeletionRecord(
            appName: "First App",
            bundleID: "com.first.app",
            deletedFiles: []
        )
        
        let record2 = DeletionRecord(
            appName: "Second App",
            bundleID: "com.second.app",
            deletedFiles: []
        )
        
        await manager.addRecord(record1)
        await manager.addRecord(record2)
        
        let foundRecord = await manager.getRecord(by: record1.id)
        #expect(foundRecord?.appName == "First App")
        #expect(foundRecord?.id == record1.id)
        
        await manager.clearHistory()
    }
    
    @Test @MainActor func getRecordByIdReturnsNilForUnknownId() async {
        let manager = HistoryManager.shared
        
        await manager.clearHistory()
        
        let unknownId = UUID()
        let foundRecord = await manager.getRecord(by: unknownId)
        #expect(foundRecord == nil)
    }
    
    @Test @MainActor func recordsAreSortedByDateDescending() async {
        let manager = HistoryManager.shared
        
        await manager.clearHistory()
        
        let oldRecord = DeletionRecord(
            date: Date().addingTimeInterval(-1000),
            appName: "Old App",
            bundleID: "com.old.app",
            deletedFiles: []
        )
        
        let newRecord = DeletionRecord(
            date: Date(),
            appName: "New App",
            bundleID: "com.new.app",
            deletedFiles: []
        )
        
        await manager.addRecord(oldRecord)
        await manager.addRecord(newRecord)
        
        let records = await manager.getAllRecords()
        #expect(records.first?.appName == "New App")
        
        await manager.clearHistory()
    }
    
    @Test @MainActor func multipleRecordsCanBeDeleted() async {
        let manager = HistoryManager.shared
        
        await manager.clearHistory()
        
        let record1 = DeletionRecord(appName: "App 1", bundleID: "com.app1", deletedFiles: [])
        let record2 = DeletionRecord(appName: "App 2", bundleID: "com.app2", deletedFiles: [])
        let record3 = DeletionRecord(appName: "App 3", bundleID: "com.app3", deletedFiles: [])
        
        await manager.addRecord(record1)
        await manager.addRecord(record2)
        await manager.addRecord(record3)
        
        var records = await manager.getAllRecords()
        let initialCount = records.count
        #expect(initialCount >= 3)
        
        await manager.deleteRecord(by: record2.id)
        
        records = await manager.getAllRecords()
        #expect(records.count == initialCount - 1)
        #expect(!records.contains { $0.id == record2.id })
        #expect(records.contains { $0.id == record1.id })
        #expect(records.contains { $0.id == record3.id })
        
        await manager.clearHistory()
    }
}
