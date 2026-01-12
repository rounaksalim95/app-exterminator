import Testing
import Foundation
@testable import app_exterminator

struct SizeCalculationTests {
    
    @Test func singleFileSize() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("size_test_\(UUID().uuidString).txt")
        
        let content = String(repeating: "a", count: 1000)
        try content.write(to: testFile, atomically: true, encoding: .utf8)
        
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        let file = DiscoveredFile(
            url: testFile,
            category: .other,
            size: try Int64(FileManager.default.attributesOfItem(atPath: testFile.path)[.size] as? UInt64 ?? 0)
        )
        
        #expect(file.size >= 1000)
    }
    
    @Test func directorySize() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("size_dir_test_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let file1 = testDir.appendingPathComponent("file1.txt")
        let file2 = testDir.appendingPathComponent("file2.txt")
        let file3 = testDir.appendingPathComponent("file3.txt")
        
        let content = String(repeating: "b", count: 500)
        try content.write(to: file1, atomically: true, encoding: .utf8)
        try content.write(to: file2, atomically: true, encoding: .utf8)
        try content.write(to: file3, atomically: true, encoding: .utf8)
        
        defer { try? FileManager.default.removeItem(at: testDir) }
        
        let app = TargetApplication(
            url: testDir,
            name: "Size Dir Test",
            bundleID: "com.size.dir.test"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let appFile = result.discoveredFiles.first { $0.category == .application }
        #expect(appFile != nil)
        #expect(appFile!.size >= 1500)
    }
    
    @Test func emptyDirectorySize() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("empty_dir_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testDir) }
        
        let app = TargetApplication(
            url: testDir,
            name: "Empty Dir Test",
            bundleID: "com.empty.dir.test"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let appFile = result.discoveredFiles.first { $0.category == .application }
        #expect(appFile != nil)
        #expect(appFile!.size == 0)
    }
    
    @Test func nestedDirectorySize() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("nested_dir_\(UUID().uuidString)")
        let nestedDir = testDir.appendingPathComponent("level1/level2")
        
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        
        let file1 = testDir.appendingPathComponent("root.txt")
        let file2 = testDir.appendingPathComponent("level1/mid.txt")
        let file3 = nestedDir.appendingPathComponent("deep.txt")
        
        let content = String(repeating: "c", count: 200)
        try content.write(to: file1, atomically: true, encoding: .utf8)
        try content.write(to: file2, atomically: true, encoding: .utf8)
        try content.write(to: file3, atomically: true, encoding: .utf8)
        
        defer { try? FileManager.default.removeItem(at: testDir) }
        
        let app = TargetApplication(
            url: testDir,
            name: "Nested Dir Test",
            bundleID: "com.nested.dir.test"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let appFile = result.discoveredFiles.first { $0.category == .application }
        #expect(appFile != nil)
        #expect(appFile!.size >= 600)
    }
    
    @Test func formattedSizeBytes() {
        let file = DiscoveredFile(
            url: URL(fileURLWithPath: "/test"),
            category: .other,
            size: 500
        )
        
        let formatted = file.formattedSize
        #expect(formatted.contains("bytes") || formatted.contains("B"))
    }
    
    @Test func formattedSizeKB() {
        let file = DiscoveredFile(
            url: URL(fileURLWithPath: "/test"),
            category: .other,
            size: 5_000
        )
        
        let formatted = file.formattedSize
        #expect(formatted.contains("KB") || formatted.contains("kB") || formatted.contains("K"))
    }
    
    @Test func formattedSizeMB() {
        let file = DiscoveredFile(
            url: URL(fileURLWithPath: "/test"),
            category: .other,
            size: 5_000_000
        )
        
        let formatted = file.formattedSize
        #expect(formatted.contains("MB") || formatted.contains("M"))
    }
    
    @Test func formattedSizeGB() {
        let file = DiscoveredFile(
            url: URL(fileURLWithPath: "/test"),
            category: .other,
            size: 5_000_000_000
        )
        
        let formatted = file.formattedSize
        #expect(formatted.contains("GB") || formatted.contains("G"))
    }
    
    @Test func zeroSizeFormat() {
        let file = DiscoveredFile(
            url: URL(fileURLWithPath: "/test"),
            category: .other,
            size: 0
        )
        
        let formatted = file.formattedSize
        #expect(formatted.contains("0") || formatted.contains("Zero"))
    }
    
    @Test func scanResultTotalSizeCalculation() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test",
            bundleID: "com.test.app"
        )
        
        let files = [
            DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .application, size: 1_000_000),
            DiscoveredFile(url: URL(fileURLWithPath: "/test2"), category: .caches, size: 500_000),
            DiscoveredFile(url: URL(fileURLWithPath: "/test3"), category: .preferences, size: 1_000),
            DiscoveredFile(url: URL(fileURLWithPath: "/test4"), category: .logs, size: 50_000)
        ]
        
        let result = ScanResult(
            app: app,
            discoveredFiles: files,
            totalSize: files.reduce(0) { $0 + $1.size },
            scanDuration: 0.1
        )
        
        #expect(result.totalSize == 1_551_000)
        #expect(result.formattedTotalSize.contains("MB") || result.formattedTotalSize.contains("1"))
    }
    
    @Test func deletionResultSizeReclaimed() {
        let files = [
            DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .application, size: 100_000_000),
            DiscoveredFile(url: URL(fileURLWithPath: "/test2"), category: .caches, size: 50_000_000),
        ]
        
        let result = DeletionResult(
            successfulDeletions: files,
            failedDeletions: [],
            skippedAdminFiles: []
        )
        
        #expect(result.sizeReclaimed == 150_000_000)
        #expect(result.formattedSizeReclaimed.contains("MB") || result.formattedSizeReclaimed.contains("150"))
    }
    
    @Test func restoreResultSizeCalculation() {
        let records = [
            DeletedFileRecord(originalPath: "/test1", category: .application, size: 200_000_000),
            DeletedFileRecord(originalPath: "/test2", category: .caches, size: 100_000_000),
        ]
        
        let result = RestoreResult(
            successfulRestores: records,
            failedRestores: [],
            notInTrash: []
        )
        
        #expect(result.restoredSize == 300_000_000)
        #expect(result.formattedRestoredSize.contains("MB") || result.formattedRestoredSize.contains("300"))
    }
    
    @Test func deletionRecordTotalSizeReclaimed() {
        let files = [
            DeletedFileRecord(originalPath: "/test1", category: .application, size: 1_073_741_824),
            DeletedFileRecord(originalPath: "/test2", category: .caches, size: 536_870_912),
        ]
        
        let record = DeletionRecord(
            appName: "Big App",
            bundleID: "com.big.app",
            deletedFiles: files
        )
        
        #expect(record.totalSizeReclaimed == 1_610_612_736)
        #expect(record.formattedTotalSize.contains("GB") || record.formattedTotalSize.contains("1"))
    }
}
