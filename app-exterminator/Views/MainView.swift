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
    @State private var filesToDelete: [DiscoveredFile] = []
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
                if let result = currentScanResult {
                    appState = .deleting(result.app, filesToDelete)
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
            Text("This will move \(filesToDelete.count) files (\(size)) to Trash. You can restore them from Trash if needed.")
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
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Moving files to Trash...")
                .font(.headline)
            
            Text("Deleting \(files.count) files")
                .foregroundColor(.secondary)
        }
        .padding()
        .task {
            let result = await deleter.delete(files: files)
            
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
