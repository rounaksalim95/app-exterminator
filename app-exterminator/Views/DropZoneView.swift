import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Binding var isTargeted: Bool
    let onAppDropped: (Result<TargetApplication, AppAnalyzerError>) -> Void
    let onBrowseApps: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 3, dash: [10])
                    )
                    .foregroundColor(isTargeted ? .accentColor : .secondary.opacity(0.5))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                    )

                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 64))
                        .foregroundColor(isTargeted ? .accentColor : .secondary)

                    Text("Drag an application here")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("to uninstall it completely")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Divider with "or"
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 60, height: 1)
                        Text("or")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 60, height: 1)
                    }
                    .padding(.top, 8)

                    // Browse Applications button
                    Button(action: onBrowseApps) {
                        Label("Browse Applications", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityHint("Opens a searchable list of installed applications")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Drop zone for applications")
            .accessibilityHint("Drag an application here to uninstall it, or press Command+Shift+A to browse applications")
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    onAppDropped(.failure(.invalidBundle))
                    return
                }
                
                let result = AppAnalyzer.analyze(appURL: url)
                onAppDropped(result)
            }
        }
        
        return true
    }
}

#Preview {
    DropZoneView(
        isTargeted: .constant(false),
        onAppDropped: { result in print("Result: \(result)") },
        onBrowseApps: { print("Browse apps") }
    )
    .frame(width: 500, height: 400)
}
