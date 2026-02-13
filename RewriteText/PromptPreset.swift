import Foundation

struct PromptPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let instructions: String
}

extension PromptPreset {
    static let builtins: [PromptPreset] = [
        PromptPreset(
            id: "lowercase-genz",
            name: "Lowercase Gen Z",
            instructions: "rewrite the text in all lowercase in EXTREMELY gen z slang. keep meaning. do not add new facts. make it sound online, casual, and a little chaotic, but still readable. you can use slang like 'fr', 'no cap', 'lowkey', 'highkey', 'ngl', 'idk', 'imo', 'literally', 'vibes', 'ate', 'slay', 'its giving', 'mid', 'bet', 'ok bestie', 'go off'. do not overdo emoji; at most 1 emoji total."
        ),
        PromptPreset(
            id: "prompt-writer",
            name: "Prompt Writer",
            instructions: "rewrite the text into a clear, concise prompt with good instructions, constraints, and desired output. keep it natural and easy to paste into an ai chat box."
        ),
    ]

    static let defaultID: String = builtins.first?.id ?? "lowercase-genz"
}
