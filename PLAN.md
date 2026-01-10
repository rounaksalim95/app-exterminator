# App Exterminator - Implementation Plan

This document breaks down the implementation into logical milestones. Each milestone is self-contained and results in a working (though incomplete) application.

---

## Milestone 1: Project Foundation

**Goal**: Basic app structure with a functional main window.

### Tasks

- [x] **1.1** Set up Xcode project
  - SwiftUI App lifecycle
  - macOS 13.0 deployment target
  - Universal binary (Apple Silicon + Intel)
  - Configure app icon placeholder
  - Set up basic project structure (folders for Views, Models, Services)

- [x] **1.2** Create main window UI
  - App window with proper sizing and title
  - Follows system light/dark mode
  - Basic drop zone placeholder (non-functional)

- [x] **1.3** Set up data models
  - `TargetApplication` struct
  - `DiscoveredFile` struct
  - `FileCategory` enum
  - `DeletionRecord` struct

**Deliverable**: App launches and displays main window with placeholder UI. ✅

---

## Milestone 2: Drag & Drop + App Analysis

**Goal**: Accept app bundles and extract metadata.

### Tasks

- [x] **2.1** Implement drop zone
  - Accept `.app` bundle drops
  - Visual feedback on drag enter/exit
  - Validate dropped item is a valid app bundle

- [x] **2.2** Create `AppAnalyzer` service
  - Extract bundle ID from `Info.plist`
  - Extract app name, version, icon
  - Detect if app is a system application
  - Handle invalid/corrupted bundles gracefully

- [x] **2.3** Display app info after drop
  - Show app icon, name, bundle ID, version
  - Transition from drop zone to app info view
  - "Cancel" button to return to drop zone

**Deliverable**: User can drop an app and see its metadata displayed. ✅

---

## Milestone 3: File Discovery Engine

**Goal**: Find all files associated with a dropped application.

### Tasks

- [x] **3.1** Create `FileScanner` service
  - Define all directories to scan (from PRD)
  - Implement directory traversal
  - Match files by bundle ID
  - Match files by app name

- [x] **3.2** Scan user-level directories
  - `~/Library/Application Support/`
  - `~/Library/Caches/`
  - `~/Library/Preferences/`
  - `~/Library/Logs/`
  - `~/Library/Containers/`
  - `~/Library/Group Containers/`
  - `~/Library/Saved Application State/`
  - `~/Library/HTTPStorages/`
  - `~/Library/WebKit/`
  - `~/Library/Cookies/`
  - `~/Library/LaunchAgents/`

- [x] **3.3** Scan system-level directories
  - `/Library/Application Support/`
  - `/Library/Caches/`
  - `/Library/Preferences/`
  - `/Library/LaunchAgents/`
  - `/Library/LaunchDaemons/`
  - `/Library/PrivilegedHelperTools/`
  - Mark files requiring admin permissions

- [x] **3.4** Scan extension directories
  - `/Library/Extensions/` (legacy kernel extensions)
  - `/Library/SystemExtensions/`
  - Safari extensions
  - Detect login items via `SMAppService`

- [x] **3.5** Calculate file sizes
  - Individual file/folder sizes
  - Total size calculation
  - Handle inaccessible files gracefully

- [x] **3.6** Categorize discovered files
  - Assign `FileCategory` to each file
  - Group files for display

**Deliverable**: App discovers and lists all associated files with sizes. ✅

---

## Milestone 4: File Preview & Selection UI

**Goal**: Display discovered files and allow selection.

### Tasks

- [x] **4.1** Create file list view
  - Grouped by category (collapsible sections)
  - Checkbox for each file
  - Display file path (truncated) and size
  - Indicate files requiring admin permissions (⚠️ icon)

- [x] **4.2** Implement selection logic
  - Select/deselect individual files
  - Select All / Deselect All buttons
  - Category-level select/deselect
  - Track total selected size

- [x] **4.3** Add file context actions
  - "Reveal in Finder" for any file
  - Tooltip showing full path on hover

- [x] **4.4** Display summary
  - Total files selected
  - Total size to be reclaimed
  - "Move to Trash" button (disabled if nothing selected)

**Deliverable**: User can browse, select/deselect files before deletion. ✅

---

## Milestone 5: Basic Deletion

**Goal**: Delete selected files (user-level only, no admin).

### Tasks

- [x] **5.1** Create `Deleter` service
  - Move files to Trash using `FileManager.trashItem()`
  - Handle errors per-file
  - Return success/failure report

- [x] **5.2** Implement deletion flow
  - Confirmation dialog before deletion
  - Progress indicator during deletion
  - Skip files requiring admin (for now)

- [x] **5.3** Show deletion results
  - Summary of deleted files
  - List any files that failed
  - Total space reclaimed
  - "Done" button to return to main screen

**Deliverable**: User can delete user-level files associated with an app. ✅

---

## Milestone 6: Running App Detection

**Goal**: Prevent deletion of running applications.

### Tasks

- [x] **6.1** Detect running applications
  - Use `NSWorkspace.shared.runningApplications`
  - Match by bundle ID

- [x] **6.2** Show warning dialog
  - "App is currently running" message
  - "Force Quit" option
  - "Cancel" option

- [x] **6.3** Implement force quit
  - Use `NSRunningApplication.terminate()` or `forceTerminate()`
  - Wait for termination before proceeding
  - Handle apps that refuse to quit

**Deliverable**: App warns about running apps and can force quit them. ✅

---

## Milestone 7: System App Protection

**Goal**: Prevent deletion of critical system applications.

### Tasks

- [x] **7.1** Define protected apps list
  - Apps in `/System/Applications/`
  - Apps with `com.apple.` bundle ID prefix
  - Specific critical apps (Finder, System Settings, etc.)

- [x] **7.2** Implement protection check
  - Check on app drop (before scanning)
  - Block protected apps immediately

- [x] **7.3** Show protection dialog
  - Explain why the app cannot be deleted
  - Link to Apple documentation (optional)
  - Only option is "OK" to dismiss

**Deliverable**: System apps are protected from deletion. ✅

---

## Milestone 8: Admin Authentication

**Goal**: Delete files requiring elevated permissions.

### Tasks

- [ ] **8.1** Identify admin-required files
  - Files in `/Library/` directories
  - Files owned by root
  - Files without write permission

- [ ] **8.2** Implement privilege escalation
  - Use `AuthorizationServices` framework
  - Request `kAuthorizationRightExecute`
  - Show system password prompt

- [ ] **8.3** Create privileged helper
  - Helper tool for privileged file operations
  - Communicate via XPC (optional) or direct execution
  - Sign helper with appropriate entitlements

- [ ] **8.4** Integrate into deletion flow
  - Separate user-level and admin-level deletions
  - Only prompt for admin if admin files are selected
  - Handle authentication failure gracefully

**Deliverable**: User can delete system-level files with admin password.

---

## Milestone 9: History & Logging

**Goal**: Track deletion history for reference and undo.

### Tasks

- [x] **9.1** Create `HistoryManager` service
  - Store `DeletionRecord` entries
  - Persist to disk (JSON file or Core Data)
  - Load history on app launch

- [x] **9.2** Record deletions
  - Create record after successful deletion
  - Store original paths for each file
  - Store deletion timestamp

- [x] **9.3** Create history view
  - List of past deletions
  - Show app name, date, file count, size reclaimed
  - Expandable to show individual files
  - "Clear History" button

- [x] **9.4** Add history access
  - "View History" button on main screen
  - Menu item: Window > History

**Deliverable**: User can view history of all past deletions. ✅

---

## Milestone 10: Undo Functionality

**Goal**: Restore deleted files from Trash.

### Tasks

- [x] **10.1** Implement restore logic
  - Find files in Trash by original path
  - Move files back to original locations
  - Handle missing files (Trash emptied)
  - *(Note: Files moved to Trash - users can restore via Finder)*

- [ ] **10.2** Add undo UI *(Deferred - manual Trash restore works)*
  - "Restore from Trash" button in history view
  - Edit menu: "Undo Last Deletion" (⌘Z)
  - Disable if files no longer in Trash

- [ ] **10.3** Handle restore failures *(Deferred)*
  - File no longer exists in Trash
  - Original location is occupied
  - Permission denied
  - Show appropriate error messages

**Deliverable**: User can restore recently deleted files. *(Partial - via Trash)*

---

## Milestone 11: Polish & Edge Cases

**Goal**: Refine UI and handle edge cases.

### Tasks

- [ ] **11.1** UI Polish
  - Animations for state transitions
  - Loading states during scanning
  - Empty states (no files found)
  - Keyboard navigation

- [ ] **11.2** Menu bar integration
  - Standard macOS menu bar
  - File > Open (choose app via file picker)
  - Edit > Undo
  - Window > History
  - Help > App Exterminator Help

- [ ] **11.3** Handle edge cases
  - Corrupted app bundles
  - Apps with no associated files
  - Very large file counts (performance)
  - Symlinks and aliases
  - Apps on external drives

- [ ] **11.4** Accessibility
  - VoiceOver support
  - Keyboard-only navigation
  - Sufficient color contrast

- [ ] **11.5** Export history
  - Export to CSV
  - Export to JSON

**Deliverable**: Polished, production-ready application.

---

## Milestone 12: Testing

**Goal**: Comprehensive testing before release.

### Tasks

- [ ] **12.1** Unit tests
  - `AppAnalyzer` tests
  - `FileScanner` tests (with mock file system)
  - `HistoryManager` tests
  - Size calculation tests

- [ ] **12.2** Integration tests
  - Full deletion flow
  - History persistence
  - Undo functionality

- [ ] **12.3** Manual testing
  - Test with various app types:
    - Standard macOS apps
    - Electron apps
    - Sandboxed apps
    - Apps with helpers/daemons
    - Adobe apps (complex)
    - JetBrains apps
    - Homebrew-installed apps
  - Test on Intel and Apple Silicon
  - Test on macOS 13, 14, 15

- [ ] **12.4** Performance testing
  - Apps with thousands of associated files
  - Large files/folders
  - Slow storage (HDD, network drives)

**Deliverable**: Tested, stable application.

---

## Milestone 13: Distribution

**Goal**: Prepare and release the application.

### Tasks

- [ ] **13.1** Direct Download version
  - Disable App Sandbox in Xcode
  - Build with hardened runtime
  - Sign with Developer ID certificate
  - Notarize with Apple
  - Create DMG installer
  - Host on website/GitHub

- [ ] **13.2** Documentation
  - README.md with usage instructions
  - FAQ for common issues
  - Privacy policy (if distributing publicly)

- [ ] **13.3** Release
  - Create GitHub release
  - Version tagging
  - Release notes

**Deliverable**: Published application ready for users.

*Note: App Store distribution is not supported. Sandboxing prevents access to ~/Library directories, which is required for the core functionality of this app.*

---

## Milestone Summary

| # | Milestone | Estimated Effort | Dependencies |
|---|-----------|------------------|--------------|
| 1 | Project Foundation | 2-3 hours | None |
| 2 | Drag & Drop + App Analysis | 3-4 hours | M1 |
| 3 | File Discovery Engine | 6-8 hours | M2 |
| 4 | File Preview & Selection UI | 4-5 hours | M3 |
| 5 | Basic Deletion | 3-4 hours | M4 |
| 6 | Running App Detection | 2-3 hours | M2 |
| 7 | System App Protection | 2-3 hours | M2 |
| 8 | Admin Authentication | 4-6 hours | M5 |
| 9 | History & Logging | 3-4 hours | M5 |
| 10 | Undo Functionality | 2-3 hours | M9 |
| 11 | Polish & Edge Cases | 4-6 hours | M1-10 |
| 12 | Testing | 4-6 hours | M11 |
| 13 | Distribution | 3-4 hours | M12 |

**Total Estimated Effort**: ~45-55 hours

---

## Suggested Working Order

```
M1 → M2 → M3 → M4 → M5 (core flow complete)
         ↓
    M6, M7 (safety features, can be parallel)
         ↓
        M8 (admin auth)
         ↓
    M9 → M10 (history & undo)
         ↓
   M11 → M12 → M13 (polish, test, ship)
```

---

## Quick Start Checklist

To begin implementation:

1. [ ] Create new Xcode project (SwiftUI, macOS 13+)
2. [ ] Set up folder structure: `Views/`, `Models/`, `Services/`
3. [ ] Copy data models from PRD into `Models/`
4. [ ] Create `ContentView.swift` with drop zone
5. [ ] Start Milestone 1!

---

*Document Version: 1.0*  
*Last Updated: January 2025*
