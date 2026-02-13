import SwiftUI

@main
struct RewriteTextApp: App {
    @StateObject private var model = RewriteModel()

    var body: some Scene {
        MenuBarExtra("RewriteText", systemImage: "wand.and.stars") {
            MenuContentView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
