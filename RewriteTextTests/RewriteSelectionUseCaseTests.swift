import XCTest
@testable import RewriteText

final class RewriteSelectionUseCaseTests: XCTestCase {
    func test_missingAPIKey_throwsActionableError() async {
        let useCase = RewriteSelectionUseCase(
            apiKeyProvider: FakeAPIKeyProvider(value: nil),
            selectionIO: FakeSelectionIO(selectedText: "hello"),
            rewriter: FakeRewriter(output: "hi")
        )

        do {
            _ = try await useCase.run(preset: PromptPreset.builtins[0])
            XCTFail("Expected missing API key error")
        } catch let error as RewriteSelectionUseCase.UseCaseError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_success_callsReplaceWithRewrittenText() async throws {
        let selection = FakeSelectionIO(selectedText: "hello")
        let rewriter = FakeRewriter(output: "hi")
        let useCase = RewriteSelectionUseCase(
            apiKeyProvider: FakeAPIKeyProvider(value: "sk-test"),
            selectionIO: selection,
            rewriter: rewriter
        )

        _ = try await useCase.run(preset: PromptPreset.builtins[0])

        XCTAssertEqual(selection.replacedText, "hi")
    }

    func test_usesProvidedPresetInstructions() async throws {
        let rewriter = FakeRewriter(output: "x")
        let useCase = RewriteSelectionUseCase(
            apiKeyProvider: FakeAPIKeyProvider(value: "sk-test"),
            selectionIO: FakeSelectionIO(selectedText: "hello"),
            rewriter: rewriter
        )

        let preset = PromptPreset.builtins[1]
        _ = try await useCase.run(preset: preset)

        XCTAssertEqual(rewriter.lastPreset?.id, preset.id)
    }
}

private struct FakeAPIKeyProvider: APIKeyProviding {
    let value: String?
    func loadAPIKey() throws -> String? { value }
}

private final class FakeSelectionIO: SelectionIO {
    private let selectedText: String
    private(set) var replacedText: String?

    init(selectedText: String) {
        self.selectedText = selectedText
    }

    func captureSelectedText() async throws -> String {
        selectedText
    }

    func replaceSelection(with text: String) async throws {
        replacedText = text
    }
}

private final class FakeRewriter: LLMRewriting {
    private let output: String
    private(set) var lastPreset: PromptPreset?

    init(output: String) {
        self.output = output
    }

    func rewrite(apiKey: String, preset: PromptPreset, inputText: String) async throws -> String {
        lastPreset = preset
        return output
    }

    func smokeTest(apiKey: String) async throws -> String {
        "OK"
    }
}

