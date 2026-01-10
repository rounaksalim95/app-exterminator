# App Exterminator - Product Requirements Document

## Overview

**App Exterminator** is a macOS application that provides complete application removal by finding and deleting not just the app bundle, but all associated files, caches, preferences, and metadata scattered across the system.

### Problem Statement

When users delete macOS applications by dragging them to Trash, numerous associated files remain:
- Preference files (`.plist`)
- Application Support data
- Caches
- Log files
- Launch agents/daemons
- Container data
- Saved application state

These orphaned files consume disk space and can cause issues when reinstalling applications.

### Solution

A drag-and-drop interface that:
1. Accepts an application bundle
2. Extracts the bundle ID and app name
3. Scans all known metadata locations
4. Presents a comprehensive list of associated files
5. Allows selective deletion with user confirmation
6. Moves files to Trash (recoverable)

---

## Target Platform

| Attribute | Value |
|-----------|-------|
| Platform | macOS |
| Minimum Version | macOS 13.0 (Ventura) |
| Architecture | Universal (Apple Silicon + Intel) |
| UI Framework | SwiftUI |
| Distribution | App Store + Direct Download |

---

## Distribution Strategy

### Direct Download Version (Primary)
- **Non-sandboxed** for full file system access
- Can delete files in all system directories
- Notarized for Gatekeeper approval
- Full functionality

### App Store Version
- **Sandboxed** (App Store requirement)
- Limited file system access
- May require a privileged helper tool for full functionality
- Consider whether reduced functionality is acceptable or if a helper is needed

---

## Core Features

### 1. Drag & Drop Interface

**Description**: Users drag an application (.app bundle) onto the main window to initiate the uninstall process.

**Requirements**:
- Accept `.app` bundles via drag and drop
- Visual feedback during drag (highlight drop zone)
- Validate that the dropped item is a valid application bundle
- Extract bundle ID from `Info.plist`
- Extract app name and other metadata

### 2. File Discovery Engine

**Description**: Scan the system for all files associated with the target application.

**Search Criteria**:
- **Bundle ID matching**: Files/folders containing the bundle ID (e.g., `com.example.app`)
- **App name matching**: Files/folders matching the application name
- **Developer name matching**: Files associated with the app's developer/organization

**Directories to Scan**:

#### User-Level (`~/Library/`)
| Directory | Contents |
|-----------|----------|
| `Application Support/` | App data, databases, resources |
| `Caches/` | Cached data |
| `Preferences/` | `.plist` preference files |
| `Logs/` | Application logs |
| `Containers/` | Sandboxed app data |
| `Group Containers/` | Shared app group data |
| `Saved Application State/` | Window positions, state restoration |
| `HTTPStorages/` | HTTP cache data |
| `WebKit/` | WebKit storage |
| `Cookies/` | App-specific cookies |
| `LaunchAgents/` | User-level launch agents |

#### System-Level (`/Library/`)
| Directory | Contents |
|-----------|----------|
| `Application Support/` | Shared app data |
| `Caches/` | System-wide caches |
| `Preferences/` | System-wide preferences |
| `LaunchAgents/` | System launch agents |
| `LaunchDaemons/` | Background services |
| `PrivilegedHelperTools/` | Elevated helper binaries |
| `Extensions/` | Kernel extensions (legacy) |
| `SystemExtensions/` | Modern system extensions |

#### Browser Extensions
| Browser | Location |
|---------|----------|
| Safari | `~/Library/Safari/Extensions/` |
| Chrome | `~/Library/Application Support/Google/Chrome/Default/Extensions/` |
| Firefox | `~/Library/Application Support/Firefox/Profiles/*/extensions/` |

#### Other Locations
- `/private/var/db/receipts/` - Installer receipts
- `~/.config/` - Unix-style config files
- Login Items (via `LSSharedFileList` or `SMAppService`)

### 3. File Preview & Selection

**Description**: Display all discovered files with the ability to select/deselect individual items.

**Requirements**:
- List view showing all discovered files
- Group files by category (Preferences, Caches, Application Support, etc.)
- Show file/folder size for each item
- Show total size to be reclaimed
- Checkbox for each item (all selected by default)
- "Select All" / "Deselect All" buttons
- Visual distinction between user-level and system-level files
- Indicate files requiring admin permissions

### 4. Safe Deletion

**Description**: Delete selected files by moving them to Trash.

**Requirements**:
- Move files to Trash (not permanent deletion)
- Handle files requiring admin permissions:
  - Prompt for password via system authentication dialog
  - Use `AuthorizationServices` for privilege escalation
- Verify successful deletion
- Handle errors gracefully (file in use, permission denied, etc.)

### 5. Running Application Detection

**Description**: Detect and warn if the target application is currently running.

**Requirements**:
- Check if app is running before proceeding
- Display warning dialog if app is running
- Offer to force quit the application
- Prevent deletion while app is running (unless user force quits)

### 6. System Application Protection

**Description**: Prevent deletion of critical system applications.

**Protected Applications**:
- Finder
- Safari (optional - can be reinstalled)
- System Preferences / System Settings
- App Store
- All apps in `/System/Applications/`
- Other Apple system applications

**Requirements**:
- Detect system applications
- Display warning explaining why deletion is blocked
- Do not allow override for truly critical apps

### 7. Deletion History & Logging

**Description**: Maintain a log of all deletion operations.

**Requirements**:
- Log each deletion session with:
  - Timestamp
  - Application name and bundle ID
  - List of deleted files with paths and sizes
  - Total space reclaimed
- Persist history across app launches
- View history in a dedicated window/tab
- Export history to file (CSV or JSON)
- Clear history option

### 8. Undo Functionality

**Description**: Allow users to restore recently deleted files from Trash.

**Requirements**:
- "Undo Last Deletion" option in Edit menu
- Works by restoring files from Trash to original locations
- Only available if files still exist in Trash
- Handle cases where Trash has been emptied

### 9. Space Reclamation Display

**Description**: Show users how much disk space will be / was reclaimed.

**Requirements**:
- Display individual file sizes in the file list
- Show total size of selected files
- Show total reclaimed after deletion
- Format sizes appropriately (KB, MB, GB)

---

## User Interface

### Main Window

```
┌─────────────────────────────────────────────────────────────┐
│  App Exterminator                              [─] [□] [×]  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│    ┌─────────────────────────────────────────────────┐     │
│    │                                                 │     │
│    │         Drag an application here               │     │
│    │              to uninstall it                   │     │
│    │                                                 │     │
│    │            [App Icon Placeholder]              │     │
│    │                                                 │     │
│    └─────────────────────────────────────────────────┘     │
│                                                             │
│    [View History]                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### File Review Window

```
┌─────────────────────────────────────────────────────────────┐
│  Uninstall "Example App"                       [─] [□] [×]  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [App Icon] Example App                                     │
│  Bundle ID: com.example.app                                 │
│  Version: 1.2.3                                             │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  Files to be deleted:                    Total: 245.6 MB    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ☑ Application                                       │   │
│  │   ☑ /Applications/Example App.app          120.0 MB │   │
│  │                                                     │   │
│  │ ☑ Preferences                                       │   │
│  │   ☑ ~/Library/Preferences/com.example...     12 KB │   │
│  │                                                     │   │
│  │ ☑ Application Support                               │   │
│  │   ☑ ~/Library/Application Support/Exa...   100.0 MB │   │
│  │                                                     │   │
│  │ ☑ Caches                                           │   │
│  │   ☑ ~/Library/Caches/com.example.app        25.5 MB │   │
│  │                                                     │   │
│  │ ☐ System Files (requires admin) ⚠️                  │   │
│  │   ☐ /Library/LaunchDaemons/com.examp...       4 KB │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [Select All]  [Deselect All]                              │
│                                                             │
│                           [Cancel]  [Move to Trash]         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### History Window

```
┌─────────────────────────────────────────────────────────────┐
│  Deletion History                              [─] [□] [×]  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 2024-01-15 14:32 - Example App                      │   │
│  │   12 files deleted, 245.6 MB reclaimed              │   │
│  │   [View Details] [Restore from Trash]               │   │
│  │                                                     │   │
│  │ 2024-01-14 09:15 - Another App                      │   │
│  │   8 files deleted, 1.2 GB reclaimed                 │   │
│  │   [View Details] [Restore from Trash]               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [Export History]                        [Clear History]    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Technical Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                        App Exterminator                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   UI Layer  │  │  Services   │  │   System Services   │ │
│  │  (SwiftUI)  │  │             │  │                     │ │
│  ├─────────────┤  ├─────────────┤  ├─────────────────────┤ │
│  │ MainView    │  │ AppAnalyzer │  │ FileManager         │ │
│  │ DropZone    │  │ FileScanner │  │ NSWorkspace         │ │
│  │ FileList    │  │ Deleter     │  │ AuthorizationServices│ │
│  │ HistoryView │  │ HistoryMgr  │  │ SMAppService        │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Data Models

```swift
struct TargetApplication {
    let url: URL
    let name: String
    let bundleID: String
    let version: String?
    let icon: NSImage?
    let isSystemApp: Bool
}

struct DiscoveredFile {
    let url: URL
    let category: FileCategory
    let size: Int64
    let requiresAdmin: Bool
}

enum FileCategory {
    case application
    case preferences
    case applicationSupport
    case caches
    case logs
    case containers
    case launchAgents
    case launchDaemons
    case extensions
    case other
}

struct DeletionRecord {
    let id: UUID
    let date: Date
    let appName: String
    let bundleID: String
    let deletedFiles: [DeletedFileRecord]
    let totalSizeReclaimed: Int64
}
```

---

## Security Considerations

### Privilege Escalation
- Use `AuthorizationServices` for admin operations
- Request only necessary privileges
- Never store admin credentials

### File System Safety
- Never delete files outside known safe directories
- Validate file paths to prevent directory traversal
- Confirm system app detection before blocking

### Code Signing
- Sign with Developer ID for direct download
- Sign with App Store distribution certificate for App Store
- Notarize the direct download version

---

## Privacy Considerations

- No telemetry or analytics
- No network requests (app works fully offline)
- History stored locally only
- No data leaves the user's machine

---

## Error Handling

| Scenario | Handling |
|----------|----------|
| Invalid app bundle dropped | Show error, explain valid formats |
| App is running | Show warning, offer force quit |
| Permission denied | Request admin authentication |
| File in use | Skip file, report in summary |
| Trash operation fails | Show error, suggest manual deletion |
| System app detected | Block deletion, explain why |

---

## Testing Requirements

### Unit Tests
- Bundle ID extraction
- File path matching logic
- System app detection
- Size calculations

### Integration Tests
- File discovery accuracy
- Deletion operations
- History persistence
- Undo functionality

### Manual Testing
- Various application types (sandboxed, non-sandboxed, Electron, etc.)
- Applications with complex file structures
- Admin-required file deletion
- Edge cases (corrupted bundles, missing Info.plist)

---

## Future Enhancements (Out of Scope for v1)

1. **Batch uninstall**: Select multiple apps to uninstall at once
2. **Scheduled cleanup**: Automatically find orphaned files from already-deleted apps
3. **Orphan file scanner**: Find leftover files from apps no longer installed
4. **Allowlist/Blocklist**: Remember preferences for specific files/directories
5. **Menu bar mode**: Quick access from menu bar
6. **Keyboard shortcut**: Global hotkey to launch with selected app
7. **Homebrew integration**: Also run `brew uninstall` for Homebrew-installed apps
8. **Quarantine check**: Warn about apps that were never opened (still quarantined)

---

## Success Metrics

- Successfully identifies >95% of associated files for common applications
- Zero false positives (never suggests deleting unrelated files)
- Deletion completion rate >99%
- App launch to deletion complete in <30 seconds for typical apps

---

## Timeline Estimate

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Phase 1: Core | 2 weeks | Drag/drop, file discovery, basic deletion |
| Phase 2: Polish | 1 week | UI refinement, history, undo |
| Phase 3: Security | 1 week | Admin auth, system app protection |
| Phase 4: Testing | 1 week | Comprehensive testing, bug fixes |
| Phase 5: Release | 1 week | Notarization, App Store submission |

**Total: ~6 weeks**

---

## Appendix: Bundle ID Extraction

```swift
// Pseudocode for bundle ID extraction
func extractBundleID(from appURL: URL) -> String? {
    let infoPlistURL = appURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("Info.plist")
    
    guard let plist = NSDictionary(contentsOf: infoPlistURL),
          let bundleID = plist["CFBundleIdentifier"] as? String else {
        return nil
    }
    
    return bundleID
}
```

---

## Appendix: Protected System Apps

The following bundle ID prefixes indicate system applications:
- `com.apple.` (most Apple apps)

Applications in these directories are protected:
- `/System/Applications/`
- `/System/Library/CoreServices/`

---

*Document Version: 1.0*  
*Last Updated: January 2025*
