import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var model: RewriteModel

    var body: some View {
        Text("Preset")

        ForEach(model.presets) { preset in
            Button {
                model.selectPreset(preset)
            } label: {
                HStack {
                    if model.selectedPresetID == preset.id {
                        Image(systemName: "checkmark")
                    } else {
                        Image(systemName: "checkmark").hidden()
                    }
                    Text(preset.name)
                }
            }
        }

        Divider()

        Button(model.isWorking ? "Rewriting..." : "Rewrite Selection Now") {
            model.rewriteSelection()
        }
        .disabled(model.isWorking)

        if !model.lastStatus.isEmpty {
            Text(model.lastStatus)
        }

        Divider()

        if #available(macOS 14.0, *) {
            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)
        } else {
            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        Button("Quit") {
            model.quit()
        }
    }
}
