import AppKit
import Foundation
import os.log

@MainActor
final class RewriteModel: ObservableObject {
    @Published private(set) var isWorking: Bool = false
    @Published private(set) var lastStatus: String = ""
    @Published private(set) var isApiKeyPresent: Bool = false

    @Published var selectedPresetID: String {
        didSet {
            UserDefaults.standard.set(selectedPresetID, forKey: Self.selectedPresetDefaultsKey)
        }
    }

    let presets: [PromptPreset] = PromptPreset.builtins

    var isUsingEnvKey: Bool {
        !(ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "").isEmpty
    }

    var isAccessibilityTrusted: Bool {
        SelectionRewriter.isAccessibilityTrusted()
    }

    private let logger = Logger(subsystem: "com.example.RewriteText", category: "App")
    private var hotkeyManager: HotkeyManager?

    private static let selectedPresetDefaultsKey = "selectedPresetID"
    private let keychainAccount = "openai_api_key"

    private let apiKeyProvider: APIKeyProviding
    private let apiKeyStore: APIKeyStoring
    private let selectionIO: SelectionIO
    private let rewriter: LLMRewriting
    private let rewriteUseCase: RewriteSelectionUseCase

    init() {
        let storedPresetID = UserDefaults.standard.string(forKey: Self.selectedPresetDefaultsKey)
        selectedPresetID = storedPresetID ?? PromptPreset.defaultID

        let service = Bundle.main.bundleIdentifier ?? "RewriteText"
        let provider = EnvOrKeychainAPIKeyProvider(service: service, account: keychainAccount)
        let store = KeychainAPIKeyStore(service: service, account: keychainAccount)

        apiKeyProvider = provider
        apiKeyStore = store
        selectionIO = MacSelectionIO()
        rewriter = OpenAIClient()
        rewriteUseCase = RewriteSelectionUseCase(apiKeyProvider: provider, selectionIO: selectionIO, rewriter: rewriter)

        refreshApiKeyPresence()

        do {
            hotkeyManager = try HotkeyManager { [weak self] in
                Task { @MainActor in
                    self?.rewriteSelection()
                }
            }
            lastStatus = "Ready (Cmd+Esc)"
        } catch {
            lastStatus = "Hotkey registration failed. Use the menu item to run."
            logger.error("Hotkey registration failed: \(String(describing: error), privacy: .public)")
        }
    }

    func selectPreset(_ preset: PromptPreset) {
        selectedPresetID = preset.id
        lastStatus = "Preset: \(preset.name)"
    }

    func rewriteSelection() {
        if isWorking { return }

        isWorking = true
        lastStatus = "Rewriting..."

        Task {
            defer {
                Task { @MainActor in
                    self.isWorking = false
                }
            }

            do {
                let preset = self.selectedPreset()
                _ = try await self.rewriteUseCase.run(preset: preset)
                await MainActor.run {
                    self.lastStatus = "Rewrote selection (\(preset.name))"
                }
            } catch {
                await MainActor.run {
                    self.lastStatus = "Error: \(error.localizedDescription)"
                }
                showAlert(title: "Rewrite Failed", message: error.localizedDescription)
            }
        }
    }

    func testApiKey() {
        if isWorking { return }

        let apiKey: String
        do {
            apiKey = (try apiKeyProvider.loadAPIKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            showAlert(title: "Key Error", message: error.localizedDescription)
            return
        }
        if apiKey.isEmpty {
            showAlert(title: "Missing API Key", message: "Set your OpenAI API key in Settings (stored in Keychain) or via OPENAI_API_KEY.")
            return
        }

        isWorking = true
        lastStatus = "Testing API key..."

        Task {
            defer {
                Task { @MainActor in
                    self.isWorking = false
                }
            }

            do {
                let result = try await rewriter.smokeTest(apiKey: apiKey)
                await MainActor.run {
                    self.lastStatus = "Key OK: \(result.trimmingCharacters(in: .whitespacesAndNewlines))"
                }
            } catch {
                await MainActor.run {
                    self.lastStatus = "Key test failed: \(error.localizedDescription)"
                }
                showAlert(title: "Key Test Failed", message: error.localizedDescription)
            }
        }
    }

    func requestAccessibilityPermission() {
        let trusted = SelectionRewriter.ensureAccessibilityPromptingIfNeeded()
        if trusted {
            lastStatus = "Accessibility permission granted."
        } else {
            showAlert(
                title: "Accessibility Permission Needed",
                message: "Enable RewriteText in System Settings -> Privacy & Security -> Accessibility. Then quit and relaunch RewriteText. If you are running from Xcode, make sure you enable the currently running build."
            )
            lastStatus = "Accessibility permission not granted."
        }
    }

    func saveApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showAlert(title: "Invalid Key", message: "Paste a non-empty API key.")
            return
        }

        do {
            try apiKeyStore.saveAPIKey(trimmed)
            refreshApiKeyPresence()
            lastStatus = "Saved key to Keychain."
        } catch {
            showAlert(title: "Keychain Error", message: error.localizedDescription)
        }
    }

    func clearApiKey() {
        do {
            try apiKeyStore.clearAPIKey()
            refreshApiKeyPresence()
            lastStatus = "Cleared key from Keychain."
        } catch {
            showAlert(title: "Keychain Error", message: error.localizedDescription)
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func selectedPreset() -> PromptPreset {
        presets.first(where: { $0.id == selectedPresetID }) ?? presets.first ?? PromptPreset(id: "default", name: "Default", instructions: "rewrite the text clearly.")
    }

    private func refreshApiKeyPresence() {
        isApiKeyPresent = apiKeyStore.hasAPIKey()
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
