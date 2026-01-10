import SwiftUI

enum AppState {
    case dropZone
    case appInfo(TargetApplication)
    case scanning(TargetApplication)
    case error(String)
}

struct MainView: View {
    @State private var appState: AppState = .dropZone
    @State private var isDropTargeted = false
    @State private var showHistory = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(minWidth: 500, minHeight: 400)
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
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
                    appState = .scanning(app)
                }
            )
            
        case .scanning(let app):
            scanningPlaceholder(for: app)
            
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
    
    private func scanningPlaceholder(for app: TargetApplication) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Scanning for files...")
                .font(.headline)
            
            Text("Looking for files associated with \(app.name)")
                .foregroundColor(.secondary)
            
            Button("Cancel") {
                appState = .dropZone
            }
            .buttonStyle(.bordered)
            .padding(.top, 20)
        }
        .padding()
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
}

#Preview("Drop Zone") {
    MainView()
}

#Preview("App Info") {
    let view = MainView()
    return view
}
