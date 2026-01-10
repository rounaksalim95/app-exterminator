import SwiftUI

struct AppInfoView: View {
    let app: TargetApplication
    let onCancel: () -> Void
    let onContinue: () -> Void
    
    @State private var isAppRunning = false
    @State private var showRunningAppAlert = false
    @State private var isTerminating = false
    
    var body: some View {
        VStack(spacing: 24) {
            appHeader
            
            Divider()
            
            appDetails
            
            if app.isSystemApp {
                systemAppWarning
            }
            
            if isAppRunning {
                runningAppWarning
            }
            
            Spacer()
            
            actionButtons
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkIfRunning()
        }
        .alert("Application is Running", isPresented: $showRunningAppAlert) {
            Button("Force Quit", role: .destructive) {
                forceQuitApp()
            }
            Button("Cancel", role: .cancel) {
                showRunningAppAlert = false
            }
        } message: {
            Text("\(app.name) is currently running. You must quit it before uninstalling.")
        }
    }
    
    private var appHeader: some View {
        HStack(spacing: 16) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                    .frame(width: 64, height: 64)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.title)
                    .fontWeight(.semibold)
                
                if let version = app.version {
                    Text("Version \(version)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var appDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailRow(label: "Bundle ID", value: app.bundleID)
            DetailRow(label: "Location", value: app.url.path)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var systemAppWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("System Application")
                    .font(.headline)
                
                Text("This appears to be an Apple system application. Deleting it may cause system instability.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var runningAppWarning: some View {
        HStack(spacing: 12) {
            if isTerminating {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isTerminating ? "Quitting..." : "Application is Running")
                    .font(.headline)
                
                if !isTerminating {
                    Text("This application is currently running and must be quit before it can be uninstalled.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !isTerminating {
                Button("Quit") {
                    showRunningAppAlert = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])
            
            Button("Scan for Files") {
                if isAppRunning {
                    showRunningAppAlert = true
                } else {
                    onContinue()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(isCriticalSystemApp || isTerminating)
        }
    }
    
    private var isCriticalSystemApp: Bool {
        switch AppAnalyzer.validateNotCriticalSystemApp(app) {
        case .success:
            return false
        case .failure:
            return true
        }
    }
    
    private func checkIfRunning() {
        isAppRunning = RunningAppChecker.isRunning(app: app)
    }
    
    private func forceQuitApp() {
        isTerminating = true
        Task {
            let success = await RunningAppChecker.terminateAndWait(app: app, force: true)
            await MainActor.run {
                isTerminating = false
                isAppRunning = !success
                if success {
                    onContinue()
                }
            }
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

#Preview("Normal App") {
    AppInfoView(
        app: TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Slack.app"),
            name: "Slack",
            bundleID: "com.tinyspeck.slackmacgap",
            version: "4.35.0"
        ),
        onCancel: {},
        onContinue: {}
    )
    .frame(width: 500, height: 400)
}

#Preview("System App") {
    AppInfoView(
        app: TargetApplication(
            url: URL(fileURLWithPath: "/Applications/Safari.app"),
            name: "Safari",
            bundleID: "com.apple.Safari",
            version: "17.0",
            isSystemApp: true
        ),
        onCancel: {},
        onContinue: {}
    )
    .frame(width: 500, height: 450)
}
