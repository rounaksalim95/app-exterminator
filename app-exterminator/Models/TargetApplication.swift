import AppKit
import Foundation

struct TargetApplication: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let bundleID: String
    let version: String?
    let icon: NSImage?
    let isSystemApp: Bool
    
    init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        bundleID: String,
        version: String? = nil,
        icon: NSImage? = nil,
        isSystemApp: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.icon = icon
        self.isSystemApp = isSystemApp
    }
    
    static func == (lhs: TargetApplication, rhs: TargetApplication) -> Bool {
        lhs.id == rhs.id &&
        lhs.url == rhs.url &&
        lhs.bundleID == rhs.bundleID
    }
}
