import Testing
import Foundation
@testable import app_exterminator

struct ApplicationFinderTests {

    // MARK: - DiscoveredApplication Tests

    @Test func discoveredApplicationHasCorrectFormattedSize() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test App",
            bundleID: "com.test.app"
        )
        let discovered = DiscoveredApplication(app: app, size: 1024 * 1024) // 1 MB

        #expect(discovered.formattedSize.contains("MB") || discovered.formattedSize.contains("1"))
    }

    @Test func discoveredApplicationEquality() {
        let app1 = TargetApplication(
            id: UUID(),
            url: URL(fileURLWithPath: "/Applications/Test1.app"),
            name: "Test App 1",
            bundleID: "com.test.app1"
        )
        let app2 = TargetApplication(
            id: app1.id,
            url: URL(fileURLWithPath: "/Applications/Test1.app"),
            name: "Test App 1",
            bundleID: "com.test.app1"
        )

        let discovered1 = DiscoveredApplication(app: app1, size: 1000)
        let discovered2 = DiscoveredApplication(app: app2, size: 2000)

        // Should be equal because they share the same UUID (via app.id)
        #expect(discovered1 == discovered2)
    }

    @Test func discoveredApplicationInequality() {
        let app1 = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Test1.app"),
            name: "Test App 1",
            bundleID: "com.test.app1"
        )
        let app2 = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Test2.app"),
            name: "Test App 2",
            bundleID: "com.test.app2"
        )

        let discovered1 = DiscoveredApplication(app: app1, size: 1000)
        let discovered2 = DiscoveredApplication(app: app2, size: 1000)

        #expect(discovered1 != discovered2)
    }

    @Test func discoveredApplicationHashable() {
        let app = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test App",
            bundleID: "com.test.app"
        )
        let discovered = DiscoveredApplication(app: app, size: 1000)

        var set = Set<DiscoveredApplication>()
        set.insert(discovered)

        #expect(set.contains(discovered))
    }

    // MARK: - ApplicationFinder Tests

    @Test func applicationFinderDiscoverApplicationsReturnsResults() async {
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        // /Applications should have at least some apps on any macOS system
        #expect(!apps.isEmpty)
    }

    @Test func applicationFinderDiscoverApplicationsAreSortedAlphabetically() async {
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        guard apps.count > 1 else { return }

        for i in 0..<(apps.count - 1) {
            let comparison = apps[i].app.name.localizedCaseInsensitiveCompare(apps[i + 1].app.name)
            #expect(comparison == .orderedAscending || comparison == .orderedSame)
        }
    }

    @Test func applicationFinderSearchWithEmptyQueryReturnsAll() async {
        let finder = ApplicationFinder()
        let allApps = await finder.discoverApplications()
        let searchResults = await finder.search(query: "", in: allApps)

        #expect(searchResults.count == allApps.count)
    }

    @Test func applicationFinderSearchByNameFindsApps() async {
        let finder = ApplicationFinder()
        let allApps = await finder.discoverApplications()

        guard let firstApp = allApps.first else {
            Issue.record("No applications found to test search")
            return
        }

        // Search for part of the first app's name
        let searchTerm = String(firstApp.app.name.prefix(3)).lowercased()
        let searchResults = await finder.search(query: searchTerm, in: allApps)

        #expect(searchResults.contains(where: { $0.id == firstApp.id }))
    }

    @Test func applicationFinderSearchByBundleIDFindsApps() async {
        let finder = ApplicationFinder()
        let allApps = await finder.discoverApplications()

        guard let firstApp = allApps.first else {
            Issue.record("No applications found to test search")
            return
        }

        // Search for part of the bundle ID
        let bundleComponents = firstApp.app.bundleID.split(separator: ".")
        if let lastComponent = bundleComponents.last {
            let searchTerm = String(lastComponent)
            let searchResults = await finder.search(query: searchTerm, in: allApps)

            #expect(searchResults.contains(where: { $0.id == firstApp.id }))
        }
    }

    @Test func applicationFinderSearchIsCaseInsensitive() async {
        let finder = ApplicationFinder()
        let allApps = await finder.discoverApplications()

        guard let firstApp = allApps.first else {
            Issue.record("No applications found to test search")
            return
        }

        let lowerResults = await finder.search(query: firstApp.app.name.lowercased(), in: allApps)
        let upperResults = await finder.search(query: firstApp.app.name.uppercased(), in: allApps)

        #expect(lowerResults.count == upperResults.count)
    }

    @Test func applicationFinderSearchWithNonExistentTermReturnsEmpty() async {
        let finder = ApplicationFinder()
        let allApps = await finder.discoverApplications()

        let searchResults = await finder.search(query: "xyznonexistentapp123456789", in: allApps)

        #expect(searchResults.isEmpty)
    }

    @Test func applicationFinderSearchTrimsWhitespace() async {
        let finder = ApplicationFinder()
        let allApps = await finder.discoverApplications()

        guard let firstApp = allApps.first else {
            Issue.record("No applications found to test search")
            return
        }

        let searchTerm = firstApp.app.name.prefix(3)
        let normalResults = await finder.search(query: String(searchTerm), in: allApps)
        let whitespaceResults = await finder.search(query: "  \(searchTerm)  ", in: allApps)

        #expect(normalResults.count == whitespaceResults.count)
    }

    @Test func applicationFinderClearCacheClearsCache() async {
        let finder = ApplicationFinder()

        // First call populates cache
        _ = await finder.discoverApplications()

        // Clear cache
        await finder.clearCache()

        // This should trigger a fresh scan (we can't directly verify cache is cleared,
        // but we can verify the method runs without error)
        let apps = await finder.discoverApplications()
        #expect(!apps.isEmpty)
    }

    @Test func applicationFinderUsesCacheOnSecondCall() async {
        let finder = ApplicationFinder()

        // First call
        let firstCall = await finder.discoverApplications()

        // Second call should use cache (should be very fast)
        let secondCall = await finder.discoverApplications()

        #expect(firstCall.count == secondCall.count)
    }

    @Test func applicationFinderForceRefreshBypassesCache() async {
        let finder = ApplicationFinder()

        // Populate cache
        let cached = await finder.discoverApplications()

        // Force refresh should still work
        let refreshed = await finder.discoverApplications(forceRefresh: true)

        #expect(refreshed.count == cached.count)
    }

    @Test func applicationFinderNoDuplicateBundleIDs() async {
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        let bundleIDs = apps.map { $0.app.bundleID }
        let uniqueBundleIDs = Set(bundleIDs)

        #expect(bundleIDs.count == uniqueBundleIDs.count)
    }

    @Test func applicationFinderAppsHaveValidPaths() async {
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        for app in apps {
            #expect(app.app.url.pathExtension == "app")
            #expect(FileManager.default.fileExists(atPath: app.app.url.path))
        }
    }

    @Test func applicationFinderAppsHaveNonEmptyBundleIDs() async {
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        for app in apps {
            #expect(!app.app.bundleID.isEmpty)
        }
    }

    @Test func applicationFinderAppsHaveNonEmptyNames() async {
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        for app in apps {
            #expect(!app.app.name.isEmpty)
        }
    }

    @Test func applicationFinderAppsHaveNonNegativeSizes() async {
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        for app in apps {
            #expect(app.size >= 0)
        }
    }

    @Test func applicationFinderIdentifiesSystemApps() async {
        let finder = ApplicationFinder()
        let apps = await finder.discoverApplications()

        // There should be at least some system apps on any macOS system
        let systemApps = apps.filter { $0.app.isSystemApp }
        #expect(!systemApps.isEmpty)
    }

    @Test func applicationFinderSearchWithProvidedNilApplicationsFetchesApps() async {
        let finder = ApplicationFinder()

        // Search without providing applications - should fetch them automatically
        let results = await finder.search(query: "")

        #expect(!results.isEmpty)
    }
}
