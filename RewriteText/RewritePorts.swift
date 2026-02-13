import Foundation

protocol APIKeyProviding {
    func loadAPIKey() throws -> String?
}

protocol APIKeyStoring {
    func saveAPIKey(_ key: String) throws
    func clearAPIKey() throws
    func hasAPIKey() -> Bool
}

protocol SelectionIO {
    func captureSelectedText() async throws -> String
    func replaceSelection(with text: String) async throws
}

protocol LLMRewriting {
    func rewrite(apiKey: String, preset: PromptPreset, inputText: String) async throws -> String
    func smokeTest(apiKey: String) async throws -> String
}

