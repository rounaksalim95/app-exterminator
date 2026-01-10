import Testing
import Foundation
@testable import app_exterminator

struct FileScannerTests {
    
    @Test func scanResultCalculatesTotalSize() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test",
            bundleID: "com.test.app"
        )
        
        let files = [
            DiscoveredFile(url: URL(fileURLWithPath: "/test1"), category: .application, size: 1000),
            DiscoveredFile(url: URL(fileURLWithPath: "/test2"), category: .caches, size: 2000),
            DiscoveredFile(url: URL(fileURLWithPath: "/test3"), category: .preferences, size: 500)
        ]
        
        let result = ScanResult(
            app: app,
            discoveredFiles: files,
            totalSize: 3500,
            scanDuration: 0.5
        )
        
        #expect(result.totalSize == 3500)
    }
    
    @Test func scannerFindsPreferencePlistByBundleID() async {
        let prefsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences")
        let testPlistURL = prefsDir.appendingPathComponent("com.testcompany.scannertest.plist")
        
        let plistData: [String: Any] = ["testKey": "testValue"]
        (plistData as NSDictionary).write(to: testPlistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testPlistURL) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/ScannerTest.app"),
            name: "Scanner Test",
            bundleID: "com.testcompany.scannertest"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let prefFiles = result.discoveredFiles.filter { $0.category == .preferences }
        #expect(prefFiles.contains { $0.url.lastPathComponent == "com.testcompany.scannertest.plist" })
    }
    
    @Test func scannerFindsContainerByBundleID() async {
        let containersDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")
        let testContainerDir = containersDir.appendingPathComponent("com.testcompany.containertest")
        
        try? FileManager.default.createDirectory(at: testContainerDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testContainerDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/ContainerTest.app"),
            name: "Container Test",
            bundleID: "com.testcompany.containertest"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let containerFiles = result.discoveredFiles.filter { $0.category == .containers }
        #expect(containerFiles.contains { $0.url.lastPathComponent == "com.testcompany.containertest" })
    }
    
    @Test func scannerFindsSavedStateByBundleID() async {
        let savedStateDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Saved Application State")
        let testStateDir = savedStateDir.appendingPathComponent("com.testcompany.statetest.savedState")
        
        try? FileManager.default.createDirectory(at: testStateDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testStateDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/StateTest.app"),
            name: "State Test",
            bundleID: "com.testcompany.statetest"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let stateFiles = result.discoveredFiles.filter { $0.category == .savedState }
        #expect(stateFiles.contains { $0.url.lastPathComponent == "com.testcompany.statetest.savedState" })
    }
    
    @Test func scanResultGroupsFilesByCategory() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test",
            bundleID: "com.test.app"
        )
        
        let files = [
            DiscoveredFile(url: URL(fileURLWithPath: "/app"), category: .application, size: 1000),
            DiscoveredFile(url: URL(fileURLWithPath: "/cache1"), category: .caches, size: 100),
            DiscoveredFile(url: URL(fileURLWithPath: "/cache2"), category: .caches, size: 200),
            DiscoveredFile(url: URL(fileURLWithPath: "/pref"), category: .preferences, size: 50)
        ]
        
        let result = ScanResult(
            app: app,
            discoveredFiles: files,
            totalSize: 1350,
            scanDuration: 0.1
        )
        
        let byCategory = result.filesByCategory
        
        #expect(byCategory[.application]?.count == 1)
        #expect(byCategory[.caches]?.count == 2)
        #expect(byCategory[.preferences]?.count == 1)
        #expect(byCategory[.logs] == nil)
    }
    
    @Test func scanResultFormattedTotalSize() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test",
            bundleID: "com.test.app"
        )
        
        let result = ScanResult(
            app: app,
            discoveredFiles: [],
            totalSize: 1_048_576,
            scanDuration: 0.1
        )
        
        #expect(result.formattedTotalSize.contains("MB") || result.formattedTotalSize.contains("1"))
    }
    
    @Test func scannerFindsAppBundle() async {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("ScannerTestApp.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.test.scannerapp",
            "CFBundleName": "Scanner Test App"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let app = TargetApplication(
            url: testAppURL,
            name: "Scanner Test App",
            bundleID: "com.test.scannerapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        #expect(result.discoveredFiles.count >= 1)
        #expect(result.discoveredFiles.first?.category == .application)
        #expect(result.discoveredFiles.first?.url == testAppURL)
    }
    
    @Test func scannerFindsCacheFiles() async {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches")
        let testCacheDir = cacheDir.appendingPathComponent("com.test.cacheapp")
        
        try? FileManager.default.createDirectory(at: testCacheDir, withIntermediateDirectories: true)
        
        let testFile = testCacheDir.appendingPathComponent("cache.db")
        try? "test data".write(to: testFile, atomically: true, encoding: .utf8)
        
        defer { try? FileManager.default.removeItem(at: testCacheDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/CacheApp.app"),
            name: "Cache App",
            bundleID: "com.test.cacheapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let cacheFiles = result.discoveredFiles.filter { $0.category == .caches }
        #expect(cacheFiles.contains { $0.url.path.contains("com.test.cacheapp") })
    }
    
    @Test func scannerFindsPreferenceFiles() async {
        let prefsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences")
        let testPlistURL = prefsDir.appendingPathComponent("com.test.prefapp.plist")
        
        let plistData: [String: Any] = ["testKey": "testValue"]
        (plistData as NSDictionary).write(to: testPlistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testPlistURL) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/PrefApp.app"),
            name: "Pref App",
            bundleID: "com.test.prefapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let prefFiles = result.discoveredFiles.filter { $0.category == .preferences }
        #expect(prefFiles.contains { $0.url.lastPathComponent == "com.test.prefapp.plist" })
    }
    
    @Test func scannerFindsApplicationSupportFiles() async {
        let appSupportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
        let testDir = appSupportDir.appendingPathComponent("TestSupportApp")
        
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let testFile = testDir.appendingPathComponent("data.json")
        try? "{}".write(to: testFile, atomically: true, encoding: .utf8)
        
        defer { try? FileManager.default.removeItem(at: testDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/TestSupportApp.app"),
            name: "TestSupportApp",
            bundleID: "com.test.supportapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let supportFiles = result.discoveredFiles.filter { $0.category == .applicationSupport }
        #expect(supportFiles.contains { $0.url.lastPathComponent == "TestSupportApp" })
    }
    
    @Test func scannerCalculatesFileSize() async {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("SizeTestApp.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.test.sizeapp",
            "CFBundleName": "Size Test App"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let app = TargetApplication(
            url: testAppURL,
            name: "Size Test App",
            bundleID: "com.test.sizeapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        #expect(result.totalSize > 0)
        
        if let appFile = result.discoveredFiles.first(where: { $0.category == .application }) {
            #expect(appFile.size > 0)
        }
    }
    
    @Test func scannerMatchesByAppName() async {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches")
        let testCacheDir = cacheDir.appendingPathComponent("MyTestApplication")
        
        try? FileManager.default.createDirectory(at: testCacheDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testCacheDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/My Test Application.app"),
            name: "My Test Application",
            bundleID: "com.different.bundleid"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let cacheFiles = result.discoveredFiles.filter { $0.category == .caches }
        #expect(cacheFiles.contains { $0.url.lastPathComponent == "MyTestApplication" })
    }
}
