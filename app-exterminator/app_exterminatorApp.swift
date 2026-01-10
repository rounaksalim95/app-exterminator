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
            CommandGroup(replacing: .newItem) {}
        }
    }
}
