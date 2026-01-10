import SwiftUI

struct AppInfoView: View {
    let app: TargetApplication
    let onCancel: () -> Void
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            appHeader
            
            Divider()
            
            appDetails
            
            if app.isSystemApp {
                systemAppWarning
            }
            
            Spacer()
            
            actionButtons
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])
            
            Button("Scan for Files") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(isCriticalSystemApp)
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

#Preview {
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
    .frame(width: 500, height: 400)
}
