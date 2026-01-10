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
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            filesList
            
            Divider()
            
            footer
        }
        .frame(minWidth: 450, minHeight: 350)
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
