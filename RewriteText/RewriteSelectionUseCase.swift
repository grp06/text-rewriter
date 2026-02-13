import Foundation

struct RewriteSelectionUseCase {
    enum UseCaseError: Error, LocalizedError, Equatable {
        case missingAPIKey

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing API key. Set your OpenAI API key in Settings (stored in Keychain) or via OPENAI_API_KEY."
            }
        }
    }

    let apiKeyProvider: APIKeyProviding
    let selectionIO: SelectionIO
    let rewriter: LLMRewriting

    func run(preset: PromptPreset) async throws -> String {
        let apiKey = (try apiKeyProvider.loadAPIKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw UseCaseError.missingAPIKey }

        let selectedText = try await selectionIO.captureSelectedText()
        let rewritten = try await rewriter.rewrite(apiKey: apiKey, preset: preset, inputText: selectedText)
        try await selectionIO.replaceSelection(with: rewritten)
        return rewritten
    }
}

