import Foundation

struct MacSelectionIO: SelectionIO {
    func captureSelectedText() async throws -> String {
        try await SelectionRewriter.captureSelectedText()
    }

    func replaceSelection(with text: String) async throws {
        try await SelectionRewriter.replaceSelection(with: text)
    }
}

