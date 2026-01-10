import SwiftUI

struct DeletionResultView: View {
    let app: TargetApplication
    let result: DeletionResult
    let onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            statusIcon
            
            statusMessage
            
            if !result.successfulDeletions.isEmpty {
                successSection
            }
            
            if !result.skippedAdminFiles.isEmpty {
                skippedSection
            }
            
            if !result.failedDeletions.isEmpty {
                failedSection
            }
            
            Spacer()
            
            Button("Done") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if result.isComplete {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
        } else if result.totalDeleted > 0 {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
        } else {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
        }
    }
    
    private var statusMessage: some View {
        VStack(spacing: 8) {
            if result.isComplete {
                Text("\(app.name) Uninstalled")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("\(result.totalDeleted) files moved to Trash")
                    .foregroundColor(.secondary)
                
                Text("\(result.formattedSizeReclaimed) reclaimed")
                    .font(.headline)
                    .foregroundColor(.green)
            } else if result.totalDeleted > 0 {
                Text("Partially Uninstalled")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("\(result.totalDeleted) of \(result.totalDeleted + result.totalFailed + result.totalSkipped) files moved to Trash")
                    .foregroundColor(.secondary)
            } else {
                Text("Uninstall Failed")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Could not delete any files")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var successSection: some View {
        DisclosureGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.successfulDeletions) { file in
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                                .frame(width: 20)
                            
                            Text(file.displayPath)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Text(file.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 150)
        } label: {
            Label("\(result.totalDeleted) files deleted", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
    
    private var skippedSection: some View {
        DisclosureGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.skippedAdminFiles) { file in
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            
                            Text(file.displayPath)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 100)
        } label: {
            Label("\(result.totalSkipped) files require admin password", systemImage: "lock.fill")
                .foregroundColor(.orange)
        }
    }
    
    private var failedSection: some View {
        DisclosureGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.failedDeletions.indices, id: \.self) { index in
                        let failure = result.failedDeletions[index]
                        HStack {
                            Image(systemName: "xmark")
                                .foregroundColor(.red)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading) {
                                Text(failure.file.displayPath)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Text(failure.error.localizedDescription)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 100)
        } label: {
            Label("\(result.totalFailed) files failed to delete", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}

#Preview("Success") {
    let app = TargetApplication(
        url: URL(fileURLWithPath: "/Applications/Example.app"),
        name: "Example App",
        bundleID: "com.example.app"
    )
    
    let result = DeletionResult(
        successfulDeletions: [
            DiscoveredFile(url: URL(fileURLWithPath: "/Applications/Example.app"), category: .application, size: 52_428_800),
            DiscoveredFile(url: URL(fileURLWithPath: "/Users/test/Library/Caches/com.example.app"), category: .caches, size: 10_485_760),
        ],
        failedDeletions: [],
        skippedAdminFiles: []
    )
    
    return DeletionResultView(app: app, result: result, onDone: {})
        .frame(width: 500, height: 400)
}

#Preview("Partial") {
    let app = TargetApplication(
        url: URL(fileURLWithPath: "/Applications/Example.app"),
        name: "Example App",
        bundleID: "com.example.app"
    )
    
    let result = DeletionResult(
        successfulDeletions: [
            DiscoveredFile(url: URL(fileURLWithPath: "/Applications/Example.app"), category: .application, size: 52_428_800),
        ],
        failedDeletions: [],
        skippedAdminFiles: [
            DiscoveredFile(url: URL(fileURLWithPath: "/Library/LaunchDaemons/com.example.plist"), category: .launchDaemons, size: 1024, requiresAdmin: true),
        ]
    )
    
    return DeletionResultView(app: app, result: result, onDone: {})
        .frame(width: 500, height: 400)
}
