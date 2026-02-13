import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum SelectionRewriter {
    struct RewriteError: Error, CustomStringConvertible, LocalizedError {
        let message: String
        var description: String { message }
        var errorDescription: String? { message }
    }

    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func ensureAccessibilityPromptingIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func rewriteSelection(rewrittenTextProvider: @escaping (String) async throws -> String) async throws {
        let selectedText = try await captureSelectedText()
        let rewritten = try await rewrittenTextProvider(selectedText)
        try await replaceSelection(with: rewritten)
    }

    static func captureSelectedText() async throws -> String {
        guard ensureAccessibilityPromptingIfNeeded() else {
            throw RewriteError(message: "Accessibility permission is required to rewrite selection. Enable RewriteText in System Settings -> Privacy & Security -> Accessibility, then quit and relaunch RewriteText.")
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        defer { snapshot.restore(to: pasteboard) }

        let snapshotChangeCount = snapshot.changeCount

        postCommandKeyCombo(keyCode: CGKeyCode(kVK_ANSI_C))
        try await Task.sleep(nanoseconds: 200_000_000)

        if pasteboard.changeCount == snapshotChangeCount {
            throw RewriteError(message: "No selected text found.")
        }

        if let str = pasteboard.string(forType: .string), !str.isEmpty {
            return str
        }

        if let rtf = pasteboard.data(forType: .rtf),
           let attr = try? NSAttributedString(rtf: rtf, documentAttributes: nil) {
            let str = attr.string
            if !str.isEmpty { return str }
        }
        if let rtfd = pasteboard.data(forType: .rtfd),
           let attr = try? NSAttributedString(rtfd: rtfd, documentAttributes: nil) {
            let str = attr.string
            if !str.isEmpty { return str }
        }

        throw RewriteError(message: "No selected text found.")
    }

    static func replaceSelection(with text: String) async throws {
        guard ensureAccessibilityPromptingIfNeeded() else {
            throw RewriteError(message: "Accessibility permission is required to rewrite selection. Enable RewriteText in System Settings -> Privacy & Security -> Accessibility, then quit and relaunch RewriteText.")
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        defer { snapshot.restore(to: pasteboard) }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        postCommandKeyCombo(keyCode: CGKeyCode(kVK_ANSI_V))
        try await Task.sleep(nanoseconds: 150_000_000)
    }

    private static func postCommandKeyCombo(keyCode: CGKeyCode) {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

private struct PasteboardSnapshot {
    let changeCount: Int
    private let itemsData: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        changeCount = pasteboard.changeCount
        itemsData = (pasteboard.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let items: [NSPasteboardItem] = itemsData.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
