import SwiftUI

@main
struct AppSweepApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 550, height: 450)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Application...") {
                    NotificationCenter.default.post(name: .openApp, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Browse Applications...") {
                    NotificationCenter.default.post(name: .browseApps, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .windowList) {
                Button("Deletion History") {
                    NotificationCenter.default.post(name: .showHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }
            
            CommandGroup(replacing: .help) {
                if let helpURL = URL(string: "https://github.com/rounaksalim95/app-exterminator") {
                    Link("App Sweep Help", destination: helpURL)
                }

                Divider()

                Button("About App Sweep") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
            }
        }
    }
}
