import AppKit
import Foundation

/// A model representing a discovered application with its size information
struct DiscoveredApplication: Identifiable, Equatable, Hashable {
    let id: UUID
    let app: TargetApplication
    let size: Int64

    init(app: TargetApplication, size: Int64) {
        self.id = app.id
        self.app = app
        self.size = size
    }

    var formattedSize: String {
        if size <= 0 {
            return "—"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    static func == (lhs: DiscoveredApplication, rhs: DiscoveredApplication) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Service for discovering installed applications on the system
actor ApplicationFinder {

    /// Standard directories where applications are installed
    private let applicationDirectories: [URL] = {
        var dirs: [URL] = []

        // /Applications
        dirs.append(URL(fileURLWithPath: "/Applications"))

        // ~/Applications
        if let userAppsDir = FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first {
            dirs.append(userAppsDir)
        }

        // /System/Applications (for display, but protected)
        dirs.append(URL(fileURLWithPath: "/System/Applications"))

        return dirs
    }()

    private let fileManager = FileManager.default

    /// Cached applications to avoid re-scanning
    private var cachedApplications: [DiscoveredApplication]?
    private var lastScanDate: Date?
    private let cacheValidityDuration: TimeInterval = 60 // 1 minute cache

    /// Discovers all installed applications
    /// - Parameter forceRefresh: If true, bypasses cache and rescans directories
    /// - Returns: Array of discovered applications sorted alphabetically by name
    func discoverApplications(forceRefresh: Bool = false) async -> [DiscoveredApplication] {
        // Check cache validity
        if !forceRefresh,
           let cached = cachedApplications,
           let lastScan = lastScanDate,
           Date().timeIntervalSince(lastScan) < cacheValidityDuration {
            return cached
        }

        var applications: [DiscoveredApplication] = []
        var seenBundleIDs: Set<String> = []

        for directory in applicationDirectories {
            let apps = await scanDirectory(directory, seenBundleIDs: &seenBundleIDs)
            applications.append(contentsOf: apps)
        }

        // Sort alphabetically by name (case-insensitive)
        applications.sort { $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending }

        // Update cache
        cachedApplications = applications
        lastScanDate = Date()

        return applications
    }

    /// Searches applications by name or bundle ID
    /// - Parameters:
    ///   - query: Search query string
    ///   - applications: Optional pre-fetched applications list. If nil, will discover apps first.
    /// - Returns: Filtered array of applications matching the query
    func search(query: String, in applications: [DiscoveredApplication]? = nil) async -> [DiscoveredApplication] {
        let apps: [DiscoveredApplication]
        if let provided = applications {
            apps = provided
        } else {
            apps = await discoverApplications()
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmedQuery.isEmpty {
            return apps
        }

        return apps.filter { app in
            app.app.name.lowercased().contains(trimmedQuery) ||
            app.app.bundleID.lowercased().contains(trimmedQuery)
        }
    }

    /// Clears the cached applications
    func clearCache() {
        cachedApplications = nil
        lastScanDate = nil
    }

    // MARK: - Private Methods

    private func scanDirectory(_ directory: URL, seenBundleIDs: inout Set<String>) async -> [DiscoveredApplication] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            print("Error scanning directory \(directory.path): \(error.localizedDescription)")
            return []
        }

        // Filter to only .app bundles
        let appURLs = contents.filter { $0.pathExtension == "app" }

        // Process apps in parallel for faster discovery
        let results = await withTaskGroup(of: DiscoveredApplication?.self, returning: [DiscoveredApplication].self) { group in
            for itemURL in appURLs {
                group.addTask {
                    // Analyze and create DiscoveredApplication on MainActor
                    // since TargetApplication contains NSImage which is main-actor isolated
                    return await MainActor.run {
                        let result = AppAnalyzer.analyzeWithoutIcon(appURL: itemURL)
                        switch result {
                        case .success(let app):
                            // Size is deferred - set to 0 for fast loading
                            return DiscoveredApplication(app: app, size: 0)
                        case .failure:
                            return nil
                        }
                    }
                }
            }

            var apps: [DiscoveredApplication] = []
            for await result in group {
                if let app = result {
                    apps.append(app)
                }
            }
            return apps
        }

        // Filter duplicates (same bundle ID) - must be done sequentially
        var applications: [DiscoveredApplication] = []
        for app in results {
            guard !seenBundleIDs.contains(app.app.bundleID) else { continue }
            seenBundleIDs.insert(app.app.bundleID)
            applications.append(app)
        }

        return applications
    }

    /// Calculate size for a specific application on-demand
    /// - Parameter url: The URL of the application bundle
    /// - Returns: The total size in bytes
    func calculateSize(for url: URL) async -> Int64 {
        // Use nonisolated helper to avoid async iterator issues with FileManager.enumerator
        calculateSizeSync(for: url)
    }

    /// Synchronous size calculation to avoid Swift 6 async iterator issues
    private nonisolated func calculateSizeSync(for url: URL) -> Int64 {
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isDirectoryKey]

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                if let size = resourceValues.totalFileAllocatedSize {
                    totalSize += Int64(size)
                }
            } catch {
                continue
            }
        }

        return totalSize
    }
}
