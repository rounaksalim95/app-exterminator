import SwiftUI

@main
struct AppExterminatorApp: App {
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
                Link("App Exterminator Help", destination: URL(string: "https://github.com/rounaksalim95/app-exterminator")!)
                
                Divider()
                
                Button("About App Exterminator") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
            }
        }
    }
}
