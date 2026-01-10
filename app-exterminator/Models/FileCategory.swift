import Foundation

enum FileCategory: String, CaseIterable, Identifiable, Codable {
    case application
    case preferences
    case applicationSupport
    case caches
    case logs
    case containers
    case launchAgents
    case launchDaemons
    case extensions
    case loginItems
    case cookies
    case webKit
    case savedState
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .application: return "Application"
        case .preferences: return "Preferences"
        case .applicationSupport: return "Application Support"
        case .caches: return "Caches"
        case .logs: return "Logs"
        case .containers: return "Containers"
        case .launchAgents: return "Launch Agents"
        case .launchDaemons: return "Launch Daemons"
        case .extensions: return "Extensions"
        case .loginItems: return "Login Items"
        case .cookies: return "Cookies"
        case .webKit: return "WebKit Data"
        case .savedState: return "Saved State"
        case .other: return "Other"
        }
    }
    
    var systemImage: String {
        switch self {
        case .application: return "app.fill"
        case .preferences: return "gearshape.fill"
        case .applicationSupport: return "folder.fill"
        case .caches: return "internaldrive.fill"
        case .logs: return "doc.text.fill"
        case .containers: return "shippingbox.fill"
        case .launchAgents: return "arrow.clockwise"
        case .launchDaemons: return "gear"
        case .extensions: return "puzzlepiece.extension.fill"
        case .loginItems: return "person.fill"
        case .cookies: return "circle.fill"
        case .webKit: return "globe"
        case .savedState: return "square.stack.fill"
        case .other: return "questionmark.folder.fill"
        }
    }
}
