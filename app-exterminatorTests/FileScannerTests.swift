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
    
    @Test func scannerFindsLogFiles() async {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
        let testLogDir = logsDir.appendingPathComponent("com.test.logapp")
        
        try? FileManager.default.createDirectory(at: testLogDir, withIntermediateDirectories: true)
        
        let testFile = testLogDir.appendingPathComponent("app.log")
        try? "log content".write(to: testFile, atomically: true, encoding: .utf8)
        
        defer { try? FileManager.default.removeItem(at: testLogDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/LogApp.app"),
            name: "Log App",
            bundleID: "com.test.logapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let logFiles = result.discoveredFiles.filter { $0.category == .logs }
        #expect(logFiles.contains { $0.url.path.contains("com.test.logapp") })
    }
    
    @Test func scannerFindsHTTPStorageFiles() async {
        let httpStorageDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/HTTPStorages")
        let testHttpDir = httpStorageDir.appendingPathComponent("com.test.httpapp")
        
        try? FileManager.default.createDirectory(at: testHttpDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testHttpDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/HTTPApp.app"),
            name: "HTTP App",
            bundleID: "com.test.httpapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let cacheFiles = result.discoveredFiles.filter { $0.category == .caches }
        #expect(cacheFiles.contains { $0.url.path.contains("com.test.httpapp") })
    }
    
    @Test func scannerFindsWebKitFiles() async {
        let webKitDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/WebKit")
        let testWebKitDir = webKitDir.appendingPathComponent("com.test.webkitapp")
        
        try? FileManager.default.createDirectory(at: testWebKitDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testWebKitDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/WebKitApp.app"),
            name: "WebKit App",
            bundleID: "com.test.webkitapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let webKitFiles = result.discoveredFiles.filter { $0.category == .webKit }
        #expect(webKitFiles.contains { $0.url.path.contains("com.test.webkitapp") })
    }
    
    @Test func scannerFindsCookieFiles() async {
        let cookiesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Cookies")
        
        try? FileManager.default.createDirectory(at: cookiesDir, withIntermediateDirectories: true)
        
        let testCookieDir = cookiesDir.appendingPathComponent("com.test.cookieapp")
        try? FileManager.default.createDirectory(at: testCookieDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testCookieDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/CookieApp.app"),
            name: "Cookie App",
            bundleID: "com.test.cookieapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let cookieFiles = result.discoveredFiles.filter { $0.category == .cookies }
        #expect(cookieFiles.contains { $0.url.path.contains("com.test.cookieapp") })
    }
    
    @Test func scannerMatchesByAppNameWithDashes() async {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches")
        let testCacheDir = cacheDir.appendingPathComponent("my-test-app")
        
        try? FileManager.default.createDirectory(at: testCacheDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testCacheDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/My Test App.app"),
            name: "My Test App",
            bundleID: "com.test.myapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let cacheFiles = result.discoveredFiles.filter { $0.category == .caches }
        #expect(cacheFiles.contains { $0.url.lastPathComponent == "my-test-app" })
    }
    
    @Test func scannerMatchesByAppNameWithUnderscores() async {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches")
        let testCacheDir = cacheDir.appendingPathComponent("my_test_app")
        
        try? FileManager.default.createDirectory(at: testCacheDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testCacheDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/My Test App.app"),
            name: "My Test App",
            bundleID: "com.test.myapp2"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let cacheFiles = result.discoveredFiles.filter { $0.category == .caches }
        #expect(cacheFiles.contains { $0.url.lastPathComponent == "my_test_app" })
    }
    
    @Test func scannerMatchesByOrganizationName() async {
        let appSupportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
        let testDir = appSupportDir.appendingPathComponent("Acmecorp")
        
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Acmecorp Tool.app"),
            name: "Acmecorp Tool",
            bundleID: "com.acmecorp.tool"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let supportFiles = result.discoveredFiles.filter { $0.category == .applicationSupport }
        #expect(supportFiles.contains { $0.url.lastPathComponent == "Acmecorp" })
    }
    
    @Test func scannerFindsGroupContainers() async {
        let groupContainersDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers")
        let testGroupDir = groupContainersDir.appendingPathComponent("group.com.test.groupapp")
        
        try? FileManager.default.createDirectory(at: testGroupDir, withIntermediateDirectories: true)
        
        defer { try? FileManager.default.removeItem(at: testGroupDir) }
        
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/GroupApp.app"),
            name: "Group App",
            bundleID: "com.test.groupapp"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        let containerFiles = result.discoveredFiles.filter { $0.category == .containers }
        #expect(containerFiles.contains { $0.url.path.contains("groupapp") })
    }
    
    @Test func scannerCalculatesScanDuration() async {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/NonExistent.app"),
            name: "Non Existent",
            bundleID: "com.nonexistent.app"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        #expect(result.scanDuration >= 0)
    }
    
    @Test func scannerHandlesMissingDirectories() async {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/MissingDirs.app"),
            name: "Missing Dirs App",
            bundleID: "com.nonexistent.missingdirs.uniquetest12345"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        #expect(result.discoveredFiles.isEmpty || result.discoveredFiles.first?.category == .application)
    }
    
    @Test func scannerMarksSystemFilesAsRequiringAdmin() async {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/AdminTest.app"),
            name: "Admin Test",
            bundleID: "com.test.admintest"
        )
        
        let scanner = FileScanner()
        let result = await scanner.scan(app: app)
        
        for file in result.discoveredFiles {
            if file.url.path.hasPrefix("/Library/") {
                #expect(file.requiresAdmin == true)
            }
        }
    }
}
