import SwiftUI
import UniformTypeIdentifiers

enum AppState: Equatable {
    case dropZone
    case browseApps
    case appInfo(TargetApplication)
    case scanning(TargetApplication)
    case results(ScanResult)
    case confirmDelete(ScanResult, [DiscoveredFile])
    case deleting(TargetApplication, [DiscoveredFile])
    case deletionComplete(TargetApplication, DeletionResult)
    case error(String)

    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.dropZone, .dropZone):
            return true
        case (.browseApps, .browseApps):
            return true
        case (.appInfo(let a), .appInfo(let b)):
            return a == b
        case (.scanning(let a), .scanning(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        case (.results, .results),
             (.confirmDelete, .confirmDelete),
             (.deleting, .deleting),
             (.deletionComplete, .deletionComplete):
            return true
        default:
            return false
        }
    }
}

struct MainView: View {
    @State private var appState: AppState = .dropZone
    @State private var isDropTargeted = false
    @State private var showHistory = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showAdminConfirmation = false
    @State private var filesToDelete: [DiscoveredFile] = []
    @State private var includeAdminFiles = false
    @State private var currentScanResult: ScanResult?
    @State private var showFilePicker = false
    
    private let fileScanner = FileScanner()
    private let deleter = Deleter()
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(minWidth: 550, minHeight: 450)
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move \(filesToDelete.count) items to Trash", role: .destructive) {
                let hasAdminFiles = filesToDelete.contains { $0.requiresAdmin }
                if hasAdminFiles {
                    showDeleteConfirmation = false
                    showAdminConfirmation = true
                } else {
                    if let result = currentScanResult {
                        includeAdminFiles = false
                        appState = .deleting(result.app, filesToDelete)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            let size = ByteCountFormatter.string(
                fromByteCount: filesToDelete.reduce(0) { $0 + $1.size },
                countStyle: .file
            )
            let adminCount = filesToDelete.filter { $0.requiresAdmin }.count
            if adminCount > 0 {
                Text("This will move \(filesToDelete.count) files (\(size)) to Trash. \(adminCount) file(s) require administrator privileges.")
            } else {
                Text("This will move \(filesToDelete.count) files (\(size)) to Trash. You can restore them from Trash if needed.")
            }
        }
        .confirmationDialog(
            "Administrator Privileges Required",
            isPresented: $showAdminConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete with Admin Password", role: .destructive) {
                if let result = currentScanResult {
                    includeAdminFiles = true
                    appState = .deleting(result.app, filesToDelete)
                }
            }
            Button("Skip Admin Files", role: .none) {
                if let result = currentScanResult {
                    includeAdminFiles = false
                    appState = .deleting(result.app, filesToDelete)
                }
            }
            Button("Cancel", role: .cancel) {
                showAdminConfirmation = false
            }
        } message: {
            let adminFiles = filesToDelete.filter { $0.requiresAdmin }
            let adminSize = ByteCountFormatter.string(
                fromByteCount: adminFiles.reduce(0) { $0 + $1.size },
                countStyle: .file
            )
            Text("\(adminFiles.count) file(s) (\(adminSize)) are in system directories and require your administrator password to delete. You will be prompted for your password.")
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            handleFilePickerResult(result)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openApp)) { _ in
            showFilePicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHistory)) { _ in
            showHistory = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .browseApps)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                appState = .browseApps
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        Group {
            switch appState {
            case .dropZone:
                dropZoneContent

            case .browseApps:
                ApplicationSearchView(
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState = .dropZone
                        }
                    },
                    onSelectApp: { app in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState = .appInfo(app)
                        }
                    }
                )

            case .appInfo(let app):
                AppInfoView(
                    app: app,
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState = .dropZone
                        }
                    },
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            startScanning(app: app)
                        }
                    }
                )
                
            case .scanning(let app):
                scanningView(for: app)
                
            case .results(let scanResult):
                if scanResult.discoveredFiles.isEmpty {
                    emptyResultsView(for: scanResult.app)
                } else {
                    ScanResultsView(
                        scanResult: scanResult,
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appState = .dropZone
                            }
                        },
                        onDelete: { selectedFiles in
                            filesToDelete = selectedFiles
                            currentScanResult = scanResult
                            showDeleteConfirmation = true
                        }
                    )
                }
                
            case .confirmDelete:
                EmptyView()
                
            case .deleting(let app, let files):
                deletingView(app: app, files: files)
                
            case .deletionComplete(let app, let result):
                DeletionResultView(
                    app: app,
                    result: result,
                    onDone: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState = .dropZone
                        }
                    }
                )
                
            case .error(let message):
                errorView(message: message)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
    
    private var dropZoneContent: some View {
        VStack(spacing: 20) {
            DropZoneView(
                isTargeted: $isDropTargeted,
                onAppDropped: { result in
                    handleDropResult(result)
                },
                onBrowseApps: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState = .browseApps
                    }
                }
            )

            HStack {
                Button("View History") {
                    showHistory = true
                }
                .buttonStyle(.link)
            }
            .padding(.bottom, 20)
        }
    }
    
    private func scanningView(for app: TargetApplication) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Scanning for files...")
                .font(.headline)
            
            Text("Looking for files associated with \(app.name)")
                .foregroundColor(.secondary)
        }
        .padding()
        .task {
            let result = await fileScanner.scan(app: app)
            appState = .results(result)
        }
    }
    
    private func deletingView(app: TargetApplication, files: [DiscoveredFile]) -> some View {
        let adminFileCount = files.filter { $0.requiresAdmin }.count
        let progressText = includeAdminFiles && adminFileCount > 0
            ? "Moving files to Trash (admin password may be required)..."
            : "Moving files to Trash..."
        
        return VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(progressText)
                .font(.headline)
            
            Text("Deleting \(files.count) files")
                .foregroundColor(.secondary)
        }
        .padding()
        .task {
            let result = await deleter.delete(files: files, includeAdminFiles: includeAdminFiles)
            
            if !result.successfulDeletions.isEmpty {
                _ = await HistoryManager.shared.createRecord(from: app, deletionResult: result)
            }
            
            appState = .deletionComplete(app, result)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState = .dropZone
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func emptyResultsView(for app: TargetApplication) -> some View {
        VStack(spacing: 20) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
            }
            
            Text("No Associated Files Found")
                .font(.headline)
            
            Text("\(app.name) doesn't appear to have any additional files outside of its application bundle.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Text("The app may be self-contained or was already cleaned up.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Done") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState = .dropZone
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding()
    }
    
    private func handleDropResult(_ result: Result<TargetApplication, AppAnalyzerError>) {
        switch result {
        case .success(let app):
            withAnimation(.easeInOut(duration: 0.2)) {
                appState = .appInfo(app)
            }
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func startScanning(app: TargetApplication) {
        appState = .scanning(app)
    }
    
    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected application."
                showError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let analyzeResult = AppAnalyzer.analyze(appURL: url)
            handleDropResult(analyzeResult)
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

extension Notification.Name {
    static let openApp = Notification.Name("openApp")
    static let showHistory = Notification.Name("showHistory")
    static let browseApps = Notification.Name("browseApps")
}

#Preview("Drop Zone") {
    MainView()
}
