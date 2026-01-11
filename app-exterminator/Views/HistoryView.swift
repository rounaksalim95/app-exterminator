import SwiftUI

struct HistoryView: View {
    @State private var records: [DeletionRecord] = []
    @State private var isLoading = true
    @State private var showClearConfirmation = false
    @State private var selectedRecord: DeletionRecord?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            if isLoading {
                loadingView
            } else if records.isEmpty {
                emptyView
            } else {
                recordsList
            }
            
            Divider()
            
            footer
        }
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await loadHistory()
        }
        .confirmationDialog(
            "Clear History?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All History", role: .destructive) {
                Task {
                    await HistoryManager.shared.clearHistory()
                    await loadHistory()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove all deletion history. Deleted files remain in Trash.")
        }
        .sheet(item: $selectedRecord) { record in
            HistoryDetailView(record: record)
        }
    }
    
    private var header: some View {
        HStack {
            Text("Deletion History")
                .font(.headline)
            
            Spacer()
            
            Text("\(records.count) records")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Text("Loading history...")
                .foregroundColor(.secondary)
                .padding(.top, 8)
            Spacer()
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No History")
                .font(.headline)
            
            Text("Deleted applications will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(records) { record in
                    HistoryRowView(record: record)
                        .onTapGesture {
                            selectedRecord = record
                        }
                }
            }
            .padding()
        }
    }
    
    private var footer: some View {
        HStack {
            Button("Clear History") {
                showClearConfirmation = true
            }
            .disabled(records.isEmpty)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding()
    }
    
    private func loadHistory() async {
        isLoading = true
        await HistoryManager.shared.load()
        records = await HistoryManager.shared.getAllRecords()
        isLoading = false
    }
}

struct HistoryRowView: View {
    let record: DeletionRecord
    
    var body: some View {
        HStack(spacing: 12) {
            appIcon
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.appName)
                    .font(.headline)
                
                Text(record.bundleID)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(record.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Label("\(record.fileCount)", systemImage: "doc")
                        .font(.caption)
                    
                    Text(record.formattedTotalSize)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        )
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var appIcon: some View {
        if let iconData = record.appIconData,
           let nsImage = NSImage(data: iconData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
                .frame(width: 40, height: 40)
        }
    }
}

struct HistoryDetailView: View {
    let record: DeletionRecord
    @Environment(\.dismiss) private var dismiss
    @State private var canRestore = false
    @State private var isRestoring = false
    @State private var showRestoreConfirmation = false
    @State private var restoreResult: RestoreResult?
    @State private var showRestoreResult = false
    
    private let restorer = TrashRestorer()
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            filesList
            
            Divider()
            
            footer
        }
        .frame(minWidth: 450, minHeight: 350)
        .task {
            canRestore = await restorer.canRestoreAny(files: record.deletedFiles)
        }
        .confirmationDialog(
            "Restore from Trash?",
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restore \(record.fileCount) files") {
                Task {
                    await performRestore()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore \(record.fileCount) files to their original locations. Files that are no longer in Trash will be skipped.")
        }
        .sheet(isPresented: $showRestoreResult) {
            if let result = restoreResult {
                RestoreResultView(result: result, appName: record.appName)
            }
        }
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            if let iconData = record.appIconData,
               let nsImage = NSImage(data: iconData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.appName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Deleted \(record.formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(record.fileCount) files")
                    .font(.subheadline)
                
                Text(record.formattedTotalSize)
                    .font(.headline)
                    .foregroundColor(.green)
            }
        }
        .padding()
    }
    
    private var filesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(record.deletedFiles) { file in
                    HStack {
                        Image(systemName: file.category.systemImage)
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        
                        Text(file.originalPath)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var footer: some View {
        HStack {
            if isRestoring {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Restoring...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button("Restore from Trash") {
                    showRestoreConfirmation = true
                }
                .disabled(!canRestore)
                .help(canRestore ? "Restore files to original locations" : "Files are no longer in Trash")
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding()
    }
    
    private func performRestore() async {
        isRestoring = true
        restoreResult = await restorer.restore(files: record.deletedFiles)
        isRestoring = false
        canRestore = await restorer.canRestoreAny(files: record.deletedFiles)
        showRestoreResult = true
    }
}

struct RestoreResultView: View {
    let result: RestoreResult
    let appName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            resultDetails
            
            Divider()
            
            footer
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: result.isComplete ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(result.isComplete ? .green : .orange)
            
            Text(result.isComplete ? "Restore Complete" : "Restore Partially Complete")
                .font(.headline)
            
            Text("\(result.totalRestored) of \(result.totalRestored + result.totalFailed + result.totalNotInTrash) files restored")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var resultDetails: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !result.successfulRestores.isEmpty {
                    resultSection(
                        title: "Restored Successfully",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        files: result.successfulRestores.map { ($0.originalPath, nil) }
                    )
                }
                
                if !result.notInTrash.isEmpty {
                    resultSection(
                        title: "Not Found in Trash",
                        icon: "trash.slash",
                        color: .secondary,
                        files: result.notInTrash.map { ($0.originalPath, "May have been emptied from Trash") }
                    )
                }
                
                if !result.failedRestores.isEmpty {
                    resultSection(
                        title: "Failed to Restore",
                        icon: "xmark.circle.fill",
                        color: .red,
                        files: result.failedRestores.map { ($0.file.originalPath, $0.error.localizedDescription) }
                    )
                }
            }
            .padding()
        }
    }
    
    private func resultSection(title: String, icon: String, color: Color, files: [(path: String, reason: String?)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(files.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(files.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 2) {
                    Text((files[index].path as NSString).lastPathComponent)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                    
                    if let reason = files[index].reason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }
    
    private var footer: some View {
        HStack {
            if result.totalRestored > 0 {
                Text("\(result.formattedRestoredSize) restored")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding()
    }
}

#Preview("History List") {
    HistoryView()
}
