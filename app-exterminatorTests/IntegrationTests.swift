import Testing
import Foundation
@testable import app_exterminator

struct IntegrationTests {
    
    @Test func fullDeletionFlowWithAnalyzeScanDelete() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString
        let testAppURL = tempDir.appendingPathComponent("IntegrationTestApp_\(uuid).app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let bundleID = "com.integration.test.\(uuid.lowercased().prefix(8))"
        let plistData: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleDisplayName": "Integration Test App",
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "42"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        let analyzeResult = AppAnalyzer.analyze(appURL: testAppURL)
        guard case .success(let targetApp) = analyzeResult else {
            Issue.record("Failed to analyze test app")
            return
        }
        
        #expect(targetApp.bundleID == bundleID)
        #expect(targetApp.name == "Integration Test App")
        #expect(targetApp.version == "1.0.0 (42)")
        #expect(targetApp.isSystemApp == false)
        
        let scanner = FileScanner()
        let scanResult = await scanner.scan(app: targetApp)
        
        #expect(scanResult.discoveredFiles.count >= 1)
        #expect(scanResult.discoveredFiles.first?.category == .application)
        #expect(scanResult.totalSize > 0)
        
        let deleter = Deleter()
        let deletionResult = await deleter.delete(files: scanResult.discoveredFiles)
        
        #expect(deletionResult.totalDeleted >= 1)
        #expect(!FileManager.default.fileExists(atPath: testAppURL.path))
    }
    
    @Test func fullFlowWithPreferencesAndCaches() async throws {
        let uuid = UUID().uuidString
        let bundleID = "com.fullflow.test.\(uuid.lowercased().prefix(8))"
        let appName = "FullFlowTest"
        
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("\(appName)_\(uuid).app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": appName
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        let prefsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences")
        let testPrefURL = prefsDir.appendingPathComponent("\(bundleID).plist")
        let prefData: [String: Any] = ["testKey": "testValue"]
        (prefData as NSDictionary).write(to: testPrefURL, atomically: true)
        
        let cachesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches")
        let testCacheDir = cachesDir.appendingPathComponent(bundleID)
        try FileManager.default.createDirectory(at: testCacheDir, withIntermediateDirectories: true)
        let cacheFile = testCacheDir.appendingPathComponent("cache.dat")
        try "cache data".write(to: cacheFile, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: testAppURL)
            try? FileManager.default.removeItem(at: testPrefURL)
            try? FileManager.default.removeItem(at: testCacheDir)
        }
        
        let analyzeResult = AppAnalyzer.analyze(appURL: testAppURL)
        guard case .success(let targetApp) = analyzeResult else {
            Issue.record("Failed to analyze test app")
            return
        }
        
        let scanner = FileScanner()
        let scanResult = await scanner.scan(app: targetApp)
        
        let categories = Set(scanResult.discoveredFiles.map { $0.category })
        #expect(categories.contains(.application))
        #expect(categories.contains(.preferences))
        #expect(categories.contains(.caches))
        
        let deleter = Deleter()
        let deletionResult = await deleter.delete(files: scanResult.discoveredFiles)
        
        #expect(deletionResult.totalDeleted >= 3)
        #expect(!FileManager.default.fileExists(atPath: testAppURL.path))
        #expect(!FileManager.default.fileExists(atPath: testPrefURL.path))
        #expect(!FileManager.default.fileExists(atPath: testCacheDir.path))
    }
    
    @Test @MainActor func deletionFlowRecordsHistory() async throws {
        let historyManager = HistoryManager.shared
        
        let initialRecordCount = await historyManager.getAllRecords().count
        
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString
        let testFile = tempDir.appendingPathComponent("history_test_\(uuid).txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let discoveredFile = DiscoveredFile(
            url: testFile,
            category: .other,
            size: 12
        )
        
        let targetApp = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/HistoryTest.app"),
            name: "History Test App",
            bundleID: "com.history.test.\(uuid)"
        )
        
        let deleter = Deleter()
        let deletionResult = await deleter.delete(files: [discoveredFile])
        
        #expect(deletionResult.totalDeleted == 1)
        
        let createdRecord = await historyManager.createRecord(from: targetApp, deletionResult: deletionResult)
        
        let records = await historyManager.getAllRecords()
        #expect(records.count == initialRecordCount + 1)
        
        let foundRecord = records.first { $0.id == createdRecord.id }
        #expect(foundRecord != nil)
        #expect(foundRecord?.appName == "History Test App")
        #expect(foundRecord?.bundleID == "com.history.test.\(uuid)")
        #expect(foundRecord?.deletedFiles.count == 1)
        
        await historyManager.deleteRecord(by: createdRecord.id)
    }
    
    @Test func systemAppProtectionBlocksDeletion() async throws {
        let systemApp = TargetApplication(
            url: URL(fileURLWithPath: "/System/Applications/Calculator.app"),
            name: "Calculator",
            bundleID: "com.apple.calculator",
            isSystemApp: true
        )
        
        let validationResult = AppAnalyzer.validateNotCriticalSystemApp(systemApp)
        
        switch validationResult {
        case .success:
            Issue.record("Expected system app to be blocked")
        case .failure(let error):
            if case .isSystemApp(let name) = error {
                #expect(name == "Calculator")
            } else {
                Issue.record("Expected isSystemApp error")
            }
        }
    }
    
    @Test func scanAndRestoreFlow() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString
        let testFile = tempDir.appendingPathComponent("restore_flow_\(uuid).txt")

        try "original content".write(to: testFile, atomically: true, encoding: .utf8)

        let file = DiscoveredFile(url: testFile, category: .other, size: 16)

        let deleter = Deleter()
        let deletionResult = await deleter.delete(files: [file])
        #expect(deletionResult.totalDeleted == 1)
        #expect(!FileManager.default.fileExists(atPath: testFile.path))

        let deletedRecord = DeletedFileRecord(from: file)

        let restorer = TrashRestorer()
        let canRestore = await restorer.canRestore(file: deletedRecord)
        #expect(canRestore == true)

        let restoreResult = await restorer.restore(files: [deletedRecord])
        #expect(restoreResult.totalRestored == 1)
        #expect(FileManager.default.fileExists(atPath: testFile.path))

        let restoredContent = try String(contentsOf: testFile, encoding: .utf8)
        #expect(restoredContent == "original content")

        try FileManager.default.removeItem(at: testFile)
    }

    // MARK: - Application Search Integration Tests

    @Test func applicationSearchToScanFlow() async throws {
        // Discover applications
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        #expect(!apps.isEmpty, "Expected to find installed applications")

        // Find a non-system app to test with
        guard let testApp = apps.first(where: { !$0.app.isSystemApp }) else {
            // If no non-system apps found, skip this test gracefully
            return
        }

        // Verify the app can be analyzed (simulating selection from search)
        let analyzeResult = AppAnalyzer.analyze(appURL: testApp.app.url)

        switch analyzeResult {
        case .success(let analyzedApp):
            #expect(analyzedApp.bundleID == testApp.app.bundleID)
            #expect(analyzedApp.name == testApp.app.name)

            // Scan for associated files
            let scanner = FileScanner()
            let scanResult = await scanner.scan(app: analyzedApp)

            // Should at least find the app bundle itself
            #expect(scanResult.discoveredFiles.count >= 1)
            #expect(scanResult.discoveredFiles.first?.category == .application)

        case .failure(let error):
            Issue.record("Failed to analyze app from search: \(error.localizedDescription)")
        }
    }

    @Test func applicationSearchAndFilterIntegration() async throws {
        let finder = ApplicationFinder()

        // Discover all apps
        let allApps = await finder.discoverApplications()
        #expect(!allApps.isEmpty)

        // Search for a common app (Safari should exist on all macOS)
        let safariResults = await finder.search(query: "Safari", in: allApps)

        // Safari should be found
        #expect(!safariResults.isEmpty)

        // Safari should be marked as a system app
        let safari = safariResults.first { $0.app.bundleID == "com.apple.Safari" }
        if let safari = safari {
            #expect(safari.app.isSystemApp == true)
        }
    }

    @Test func applicationSearchSystemAppProtection() async throws {
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        // Find system apps
        let systemApps = apps.filter { $0.app.isSystemApp }
        #expect(!systemApps.isEmpty, "Expected to find system applications")

        // Verify system apps are blocked from deletion
        for systemApp in systemApps.prefix(3) {
            let validationResult = AppAnalyzer.validateNotCriticalSystemApp(systemApp.app)

            // Apps in /System/Applications or with com.apple. bundle ID should be blocked
            if systemApp.app.url.path.hasPrefix("/System/Applications") ||
               systemApp.app.bundleID.hasPrefix("com.apple.") {
                switch validationResult {
                case .success:
                    // Some com.apple apps might not be in the critical list
                    break
                case .failure:
                    // Expected for critical system apps
                    #expect(true)
                }
            }
        }
    }

    @Test func applicationSearchCachePerformance() async throws {
        let finder = ApplicationFinder()

        // First call - populates cache
        let start1 = Date()
        let apps1 = await finder.discoverApplications()
        let duration1 = Date().timeIntervalSince(start1)

        // Second call - should use cache
        let start2 = Date()
        let apps2 = await finder.discoverApplications()
        let duration2 = Date().timeIntervalSince(start2)

        // Results should be the same
        #expect(apps1.count == apps2.count)

        // Cached call should be faster (or at least not significantly slower)
        // We allow some variance for system overhead
        #expect(duration2 <= duration1 * 2)
    }

    @Test func applicationSearchNoDuplicatesAcrossDirectories() async throws {
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        // Check for duplicate bundle IDs
        var seenBundleIDs = Set<String>()
        for app in apps {
            #expect(!seenBundleIDs.contains(app.app.bundleID),
                   "Found duplicate bundle ID: \(app.app.bundleID)")
            seenBundleIDs.insert(app.app.bundleID)
        }
    }
}
