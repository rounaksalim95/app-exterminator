import AppKit
import Foundation

enum AppAnalyzerError: Error, LocalizedError {
    case notAnAppBundle
    case missingInfoPlist
    case missingBundleIdentifier
    case invalidBundle
    case isSystemApp(String)
    
    var errorDescription: String? {
        switch self {
        case .notAnAppBundle:
            return "The dropped item is not an application bundle."
        case .missingInfoPlist:
            return "The application bundle is missing its Info.plist file."
        case .missingBundleIdentifier:
            return "The application bundle does not have a valid bundle identifier."
        case .invalidBundle:
            return "The application bundle appears to be corrupted or invalid."
        case .isSystemApp(let name):
            return "\(name) is a protected system application and cannot be deleted."
        }
    }
}

struct AppAnalyzer {
    
    private static let systemAppPrefixes = [
        "/System/Applications/",
        "/System/Library/CoreServices/",
        "/System/Library/PreferencePanes/"
    ]
    
    private static let protectedBundleIDPrefixes = [
        "com.apple."
    ]
    
    private static let criticalBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.SystemPreferences",
        "com.apple.systempreferences",
        "com.apple.loginwindow",
        "com.apple.AppStore"
    ]
    
    static func analyze(appURL: URL) -> Result<TargetApplication, AppAnalyzerError> {
        guard appURL.pathExtension == "app" else {
            return .failure(.notAnAppBundle)
        }
        
        let infoPlistURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")
        
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            return .failure(.missingInfoPlist)
        }
        
        guard let plistData = NSDictionary(contentsOf: infoPlistURL) else {
            return .failure(.invalidBundle)
        }
        
        guard let bundleID = plistData["CFBundleIdentifier"] as? String, !bundleID.isEmpty else {
            return .failure(.missingBundleIdentifier)
        }
        
        let appName = extractAppName(from: plistData, url: appURL)
        let version = extractVersion(from: plistData)
        let icon = extractIcon(from: appURL)
        let isSystemApp = checkIfSystemApp(url: appURL, bundleID: bundleID)
        
        let app = TargetApplication(
            url: appURL,
            name: appName,
            bundleID: bundleID,
            version: version,
            icon: icon,
            isSystemApp: isSystemApp
        )
        
        return .success(app)
    }
    
    static func validateNotCriticalSystemApp(_ app: TargetApplication) -> Result<Void, AppAnalyzerError> {
        if criticalBundleIDs.contains(app.bundleID) {
            return .failure(.isSystemApp(app.name))
        }
        
        for prefix in systemAppPrefixes {
            if app.url.path.hasPrefix(prefix) {
                return .failure(.isSystemApp(app.name))
            }
        }
        
        return .success(())
    }
    
    private static func extractAppName(from plist: NSDictionary, url: URL) -> String {
        if let displayName = plist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
            return displayName
        }
        if let bundleName = plist["CFBundleName"] as? String, !bundleName.isEmpty {
            return bundleName
        }
        return url.deletingPathExtension().lastPathComponent
    }
    
    private static func extractVersion(from plist: NSDictionary) -> String? {
        if let shortVersion = plist["CFBundleShortVersionString"] as? String {
            if let buildVersion = plist["CFBundleVersion"] as? String, buildVersion != shortVersion {
                return "\(shortVersion) (\(buildVersion))"
            }
            return shortVersion
        }
        return plist["CFBundleVersion"] as? String
    }
    
    private static func extractIcon(from appURL: URL) -> NSImage? {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }
    
    private static func checkIfSystemApp(url: URL, bundleID: String) -> Bool {
        for prefix in systemAppPrefixes {
            if url.path.hasPrefix(prefix) {
                return true
            }
        }
        
        for prefix in protectedBundleIDPrefixes {
            if bundleID.hasPrefix(prefix) {
                return true
            }
        }
        
        return false
    }
}
