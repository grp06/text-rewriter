import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: RewriteModel
    @State private var apiKeyInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAI")
                .font(.headline)

            if model.isUsingEnvKey {
                Text("Using OPENAI_API_KEY from your environment.")
                    .foregroundStyle(.secondary)
            } else {
                SecureField("API key", text: $apiKeyInput)

                HStack {
                    Button("Save Key") {
                        model.saveApiKey(apiKeyInput)
                        apiKeyInput = ""
                    }
                    Button("Clear Key") {
                        model.clearApiKey()
                        apiKeyInput = ""
                    }
                    Button(model.isWorking ? "Testing..." : "Test Key") {
                        model.testApiKey()
                    }
                    .disabled(model.isWorking)
                }

                Text(model.isApiKeyPresent ? "Key is saved in Keychain." : "No key saved yet.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Permissions")
                .font(.headline)

            HStack {
                Text(model.isAccessibilityTrusted ? "Accessibility: Enabled" : "Accessibility: Not enabled")
                    .foregroundStyle(model.isAccessibilityTrusted ? .secondary : .primary)
                Spacer()
                Button("Request Accessibility...") {
                    model.requestAccessibilityPermission()
                }
            }

            Text("RewriteText must be enabled under System Settings -> Privacy & Security -> Accessibility for Cmd+C/Cmd+V automation to work.")
                .foregroundStyle(.secondary)

            Divider()

            Text("Usage")
                .font(.headline)

            Text("1) Highlight text in any app.\n2) Press Cmd+Esc.\n3) The selection will be replaced with the rewrite.")
                .foregroundStyle(.secondary)

            Text("If rewriting does nothing, grant Accessibility permission:\nSystem Settings -> Privacy & Security -> Accessibility -> enable RewriteText.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(16)
        .frame(width: 520)
    }
}
