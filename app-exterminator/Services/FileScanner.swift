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

struct FileScanner {
    
    private struct ScanDirectory {
        let path: String
        let category: FileCategory
        let requiresAdmin: Bool
    }
    
    func scan(app: TargetApplication) async -> ScanResult {
        let startTime = Date()
        var discoveredFiles: [DiscoveredFile] = []
        let fileManager = FileManager.default
        
        let appFile = DiscoveredFile(
            url: app.url,
            category: .application,
            size: calculateSize(at: app.url, fileManager: fileManager),
            requiresAdmin: !fileManager.isWritableFile(atPath: app.url.path)
        )
        discoveredFiles.append(appFile)
        
        let searchTerms = buildSearchTerms(for: app)
        let directories = getAllDirectories()
        
        for directory in directories {
            let files = scanDirectory(directory, searchTerms: searchTerms, fileManager: fileManager)
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
    
    private func getAllDirectories() -> [ScanDirectory] {
        let home = NSHomeDirectory()
        let userLibrary = "\(home)/Library"
        
        var directories: [ScanDirectory] = []
        
        // User directories
        directories.append(ScanDirectory(path: "\(userLibrary)/Application Support", category: .applicationSupport, requiresAdmin: false))
        directories.append(ScanDirectory(path: "\(userLibrary)/Caches", category: .caches, requiresAdmin: false))
        directories.append(ScanDirectory(path: "\(userLibrary)/Preferences", category: .preferences, requiresAdmin: false))
        directories.append(ScanDirectory(path: "\(userLibrary)/Logs", category: .logs, requiresAdmin: false))
        directories.append(ScanDirectory(path: "\(userLibrary)/Containers", category: .containers, requiresAdmin: false))
        directories.append(ScanDirectory(path: "\(userLibrary)/Group Containers", category: .containers, requiresAdmin: false))
        directories.append(ScanDirectory(path: "\(userLibrary)/Saved Application State", category: .savedState, requiresAdmin: false))
        directories.append(ScanDirectory(path: "\(userLibrary)/HTTPStorages", category: .caches, requiresAdmin: false))
        directories.append(ScanDirectory(path: "\(userLibrary)/WebKit", category: .webKit, requiresAdmin: false))
        directories.append(ScanDirectory(path: "\(userLibrary)/Cookies", category: .cookies, requiresAdmin: false))
        directories.append(ScanDirectory(path: "\(userLibrary)/LaunchAgents", category: .launchAgents, requiresAdmin: false))
        
        // System directories
        directories.append(ScanDirectory(path: "/Library/Application Support", category: .applicationSupport, requiresAdmin: true))
        directories.append(ScanDirectory(path: "/Library/Caches", category: .caches, requiresAdmin: true))
        directories.append(ScanDirectory(path: "/Library/Preferences", category: .preferences, requiresAdmin: true))
        directories.append(ScanDirectory(path: "/Library/LaunchAgents", category: .launchAgents, requiresAdmin: true))
        directories.append(ScanDirectory(path: "/Library/LaunchDaemons", category: .launchDaemons, requiresAdmin: true))
        directories.append(ScanDirectory(path: "/Library/PrivilegedHelperTools", category: .other, requiresAdmin: true))
        
        // Extension directories
        directories.append(ScanDirectory(path: "/Library/Extensions", category: .extensions, requiresAdmin: true))
        directories.append(ScanDirectory(path: "/Library/SystemExtensions", category: .extensions, requiresAdmin: true))
        directories.append(ScanDirectory(path: "\(userLibrary)/Safari/Extensions", category: .extensions, requiresAdmin: false))
        
        return directories
    }
    
    private func scanDirectory(_ directory: ScanDirectory, searchTerms: [String], fileManager: FileManager) -> [DiscoveredFile] {
        var results: [DiscoveredFile] = []
        
        print("Scanning directory: \(directory.path)")
        
        guard fileManager.fileExists(atPath: directory.path) else {
            print("  Directory does not exist: \(directory.path)")
            return results
        }
        
        let directoryURL = URL(fileURLWithPath: directory.path)
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
            
            print("  Found \(contents.count) items in \(directory.path)")
            
            for itemURL in contents {
                if matchesSearchTerms(itemURL: itemURL, searchTerms: searchTerms) {
                    print("  MATCH: \(itemURL.lastPathComponent)")
                    let size = calculateSize(at: itemURL, fileManager: fileManager)
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
            
            print("  Matched \(results.count) files in \(directory.path)")
        } catch {
            print("Error scanning \(directory.path): \(error.localizedDescription)")
        }
        
        return results
    }
    
    private func buildSearchTerms(for app: TargetApplication) -> [String] {
        var terms: [String] = []
        
        // Full bundle ID (e.g., "com.openai.chat")
        let bundleIDLower = app.bundleID.lowercased()
        terms.append(bundleIDLower)
        
        // Bundle ID components
        let bundleComponents = app.bundleID.components(separatedBy: ".")
        
        // Last component of bundle ID (e.g., "chat" from "com.openai.chat")
        if let lastComponent = bundleComponents.last, lastComponent.count > 2 {
            terms.append(lastComponent.lowercased())
        }
        
        // Last two components (e.g., "openai.chat")
        if bundleComponents.count >= 2 {
            let lastTwo = bundleComponents.suffix(2).joined(separator: ".")
            terms.append(lastTwo.lowercased())
        }
        
        // Organization/company name (second component, e.g., "openai")
        if bundleComponents.count >= 2 {
            let org = bundleComponents[1]
            if org.count > 3 && org.lowercased() != "apple" {
                terms.append(org.lowercased())
            }
        }
        
        // App name variations
        let appNameLower = app.name.lowercased()
        terms.append(appNameLower)
        
        // App name without spaces
        let appNameNoSpaces = appNameLower.replacingOccurrences(of: " ", with: "")
        if appNameNoSpaces != appNameLower {
            terms.append(appNameNoSpaces)
        }
        
        // App name with dashes
        let appNameDashes = appNameLower.replacingOccurrences(of: " ", with: "-")
        if appNameDashes != appNameLower {
            terms.append(appNameDashes)
        }
        
        // App name with underscores
        let appNameUnderscores = appNameLower.replacingOccurrences(of: " ", with: "_")
        if appNameUnderscores != appNameLower {
            terms.append(appNameUnderscores)
        }
        
        // First word of app name if multi-word
        let appNameWords = app.name.components(separatedBy: " ")
        if appNameWords.count > 1, let firstWord = appNameWords.first, firstWord.count > 3 {
            terms.append(firstWord.lowercased())
        }
        
        // App bundle filename (without .app)
        let appFilename = app.url.deletingPathExtension().lastPathComponent.lowercased()
        if !terms.contains(appFilename) {
            terms.append(appFilename)
        }
        
        // Remove duplicates and very short terms
        let uniqueTerms = Array(Set(terms)).filter { $0.count > 2 }
        
        print("Search terms for \(app.name): \(uniqueTerms)")
        
        return uniqueTerms
    }
    
    private func matchesSearchTerms(itemURL: URL, searchTerms: [String]) -> Bool {
        let itemName = itemURL.lastPathComponent.lowercased()
        let itemNameWithoutExtension = itemURL.deletingPathExtension().lastPathComponent.lowercased()
        
        for term in searchTerms {
            // Exact match
            if itemNameWithoutExtension == term || itemName == term {
                return true
            }
            
            // Starts with term
            if itemName.hasPrefix(term) || itemNameWithoutExtension.hasPrefix(term) {
                return true
            }
            
            // Contains term
            if itemName.contains(term) || itemNameWithoutExtension.contains(term) {
                return true
            }
            
            // Plist file matching
            if itemName == "\(term).plist" {
                return true
            }
            
            // Saved state matching
            if itemName == "\(term).savedstate" {
                return true
            }
        }
        
        return false
    }
    
    private func calculateSize(at url: URL, fileManager: FileManager) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }
        
        if isDirectory.boolValue {
            return calculateDirectorySize(at: url, fileManager: fileManager)
        } else {
            return calculateFileSize(at: url, fileManager: fileManager)
        }
    }
    
    private func calculateFileSize(at url: URL, fileManager: FileManager) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func calculateDirectorySize(at url: URL, fileManager: FileManager) -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [],
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
