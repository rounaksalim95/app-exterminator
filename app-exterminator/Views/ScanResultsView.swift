import SwiftUI

struct ScanResultsView: View {
    let scanResult: ScanResult
    let onCancel: () -> Void
    let onDelete: ([DiscoveredFile]) -> Void
    
    @State private var selectedFiles: Set<DiscoveredFile.ID> = []
    @State private var expandedCategories: Set<FileCategory> = Set(FileCategory.allCases)
    
    init(scanResult: ScanResult, onCancel: @escaping () -> Void, onDelete: @escaping ([DiscoveredFile]) -> Void) {
        self.scanResult = scanResult
        self.onCancel = onCancel
        self.onDelete = onDelete
        _selectedFiles = State(initialValue: Set(scanResult.discoveredFiles.map { $0.id }))
    }
    
    private var selectedFilesArray: [DiscoveredFile] {
        scanResult.discoveredFiles.filter { selectedFiles.contains($0.id) }
    }
    
    private var selectedTotalSize: Int64 {
        selectedFilesArray.reduce(0) { $0 + $1.size }
    }
    
    private var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedTotalSize, countStyle: .file)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            fileList
            
            Divider()
            
            footer
        }
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            if let icon = scanResult.app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Uninstall \(scanResult.app.name)")
                    .font(.headline)
                
                Text(scanResult.app.bundleID)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(scanResult.discoveredFiles.count) files found")
                    .font(.subheadline)
                
                Text("Total: \(scanResult.formattedTotalSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var fileList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(sortedCategories, id: \.self) { category in
                    if let files = scanResult.filesByCategory[category], !files.isEmpty {
                        categorySection(category: category, files: files)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var sortedCategories: [FileCategory] {
        FileCategory.allCases.filter { category in
            scanResult.filesByCategory[category]?.isEmpty == false
        }
    }
    
    private func categorySection(category: FileCategory, files: [DiscoveredFile]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryHeader(category: category, files: files)
            
            if expandedCategories.contains(category) {
                ForEach(files) { file in
                    fileRow(file: file)
                }
            }
        }
    }
    
    private func categoryHeader(category: FileCategory, files: [DiscoveredFile]) -> some View {
        let allSelected = files.allSatisfy { selectedFiles.contains($0.id) }
        let someSelected = files.contains { selectedFiles.contains($0.id) }
        let categorySize = files.reduce(0) { $0 + $1.size }
        
        return Button {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                
                Toggle("", isOn: Binding(
                    get: { allSelected },
                    set: { newValue in
                        if newValue {
                            files.forEach { selectedFiles.insert($0.id) }
                        } else {
                            files.forEach { selectedFiles.remove($0.id) }
                        }
                    }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .opacity(someSelected && !allSelected ? 0.5 : 1.0)
                
                Image(systemName: category.systemImage)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                Text(category.displayName)
                    .fontWeight(.medium)
                
                Text("(\(files.count))")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(ByteCountFormatter.string(fromByteCount: categorySize, countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
        }
        .buttonStyle(.plain)
    }
    
    private func fileRow(file: DiscoveredFile) -> some View {
        HStack(spacing: 8) {
            Color.clear
                .frame(width: 16)
            
            Toggle("", isOn: Binding(
                get: { selectedFiles.contains(file.id) },
                set: { newValue in
                    if newValue {
                        selectedFiles.insert(file.id)
                    } else {
                        selectedFiles.remove(file.id)
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            if file.requiresAdmin {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .help("Requires administrator password to delete")
            }
            
            Text(file.displayPath)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(file.url.path)
            
            Spacer()
            
            Text(file.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    private var footer: some View {
        HStack {
            Button("Select All") {
                selectedFiles = Set(scanResult.discoveredFiles.map { $0.id })
            }
            .buttonStyle(.link)
            
            Button("Deselect All") {
                selectedFiles.removeAll()
            }
            .buttonStyle(.link)
            
            Spacer()
            
            Text("\(selectedFilesArray.count) selected (\(formattedSelectedSize))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])
            
            Button("Move to Trash") {
                onDelete(selectedFilesArray)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(selectedFiles.isEmpty)
        }
        .padding()
    }
}

#Preview {
    let app = TargetApplication(
        url: URL(fileURLWithPath: "/Applications/Example.app"),
        name: "Example App",
        bundleID: "com.example.app",
        version: "1.0"
    )
    
    let files = [
        DiscoveredFile(url: URL(fileURLWithPath: "/Applications/Example.app"), category: .application, size: 52_428_800),
        DiscoveredFile(url: URL(fileURLWithPath: "/Users/test/Library/Caches/com.example.app"), category: .caches, size: 10_485_760),
        DiscoveredFile(url: URL(fileURLWithPath: "/Users/test/Library/Preferences/com.example.app.plist"), category: .preferences, size: 4096),
        DiscoveredFile(url: URL(fileURLWithPath: "/Library/LaunchDaemons/com.example.app.plist"), category: .launchDaemons, size: 1024, requiresAdmin: true),
    ]
    
    let result = ScanResult(
        app: app,
        discoveredFiles: files,
        totalSize: files.reduce(0) { $0 + $1.size },
        scanDuration: 0.5
    )
    
    return ScanResultsView(
        scanResult: result,
        onCancel: {},
        onDelete: { _ in }
    )
    .frame(width: 600, height: 500)
}
