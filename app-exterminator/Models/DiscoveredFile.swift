import Foundation

struct DiscoveredFile: Identifiable, Hashable, Equatable {
    let id: UUID
    let url: URL
    let category: FileCategory
    let size: Int64
    let requiresAdmin: Bool
    
    init(
        id: UUID = UUID(),
        url: URL,
        category: FileCategory,
        size: Int64 = 0,
        requiresAdmin: Bool = false
    ) {
        self.id = id
        self.url = url
        self.category = category
        self.size = size
        self.requiresAdmin = requiresAdmin
    }
    
    var displayPath: String {
        let path = url.path
        if let homeDir = FileManager.default.homeDirectoryForCurrentUser.path as String? {
            if path.hasPrefix(homeDir) {
                return path.replacingOccurrences(of: homeDir, with: "~")
            }
        }
        return path
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DiscoveredFile, rhs: DiscoveredFile) -> Bool {
        lhs.id == rhs.id
    }
}
