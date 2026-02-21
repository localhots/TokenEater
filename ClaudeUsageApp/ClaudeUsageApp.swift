import SwiftUI

@main
struct ClaudeUsageApp: App {
    init() {
        ClaudeAPIClient.shared.isHostApp = true
    }

    var body: some Scene {
        WindowGroup {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}
