import Foundation
import os.log

struct OpenAIClient {
    private let logger = Logger(subsystem: "com.example.RewriteText", category: "OpenAI")

    struct OpenAIHTTPError: Error, CustomStringConvertible {
        let statusCode: Int
        let body: String

        var description: String {
            "OpenAI HTTP \(statusCode): \(body)"
        }
    }

    struct ResponseParsingError: Error, CustomStringConvertible {
        let bodySnippet: String

        var description: String {
            "Could not extract output text from OpenAI response. Body snippet: \(bodySnippet)"
        }
    }

    func smokeTest(apiKey: String) async throws -> String {
        try await createResponse(apiKey: apiKey, instructions: "Respond with the single word OK.", inputText: "OK")
    }

    func rewrite(apiKey: String, presetInstructions: String, inputText: String) async throws -> String {
        let instructions = """
        You rewrite user-provided text.

        Follow these preset instructions:
        \(presetInstructions)

        Constraints:
        - preserve the original meaning
        - do not add new facts
        - return only the rewritten text (no markdown, no surrounding quotes)
        """
        return try await createResponse(apiKey: apiKey, instructions: instructions, inputText: inputText)
    }

    private func createResponse(apiKey: String, instructions: String, inputText: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = CreateResponseRequest(
            model: "gpt-5.2",
            instructions: instructions,
            input: [
                .init(role: "user", content: inputText),
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let statusCode = http?.statusCode ?? -1

        let rawBody = String(data: data, encoding: .utf8) ?? ""
        let snippet = String(rawBody.prefix(4000))
        if let requestID = http?.value(forHTTPHeaderField: "x-request-id") {
            logger.info("OpenAI response status=\(statusCode) request_id=\(requestID) body_snippet=\(snippet, privacy: .public)")
        } else {
            logger.info("OpenAI response status=\(statusCode) body_snippet=\(snippet, privacy: .public)")
        }

        guard (200..<300).contains(statusCode) else {
            throw OpenAIHTTPError(statusCode: statusCode, body: snippet)
        }

        let decoded = try JSONDecoder().decode(CreateResponseResponse.self, from: data)
        if let outputText = decoded.output_text, !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return outputText
        }

        let extracted = decoded.outputText()
        if !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return extracted
        }

        throw ResponseParsingError(bodySnippet: snippet)
    }
}

extension OpenAIClient: LLMRewriting {
    func rewrite(apiKey: String, preset: PromptPreset, inputText: String) async throws -> String {
        try await rewrite(apiKey: apiKey, presetInstructions: preset.instructions, inputText: inputText)
    }
}

private struct CreateResponseRequest: Encodable {
    let model: String
    let instructions: String
    let input: [InputMessage]

    struct InputMessage: Encodable {
        let role: String
        let content: String
    }
}

private struct CreateResponseResponse: Decodable {
    let output_text: String?
    let output: [OutputItem]?

    struct OutputItem: Decodable {
        let type: String?
        let role: String?
        let content: [ContentPart]?
    }

    struct ContentPart: Decodable {
        let type: String?
        let text: String?
    }

    func outputText() -> String {
        guard let output else { return "" }
        let assistantMessages = output.filter { ($0.type ?? "") == "message" && ($0.role ?? "") == "assistant" }
        let parts = assistantMessages.flatMap { $0.content ?? [] }
        let texts = parts.compactMap { part -> String? in
            guard (part.type ?? "") == "output_text" else { return nil }
            return part.text
        }
        return texts.joined()
    }
}
