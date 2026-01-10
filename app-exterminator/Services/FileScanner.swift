import Foundation

struct ScanResult {
    let app: TargetApplication
    let discoveredFiles: [DiscoveredFile]
    let totalSize: Int64
    let scanDuration: TimeInterval
    
    var filesByCategory: [FileCategory: [DiscoveredFile]] {
        Dictionary(grouping: discoveredFiles, by: { $0.category })
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

actor FileScanner {
    
    private struct ScanDirectory {
        let url: URL
        let category: FileCategory
        let requiresAdmin: Bool
        
        init(_ path: String, category: FileCategory, requiresAdmin: Bool = false) {
            self.url = URL(fileURLWithPath: path)
            self.category = category
            self.requiresAdmin = requiresAdmin
        }
        
        init(url: URL, category: FileCategory, requiresAdmin: Bool = false) {
            self.url = url
            self.category = category
            self.requiresAdmin = requiresAdmin
        }
    }
    
    private let fileManager = FileManager.default
    
    private var userLibrary: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library")
    }
    
    private var systemLibrary: URL {
        URL(fileURLWithPath: "/Library")
    }
    
    private var userDirectories: [ScanDirectory] {
        [
            ScanDirectory(url: userLibrary.appendingPathComponent("Application Support"), category: .applicationSupport),
            ScanDirectory(url: userLibrary.appendingPathComponent("Caches"), category: .caches),
            ScanDirectory(url: userLibrary.appendingPathComponent("Preferences"), category: .preferences),
            ScanDirectory(url: userLibrary.appendingPathComponent("Logs"), category: .logs),
            ScanDirectory(url: userLibrary.appendingPathComponent("Containers"), category: .containers),
            ScanDirectory(url: userLibrary.appendingPathComponent("Group Containers"), category: .containers),
            ScanDirectory(url: userLibrary.appendingPathComponent("Saved Application State"), category: .savedState),
            ScanDirectory(url: userLibrary.appendingPathComponent("HTTPStorages"), category: .caches),
            ScanDirectory(url: userLibrary.appendingPathComponent("WebKit"), category: .webKit),
            ScanDirectory(url: userLibrary.appendingPathComponent("Cookies"), category: .cookies),
            ScanDirectory(url: userLibrary.appendingPathComponent("LaunchAgents"), category: .launchAgents),
        ]
    }
    
    private var systemDirectories: [ScanDirectory] {
        [
            ScanDirectory(url: systemLibrary.appendingPathComponent("Application Support"), category: .applicationSupport, requiresAdmin: true),
            ScanDirectory(url: systemLibrary.appendingPathComponent("Caches"), category: .caches, requiresAdmin: true),
            ScanDirectory(url: systemLibrary.appendingPathComponent("Preferences"), category: .preferences, requiresAdmin: true),
            ScanDirectory(url: systemLibrary.appendingPathComponent("LaunchAgents"), category: .launchAgents, requiresAdmin: true),
            ScanDirectory(url: systemLibrary.appendingPathComponent("LaunchDaemons"), category: .launchDaemons, requiresAdmin: true),
            ScanDirectory(url: systemLibrary.appendingPathComponent("PrivilegedHelperTools"), category: .other, requiresAdmin: true),
        ]
    }
    
    private var extensionDirectories: [ScanDirectory] {
        [
            ScanDirectory("/Library/Extensions", category: .extensions, requiresAdmin: true),
            ScanDirectory("/Library/SystemExtensions", category: .extensions, requiresAdmin: true),
            ScanDirectory(url: userLibrary.appendingPathComponent("Safari/Extensions"), category: .extensions),
        ]
    }
    
    func scan(app: TargetApplication) async -> ScanResult {
        let startTime = Date()
        var discoveredFiles: [DiscoveredFile] = []
        
        let appFile = DiscoveredFile(
            url: app.url,
            category: .application,
            size: calculateSize(at: app.url),
            requiresAdmin: !fileManager.isWritableFile(atPath: app.url.path)
        )
        discoveredFiles.append(appFile)
        
        let allDirectories = userDirectories + systemDirectories + extensionDirectories
        
        for directory in allDirectories {
            let files = scanDirectory(directory, for: app)
            discoveredFiles.append(contentsOf: files)
        }
        
        let totalSize = discoveredFiles.reduce(0) { $0 + $1.size }
        let duration = Date().timeIntervalSince(startTime)
        
        return ScanResult(
            app: app,
            discoveredFiles: discoveredFiles,
            totalSize: totalSize,
            scanDuration: duration
        )
    }
    
    private func scanDirectory(_ directory: ScanDirectory, for app: TargetApplication) -> [DiscoveredFile] {
        var results: [DiscoveredFile] = []
        
        guard fileManager.fileExists(atPath: directory.url.path) else {
            return results
        }
        
        let searchTerms = buildSearchTerms(for: app)
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory.url,
                includingPropertiesForKeys: [.isDirectoryKey, .totalFileSizeKey, .totalFileAllocatedSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            for itemURL in contents {
                if matchesApp(itemURL: itemURL, searchTerms: searchTerms) {
                    let size = calculateSize(at: itemURL)
                    let requiresAdmin = directory.requiresAdmin || !fileManager.isWritableFile(atPath: itemURL.path)
                    
                    let file = DiscoveredFile(
                        url: itemURL,
                        category: directory.category,
                        size: size,
                        requiresAdmin: requiresAdmin
                    )
                    results.append(file)
                }
            }
        } catch {
            // Directory not accessible, skip silently
        }
        
        return results
    }
    
    private func buildSearchTerms(for app: TargetApplication) -> [String] {
        var terms: [String] = []
        
        terms.append(app.bundleID.lowercased())
        
        let bundleComponents = app.bundleID.components(separatedBy: ".")
        if bundleComponents.count >= 2 {
            let lastTwo = bundleComponents.suffix(2).joined(separator: ".")
            terms.append(lastTwo.lowercased())
        }
        if let lastComponent = bundleComponents.last {
            terms.append(lastComponent.lowercased())
        }
        
        let appNameLower = app.name.lowercased()
        terms.append(appNameLower)
        
        let appNameNoSpaces = appNameLower.replacingOccurrences(of: " ", with: "")
        if appNameNoSpaces != appNameLower {
            terms.append(appNameNoSpaces)
        }
        
        let appNameDashes = appNameLower.replacingOccurrences(of: " ", with: "-")
        if appNameDashes != appNameLower {
            terms.append(appNameDashes)
        }
        
        return Array(Set(terms))
    }
    
    private func matchesApp(itemURL: URL, searchTerms: [String]) -> Bool {
        let itemName = itemURL.lastPathComponent.lowercased()
        let itemNameWithoutExtension = itemURL.deletingPathExtension().lastPathComponent.lowercased()
        
        for term in searchTerms {
            if itemName.contains(term) || itemNameWithoutExtension.contains(term) {
                return true
            }
            
            if itemName == "\(term).plist" {
                return true
            }
        }
        
        return false
    }
    
    private func calculateSize(at url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }
        
        if isDirectory.boolValue {
            return calculateDirectorySize(at: url)
        } else {
            return calculateFileSize(at: url)
        }
    }
    
    private func calculateFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                let size = Int64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
                totalSize += size
            } catch {
                continue
            }
        }
        
        return totalSize
    }
}
