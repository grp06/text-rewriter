# Text Rewriter

A tiny macOS menu bar app that rewrites whatever text you have selected, anywhere on your Mac.

Highlight text, hit a global hotkey, and it:

1. Copies the selection (Cmd+C).
2. Sends it to an LLM (OpenAI Responses API, model `gpt-5.2`) with your chosen preset.
3. Pastes the rewritten result back in place (Cmd+V).

It is intentionally simple: a couple of “prompt filter” presets, one hotkey, and you are back to typing.

## Features

- Works in most apps: browsers, Notes, chat boxes, editors.
- Presets (radio-button style):
  - Lowercase Gen Z (super slang)
  - Prompt Writer (turn rough dictation into a clean, paste-ready prompt)
- Global hotkey: `Cmd+Esc`
- Menu item: "Rewrite Selection Now"
- API key stored in macOS Keychain (or use `OPENAI_API_KEY`)
- Restores your clipboard after rewriting

## Requirements

- macOS 13+
- Xcode
- XcodeGen (`brew install xcodegen`)
- An OpenAI API key

## Run Locally

Generate the Xcode project:

    cd /Users/georgepickett/rewrite-text
    xcodegen generate
    open /Users/georgepickett/rewrite-text/RewriteText.xcodeproj

In Xcode:

1. Select scheme `RewriteText`
2. Destination `My Mac`
3. Run

## First-Time Setup (Important)

1. Open Settings from the menu bar icon.
2. Paste your OpenAI API key and click "Save Key".
3. Grant Accessibility permission so the app can send Cmd+C / Cmd+V to other apps:

   System Settings -> Privacy & Security -> Accessibility -> enable `RewriteText`

If you enabled it but still get prompted, quit and relaunch RewriteText. Accessibility permission is tied to the currently running build/signature.

## Smoke Test The OpenAI Key (Optional)

    cd /Users/georgepickett/rewrite-text
    export OPENAI_API_KEY="sk-..."
    ./scripts/openai_smoke.sh

## Notes

- This app automates copy/paste. Some apps may block synthetic key events.
- It will never commit your secrets: `.env` is ignored; only `.env.example` is included.

