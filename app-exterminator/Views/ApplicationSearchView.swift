import SwiftUI

struct ApplicationSearchView: View {
    let onCancel: () -> Void
    let onSelectApp: (TargetApplication) -> Void

    @State private var searchText = ""
    @State private var applications: [DiscoveredApplication] = []
    @State private var filteredApplications: [DiscoveredApplication] = []
    @State private var selectedApp: DiscoveredApplication?
    @State private var isLoading = true
    @State private var appSizes: [UUID: Int64] = [:]
    @State private var sizeCalculationTask: Task<Void, Never>?
    @State private var lastTapTime: Date?
    @State private var lastTappedAppId: UUID?

    private let applicationFinder = ApplicationFinder()
    private let doubleClickInterval: TimeInterval = 0.3

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Search field
            searchFieldView

            Divider()

            // Content
            if isLoading {
                loadingView
            } else if filteredApplications.isEmpty {
                emptyStateView
            } else {
                applicationListView
            }

            Divider()

            // Footer
            footerView
        }
        .frame(minWidth: 500, minHeight: 450)
        .task {
            await loadApplications()
        }
        .onChange(of: searchText) { _, newValue in
            Task {
                await filterApplications(query: newValue)
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Browse Applications")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    private var searchFieldView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search applications...", text: $searchText)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search applications")
                .accessibilityHint("Type to filter the list of installed applications")
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(Color(NSColor.textBackgroundColor))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Scanning for applications...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            if searchText.isEmpty {
                Text("No applications found")
                    .font(.headline)
                Text("Could not find any applications on this system.")
                    .foregroundColor(.secondary)
            } else {
                Text("No matching applications")
                    .font(.headline)
                Text("No applications match \"\(searchText)\"")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var applicationListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredApplications) { app in
                    ApplicationRowView(
                        app: app,
                        isSelected: selectedApp?.id == app.id,
                        calculatedSize: appSizes[app.id]
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleTap(on: app)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private func handleTap(on app: DiscoveredApplication) {
        let now = Date()

        // Check for double-click: same app tapped within interval
        if let lastTime = lastTapTime,
           let lastId = lastTappedAppId,
           lastId == app.id,
           now.timeIntervalSince(lastTime) < doubleClickInterval {
            // Double-click detected - proceed with selection
            selectAndProceed(app)
            lastTapTime = nil
            lastTappedAppId = nil
        } else {
            // Single click - select the app
            selectedApp = app
            lastTapTime = now
            lastTappedAppId = app.id
        }
    }

    private var footerView: some View {
        HStack {
            Text("\(filteredApplications.count) application\(filteredApplications.count == 1 ? "" : "s") found")
                .foregroundColor(.secondary)
                .font(.caption)

            Spacer()

            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button("Select Application") {
                if let app = selectedApp {
                    selectAndProceed(app)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedApp == nil)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding()
    }

    // MARK: - Methods

    private func loadApplications() async {
        isLoading = true
        applications = await applicationFinder.discoverApplications()
        filteredApplications = applications
        isLoading = false

        // Start calculating sizes in the background
        startBackgroundSizeCalculation()
    }

    private func startBackgroundSizeCalculation() {
        // Cancel any existing size calculation task
        sizeCalculationTask?.cancel()

        sizeCalculationTask = Task {
            var pendingUpdates: [UUID: Int64] = [:]
            let batchSize = 10

            for (index, app) in applications.enumerated() {
                // Check if task was cancelled
                guard !Task.isCancelled else { break }

                // Calculate size for this app
                let size = await applicationFinder.calculateSize(for: app.app.url)
                pendingUpdates[app.id] = size

                // Batch update every N apps or at the end
                if pendingUpdates.count >= batchSize || index == applications.count - 1 {
                    let updates = pendingUpdates
                    await MainActor.run {
                        for (id, size) in updates {
                            appSizes[id] = size
                        }
                    }
                    pendingUpdates.removeAll()
                }
            }
        }
    }

    private func filterApplications(query: String) async {
        filteredApplications = await applicationFinder.search(query: query, in: applications)
    }

    private func selectAndProceed(_ app: DiscoveredApplication) {
        onSelectApp(app.app)
    }
}

// MARK: - Application Row View

struct ApplicationRowView: View {
    let app: DiscoveredApplication
    let isSelected: Bool
    let calculatedSize: Int64?

    @State private var icon: NSImage?
    @State private var iconLoaded = false

    private var displaySize: String {
        if let size = calculatedSize, size > 0 {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        return "—"
    }

    var body: some View {
        HStack(spacing: 12) {
            // App icon - loads lazily when row appears
            Group {
                if let loadedIcon = icon {
                    Image(nsImage: loadedIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .task(id: app.id) {
                // Load icon lazily when row becomes visible
                guard !iconLoaded else { return }
                iconLoaded = true

                // Check if app already has icon (from previous analysis)
                if let existingIcon = app.app.icon {
                    icon = existingIcon
                } else {
                    // Load icon asynchronously
                    let loadedIcon = await MainActor.run {
                        AppAnalyzer.loadIcon(for: app.app.url)
                    }
                    icon = loadedIcon
                }
            }

            // App info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.app.name)
                        .font(.headline)
                        .lineLimit(1)

                    if app.app.isSystemApp {
                        Label("Protected", systemImage: "lock.shield.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                Text(app.app.bundleID)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(app.app.url.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Size - shows calculated size or "—" while calculating
            Text(displaySize)
                .font(.callout)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.app.name), \(app.app.bundleID), \(displaySize)")
        .accessibilityHint(app.app.isSystemApp ? "Protected system application" : "Double-click or press Return to select")
    }
}

#Preview {
    ApplicationSearchView(
        onCancel: { print("Cancelled") },
        onSelectApp: { app in print("Selected: \(app.name)") }
    )
}
