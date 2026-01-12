import Testing
import Foundation
@testable import app_exterminator

struct AppAnalyzerTests {
    
    @Test func analyzeRejectsNonAppExtension() {
        let url = URL(fileURLWithPath: "/Applications/SomeFile.txt")
        let result = AppAnalyzer.analyze(appURL: url)
        
        switch result {
        case .failure(let error):
            #expect(error == .notAnAppBundle)
        case .success:
            Issue.record("Expected failure for non-app extension")
        }
    }
    
    @Test func analyzeRejectsMissingInfoPlist() {
        let tempDir = FileManager.default.temporaryDirectory
        let fakeAppURL = tempDir.appendingPathComponent("FakeApp.app")
        
        try? FileManager.default.createDirectory(at: fakeAppURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fakeAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: fakeAppURL)
        
        switch result {
        case .failure(let error):
            #expect(error == .missingInfoPlist)
        case .success:
            Issue.record("Expected failure for missing Info.plist")
        }
    }
    
    @Test func analyzeRejectsMissingBundleIdentifier() {
        let tempDir = FileManager.default.temporaryDirectory
        let fakeAppURL = tempDir.appendingPathComponent("NoBundleID.app")
        let contentsURL = fakeAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleName": "Test App"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: fakeAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: fakeAppURL)
        
        switch result {
        case .failure(let error):
            #expect(error == .missingBundleIdentifier)
        case .success:
            Issue.record("Expected failure for missing bundle identifier")
        }
    }
    
    @Test func analyzeSucceedsWithValidBundle() {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("ValidTestApp.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.test.validapp",
            "CFBundleDisplayName": "Valid Test App",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "100"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: testAppURL)
        
        switch result {
        case .success(let app):
            #expect(app.bundleID == "com.test.validapp")
            #expect(app.name == "Valid Test App")
            #expect(app.version == "1.0 (100)")
            #expect(app.isSystemApp == false)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test func analyzeExtractsAppNameFromBundleName() {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("BundleNameApp.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.test.bundlename",
            "CFBundleName": "Bundle Name App"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: testAppURL)
        
        switch result {
        case .success(let app):
            #expect(app.name == "Bundle Name App")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test func analyzeDetectsSystemAppByBundleID() {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("AppleApp.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.apple.someapp",
            "CFBundleName": "Apple App"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: testAppURL)
        
        switch result {
        case .success(let app):
            #expect(app.isSystemApp == true)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test func validateNotCriticalSystemAppAllowsNonSystemApps() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/SomeApp.app"),
            name: "Some App",
            bundleID: "com.thirdparty.someapp"
        )
        
        let result = AppAnalyzer.validateNotCriticalSystemApp(app)
        
        switch result {
        case .success:
            #expect(true)
        case .failure:
            Issue.record("Expected non-system app to be allowed")
        }
    }
    
    @Test func validateNotCriticalSystemAppBlocksFinder() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/System/Applications/Finder.app"),
            name: "Finder",
            bundleID: "com.apple.finder",
            isSystemApp: true
        )
        
        let result = AppAnalyzer.validateNotCriticalSystemApp(app)
        
        switch result {
        case .success:
            Issue.record("Expected Finder to be blocked")
        case .failure(let error):
            if case .isSystemApp(let name) = error {
                #expect(name == "Finder")
            } else {
                Issue.record("Expected isSystemApp error")
            }
        }
    }
    
    @Test func validateNotCriticalSystemAppBlocksSystemApplicationsPath() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/System/Applications/Calculator.app"),
            name: "Calculator",
            bundleID: "com.apple.calculator",
            isSystemApp: true
        )
        
        let result = AppAnalyzer.validateNotCriticalSystemApp(app)
        
        switch result {
        case .success:
            Issue.record("Expected system path app to be blocked")
        case .failure:
            #expect(true)
        }
    }
    
    @Test func analyzeExtractsVersionWithBothVersionStrings() {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("VersionTestApp.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.test.versionapp",
            "CFBundleName": "Version Test App",
            "CFBundleShortVersionString": "2.1.0",
            "CFBundleVersion": "2100"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: testAppURL)
        
        switch result {
        case .success(let app):
            #expect(app.version == "2.1.0 (2100)")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test func analyzeExtractsVersionWithOnlyShortVersion() {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("ShortVersionApp.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.test.shortversion",
            "CFBundleName": "Short Version App",
            "CFBundleShortVersionString": "1.5.0"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: testAppURL)
        
        switch result {
        case .success(let app):
            #expect(app.version == "1.5.0")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test func analyzeExtractsVersionWithOnlyBuildVersion() {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("BuildVersionApp.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.test.buildversion",
            "CFBundleName": "Build Version App",
            "CFBundleVersion": "500"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: testAppURL)
        
        switch result {
        case .success(let app):
            #expect(app.version == "500")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test func analyzeReturnsNilVersionWhenNoVersionInfo() {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("NoVersionApp.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.test.noversion",
            "CFBundleName": "No Version App"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: testAppURL)
        
        switch result {
        case .success(let app):
            #expect(app.version == nil)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test func analyzeFallsBackToFilenameForAppName() {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("FilenameFallback.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.test.fallback"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: testAppURL)
        
        switch result {
        case .success(let app):
            #expect(app.name == "FilenameFallback")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
    
    @Test func analyzeDetectsSystemAppByCoreServicesPath() {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = URL(fileURLWithPath: "/System/Library/CoreServices/SomeApp.app")
        
        let app = TargetApplication(
            url: testAppURL,
            name: "Core Service App",
            bundleID: "com.thirdparty.app"
        )
        
        let result = AppAnalyzer.validateNotCriticalSystemApp(app)
        
        switch result {
        case .success:
            Issue.record("Expected CoreServices path app to be blocked")
        case .failure:
            #expect(true)
        }
    }
    
    @Test func validateNotCriticalSystemAppBlocksDock() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/System/Library/CoreServices/Dock.app"),
            name: "Dock",
            bundleID: "com.apple.dock",
            isSystemApp: true
        )
        
        let result = AppAnalyzer.validateNotCriticalSystemApp(app)
        
        switch result {
        case .success:
            Issue.record("Expected Dock to be blocked")
        case .failure(let error):
            if case .isSystemApp(let name) = error {
                #expect(name == "Dock")
            } else {
                Issue.record("Expected isSystemApp error")
            }
        }
    }
    
    @Test func validateNotCriticalSystemAppBlocksAppStore() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/System/Applications/App Store.app"),
            name: "App Store",
            bundleID: "com.apple.AppStore",
            isSystemApp: true
        )
        
        let result = AppAnalyzer.validateNotCriticalSystemApp(app)
        
        switch result {
        case .success:
            Issue.record("Expected App Store to be blocked")
        case .failure:
            #expect(true)
        }
    }
    
    @Test func errorDescriptionsAreNotEmpty() {
        let errors: [AppAnalyzerError] = [
            .notAnAppBundle,
            .missingInfoPlist,
            .missingBundleIdentifier,
            .invalidBundle,
            .isSystemApp("TestApp")
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
    
    @Test func analyzeSameVersionStringsDoNotDuplicate() {
        let tempDir = FileManager.default.temporaryDirectory
        let testAppURL = tempDir.appendingPathComponent("SameVersionApp.app")
        let contentsURL = testAppURL.appendingPathComponent("Contents")
        
        try? FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        
        let plistData: [String: Any] = [
            "CFBundleIdentifier": "com.test.sameversion",
            "CFBundleName": "Same Version App",
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "1.0.0"
        ]
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        (plistData as NSDictionary).write(to: plistURL, atomically: true)
        
        defer { try? FileManager.default.removeItem(at: testAppURL) }
        
        let result = AppAnalyzer.analyze(appURL: testAppURL)
        
        switch result {
        case .success(let app):
            #expect(app.version == "1.0.0")
            #expect(!app.version!.contains("("))
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
}

extension AppAnalyzerError: Equatable {
    public static func == (lhs: AppAnalyzerError, rhs: AppAnalyzerError) -> Bool {
        switch (lhs, rhs) {
        case (.notAnAppBundle, .notAnAppBundle),
             (.missingInfoPlist, .missingInfoPlist),
             (.missingBundleIdentifier, .missingBundleIdentifier),
             (.invalidBundle, .invalidBundle):
            return true
        case (.isSystemApp(let lhsName), .isSystemApp(let rhsName)):
            return lhsName == rhsName
        default:
            return false
        }
    }
}
