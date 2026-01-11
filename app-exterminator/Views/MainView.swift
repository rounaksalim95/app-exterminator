import SwiftUI

enum AppState: Equatable {
    case dropZone
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
    }
    
    @ViewBuilder
    private var content: some View {
        switch appState {
        case .dropZone:
            dropZoneContent
            
        case .appInfo(let app):
            AppInfoView(
                app: app,
                onCancel: {
                    appState = .dropZone
                },
                onContinue: {
                    startScanning(app: app)
                }
            )
            
        case .scanning(let app):
            scanningView(for: app)
            
        case .results(let scanResult):
            ScanResultsView(
                scanResult: scanResult,
                onCancel: {
                    appState = .dropZone
                },
                onDelete: { selectedFiles in
                    filesToDelete = selectedFiles
                    currentScanResult = scanResult
                    showDeleteConfirmation = true
                }
            )
            
        case .confirmDelete:
            EmptyView()
            
        case .deleting(let app, let files):
            deletingView(app: app, files: files)
            
        case .deletionComplete(let app, let result):
            DeletionResultView(
                app: app,
                result: result,
                onDone: {
                    appState = .dropZone
                }
            )
            
        case .error(let message):
            errorView(message: message)
        }
    }
    
    private var dropZoneContent: some View {
        VStack(spacing: 20) {
            DropZoneView(isTargeted: $isDropTargeted) { result in
                handleDropResult(result)
            }
            
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
                appState = .dropZone
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func handleDropResult(_ result: Result<TargetApplication, AppAnalyzerError>) {
        switch result {
        case .success(let app):
            appState = .appInfo(app)
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func startScanning(app: TargetApplication) {
        appState = .scanning(app)
    }
}

#Preview("Drop Zone") {
    MainView()
}
