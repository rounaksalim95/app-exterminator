import Foundation

struct DeletedFileRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let originalPath: String
    let category: FileCategory
    let size: Int64
    
    init(
        id: UUID = UUID(),
        originalPath: String,
        category: FileCategory,
        size: Int64
    ) {
        self.id = id
        self.originalPath = originalPath
        self.category = category
        self.size = size
    }
    
    init(from discoveredFile: DiscoveredFile) {
        self.id = discoveredFile.id
        self.originalPath = discoveredFile.url.path
        self.category = discoveredFile.category
        self.size = discoveredFile.size
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct DeletionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let appName: String
    let bundleID: String
    let appIconData: Data?
    let deletedFiles: [DeletedFileRecord]
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        appName: String,
        bundleID: String,
        appIconData: Data? = nil,
        deletedFiles: [DeletedFileRecord]
    ) {
        self.id = id
        self.date = date
        self.appName = appName
        self.bundleID = bundleID
        self.appIconData = appIconData
        self.deletedFiles = deletedFiles
    }
    
    var totalSizeReclaimed: Int64 {
        deletedFiles.reduce(0) { $0 + $1.size }
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeReclaimed, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var fileCount: Int {
        deletedFiles.count
    }
}
