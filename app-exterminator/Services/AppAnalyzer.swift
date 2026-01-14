import AppKit
import Foundation
import Security
import os.log

private nonisolated(unsafe) let logger = Logger(subsystem: "com.appexterminator", category: "AppAnalyzer")

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

        // Verify code signature integrity (not identity) - warn if tampered
        if case .failure = verifyCodeSignatureIntegrity(at: appURL) {
            logger.warning("App at \(appURL.path) has an invalid or tampered code signature")
            // We continue anyway, but log the warning - user can decide
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

    /// Analyze app without extracting icon (faster for bulk discovery)
    static func analyzeWithoutIcon(appURL: URL) -> Result<TargetApplication, AppAnalyzerError> {
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
        let isSystemApp = checkIfSystemApp(url: appURL, bundleID: bundleID)

        let app = TargetApplication(
            url: appURL,
            name: appName,
            bundleID: bundleID,
            version: version,
            icon: nil,  // Defer icon loading
            isSystemApp: isSystemApp
        )

        return .success(app)
    }

    /// Load icon for an app URL (call from UI layer for lazy loading)
    static func loadIcon(for appURL: URL) -> NSImage? {
        extractIcon(from: appURL)
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

    /// Verifies code signature integrity (not identity) to detect tampered bundles
    /// - Parameter url: URL of the app bundle
    /// - Returns: Success if signature is valid or app is unsigned, failure if signature is tampered
    private static func verifyCodeSignatureIntegrity(at url: URL) -> Result<Void, AppAnalyzerError> {
        var staticCode: SecStaticCode?
        let createResult = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)

        // If we can't create a static code reference, the app might be unsigned
        // Unsigned apps are allowed (many legitimate apps are unsigned)
        guard createResult == errSecSuccess, let code = staticCode else {
            logger.debug("App at \(url.path) has no code signature (unsigned)")
            return .success(())
        }

        // Validate the signature integrity (not identity)
        // We're checking if the signature is valid, not who signed it
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures)
        let validateResult = SecStaticCodeCheckValidity(code, flags, nil)

        switch validateResult {
        case errSecSuccess:
            logger.debug("Code signature valid for \(url.path)")
            return .success(())
        case errSecCSSignatureFailed, errSecCSSignatureInvalid:
            // Signature exists but is invalid/tampered
            logger.warning("Code signature INVALID for \(url.path) - possible tampering")
            return .failure(.invalidBundle)
        default:
            // Other errors (e.g., resource issues) - allow but log
            logger.debug("Code signature check returned \(validateResult) for \(url.path)")
            return .success(())
        }
    }
}
