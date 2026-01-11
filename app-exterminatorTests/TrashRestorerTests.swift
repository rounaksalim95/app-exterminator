import Testing
import Foundation
@testable import app_exterminator

struct RestoreResultTests {
    
    @Test func calculatesCorrectCounts() {
        let result = RestoreResult(
            successfulRestores: [
                DeletedFileRecord(originalPath: "/test1", category: .application, size: 1000),
                DeletedFileRecord(originalPath: "/test2", category: .caches, size: 2000),
            ],
            failedRestores: [
                (file: DeletedFileRecord(originalPath: "/test3", category: .preferences, size: 500), 
                 error: RestoreError.permissionDenied(path: "/test3"))
            ],
            notInTrash: [
                DeletedFileRecord(originalPath: "/test4", category: .launchDaemons, size: 100)
            ]
        )
        
        #expect(result.totalRestored == 2)
        #expect(result.totalFailed == 1)
        #expect(result.totalNotInTrash == 1)
    }
    
    @Test func calculatesRestoredSize() {
        let result = RestoreResult(
            successfulRestores: [
                DeletedFileRecord(originalPath: "/test1", category: .application, size: 1000),
                DeletedFileRecord(originalPath: "/test2", category: .caches, size: 2500),
            ],
            failedRestores: [],
            notInTrash: []
        )
        
        #expect(result.restoredSize == 3500)
    }
    
    @Test func isCompleteWhenAllRestored() {
        let completeResult = RestoreResult(
            successfulRestores: [
                DeletedFileRecord(originalPath: "/test1", category: .application, size: 1000),
            ],
            failedRestores: [],
            notInTrash: []
        )
        
        #expect(completeResult.isComplete == true)
        
        let incompleteResult = RestoreResult(
            successfulRestores: [
                DeletedFileRecord(originalPath: "/test1", category: .application, size: 1000),
            ],
            failedRestores: [],
            notInTrash: [
                DeletedFileRecord(originalPath: "/test2", category: .caches, size: 100)
            ]
        )
        
        #expect(incompleteResult.isComplete == false)
    }
}

struct RestoreErrorTests {
    
    @Test func fileNotInTrashErrorDescription() {
        let error = RestoreError.fileNotInTrash(originalPath: "/path/to/MyApp.app")
        #expect(error.errorDescription?.contains("MyApp.app") == true)
        #expect(error.errorDescription?.contains("no longer in Trash") == true)
    }
    
    @Test func destinationOccupiedErrorDescription() {
        let error = RestoreError.destinationOccupied(path: "/Applications/MyApp.app")
        #expect(error.errorDescription?.contains("occupied") == true)
    }
    
    @Test func permissionDeniedErrorDescription() {
        let error = RestoreError.permissionDenied(path: "/Library/test")
        #expect(error.errorDescription?.contains("Permission denied") == true)
    }
    
    @Test func parentDirectoryMissingErrorDescription() {
        let error = RestoreError.parentDirectoryMissing(path: "/missing/parent/file.txt")
        #expect(error.errorDescription?.contains("Parent directory") == true)
    }
}

struct TrashRestorerTests {
    
    @Test func restoresFileSuccessfully() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("restore_test_\(UUID().uuidString).txt")
        
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: testFile.path))
        
        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: testFile, resultingItemURL: &trashedURL)
        #expect(!FileManager.default.fileExists(atPath: testFile.path))
        
        let record = DeletedFileRecord(originalPath: testFile.path, category: .other, size: 12)
        
        let restorer = TrashRestorer()
        let result = await restorer.restore(files: [record])
        
        #expect(result.totalRestored == 1)
        #expect(result.totalFailed == 0)
        #expect(result.totalNotInTrash == 0)
        #expect(FileManager.default.fileExists(atPath: testFile.path))
        
        try? FileManager.default.removeItem(at: testFile)
    }
    
    @Test func reportsFileNotInTrash() async {
        let nonExistent = DeletedFileRecord(
            originalPath: "/nonexistent/unique_\(UUID().uuidString)/file.txt",
            category: .other,
            size: 0
        )
        
        let restorer = TrashRestorer()
        let result = await restorer.restore(files: [nonExistent])
        
        #expect(result.totalRestored == 0)
        #expect(result.totalNotInTrash == 1)
    }
    
    @Test func reportsDestinationOccupied() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("occupied_test_\(UUID().uuidString).txt")
        
        try "original content".write(to: testFile, atomically: true, encoding: .utf8)
        
        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: testFile, resultingItemURL: &trashedURL)
        
        try "new content occupying location".write(to: testFile, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: testFile.path))
        
        let record = DeletedFileRecord(originalPath: testFile.path, category: .other, size: 12)
        
        let restorer = TrashRestorer()
        let result = await restorer.restore(files: [record])
        
        #expect(result.totalRestored == 0)
        #expect(result.totalFailed == 1)
        
        if let error = result.failedRestores.first?.error as? RestoreError,
           case .destinationOccupied = error {
        } else {
            Issue.record("Expected destinationOccupied error")
        }
        
        try? FileManager.default.removeItem(at: testFile)
        if let trashed = trashedURL as URL? {
            try? FileManager.default.removeItem(at: trashed)
        }
    }
    
    @Test func canRestoreReturnsTrueWhenFileInTrash() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("canrestore_test_\(UUID().uuidString).txt")
        
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: testFile, resultingItemURL: &trashedURL)
        
        let record = DeletedFileRecord(originalPath: testFile.path, category: .other, size: 12)
        
        let restorer = TrashRestorer()
        let canRestore = await restorer.canRestore(file: record)
        
        #expect(canRestore == true)
        
        if let trashed = trashedURL as URL? {
            try? FileManager.default.removeItem(at: trashed)
        }
    }
    
    @Test func canRestoreReturnsFalseWhenFileNotInTrash() async {
        let record = DeletedFileRecord(
            originalPath: "/nonexistent/unique_\(UUID().uuidString)/file.txt",
            category: .other,
            size: 0
        )
        
        let restorer = TrashRestorer()
        let canRestore = await restorer.canRestore(file: record)
        
        #expect(canRestore == false)
    }
    
    @Test func restoresMultipleFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString
        let testFile1 = tempDir.appendingPathComponent("multi_restore_1_\(uuid).txt")
        let testFile2 = tempDir.appendingPathComponent("multi_restore_2_\(uuid).txt")
        
        try "content1".write(to: testFile1, atomically: true, encoding: .utf8)
        try "content2".write(to: testFile2, atomically: true, encoding: .utf8)
        
        try FileManager.default.trashItem(at: testFile1, resultingItemURL: nil)
        try FileManager.default.trashItem(at: testFile2, resultingItemURL: nil)
        
        let records = [
            DeletedFileRecord(originalPath: testFile1.path, category: .other, size: 8),
            DeletedFileRecord(originalPath: testFile2.path, category: .other, size: 8),
        ]
        
        let restorer = TrashRestorer()
        let result = await restorer.restore(files: records)
        
        #expect(result.totalRestored == 2)
        #expect(FileManager.default.fileExists(atPath: testFile1.path))
        #expect(FileManager.default.fileExists(atPath: testFile2.path))
        
        try? FileManager.default.removeItem(at: testFile1)
        try? FileManager.default.removeItem(at: testFile2)
    }
    
    @Test func createsParentDirectoryIfMissing() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString
        let nestedDir = tempDir.appendingPathComponent("parent_\(uuid)")
        let testFile = nestedDir.appendingPathComponent("nested_file.txt")
        
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: testFile, resultingItemURL: &trashedURL)
        try FileManager.default.removeItem(at: nestedDir)
        
        #expect(!FileManager.default.fileExists(atPath: nestedDir.path))
        
        let record = DeletedFileRecord(originalPath: testFile.path, category: .other, size: 12)
        
        let restorer = TrashRestorer()
        let result = await restorer.restore(files: [record])
        
        #expect(result.totalRestored == 1)
        #expect(FileManager.default.fileExists(atPath: testFile.path))
        
        try? FileManager.default.removeItem(at: nestedDir)
    }
}
