# RewriteText: Global Hotkey Rewrite With Prompt Presets (macOS)

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repo did not include a `PLANS.md`, so we copied the plan rules to `.agent/PLANS.md`. This ExecPlan must be maintained in accordance with `.agent/PLANS.md`.

## Purpose / Big Picture

After this change, on macOS you can highlight text in nearly any app (browser, notes, chat boxes), press a single global keyboard shortcut, and have that text rewritten by an LLM using the currently selected “prompt filter” (a preset). The rewritten text is then pasted back in place, so the workflow is “select, hotkey, replaced”.

We keep it simple by using the system clipboard to capture the current selection (simulate Copy), sending it to OpenAI’s Responses API using model `gpt-5.2`, and then simulating Paste to replace the selection. We do not build voice transcription in this iteration; this feature still supports dictation workflows if the user dictates into any textbox and then highlights the text to rewrite.

Security note: we will not implement code that searches your home directory for API keys. Instead, we will add a single explicit configuration path for the OpenAI API key (a settings field stored in the Keychain, or an environment variable for development) and provide a small smoke check to validate the key works.

## Progress

- [x] (2026-02-13 16:55Z) Establish OpenAI key configuration and a repeatable smoke check against the Responses API.
- [x] (2026-02-13 16:55Z) Convert the macOS app into a menu bar app with prompt preset selection UI and a visible “current preset”.
- [x] (2026-02-13 16:55Z) Implement global hotkey registration and a debounced “rewrite current selection” action.
- [x] (2026-02-13 16:55Z) Implement selection capture via clipboard (simulate Cmd+C) and in-place replacement via paste (simulate Cmd+V), including Accessibility permission prompting.
- [x] (2026-02-13 16:55Z) Implement OpenAI Responses API client for `gpt-5.2`, with minimal logging to learn response shape and robust error surfacing.
- [x] (2026-02-13 16:55Z) End-to-end validation: app builds successfully; manual runtime validation steps documented below (requires API key + Accessibility permission).

## Surprises & Discoveries

- Observation: (fill in during implementation) macOS privacy controls may block synthetic key events unless the app is granted Accessibility permissions.
  Evidence: (paste a short error transcript or describe the observed behavior).

- Observation: (fill in during implementation) The exact JSON shape of the Responses API output may differ from assumptions; we will log the raw response during the first integration.
  Evidence: (paste a short excerpt with secrets removed).

- Observation: `SettingsLink` is only available starting macOS 14, but this app targets macOS 13.0.
  Evidence: Swift compiler error referencing `SettingsLink` availability; implemented Settings window opening via `NSApp.sendAction(Selector(("showSettingsWindow:")), ...)` instead.

- Observation: The `NSAttributedString(pasteboard:documentAttributes:)` initializer is not available in the current SDK, so pasteboard selection extraction uses `.string` and falls back to `.rtf` / `.rtfd` data decoding.
  Evidence: Swift compiler error listing available `NSAttributedString` initializers.

## Decision Log

- Decision: Build a macOS menu bar app with a global hotkey, rather than a pure “Services” or Safari extension workflow.
  Rationale: It provides the simplest “works everywhere” UX without needing per-app integration. A menu bar app can hold prompt presets and the OpenAI key, and can run continuously.
  Date/Author: 2026-02-13 / Codex

- Decision: Use clipboard-based selection capture (simulate Copy) rather than attempting to read selected text via per-app Accessibility attributes.
  Rationale: Clipboard copy/paste is the most broadly compatible way to get selected text from arbitrary apps with minimal app-specific code.
  Date/Author: 2026-02-13 / Codex

- Decision: Do not scan arbitrary directories for `.env` files or API keys.
  Rationale: It is unsafe and surprising behavior. We will support explicit configuration: paste key once into the app (Keychain) or provide it as an environment variable during development.
  Date/Author: 2026-02-13 / Codex

- Decision: Target macOS 13.0 and implement Settings menu opening without `SettingsLink`.
  Rationale: `SettingsLink` requires macOS 14+. We keep compatibility with the existing deployment target and avoid raising it unnecessarily.
  Date/Author: 2026-02-13 / Codex

## Outcomes & Retrospective

- Outcome: The app is now a macOS menu bar app with two built-in prompt presets, a global hotkey (`Cmd+Shift+R`), a “Rewrite Selection Now” menu item, and a Settings window for storing an OpenAI API key in Keychain.

- Outcome: Rewriting uses a clipboard-based pipeline (Cmd+C capture, Responses API call to `gpt-5.2`, Cmd+V paste) and restores the user clipboard afterward.

- Gap: Runtime validation requires manual action: provide a working API key (Settings or `OPENAI_API_KEY`) and grant Accessibility permission so synthetic copy/paste events are allowed. See `Validation and Acceptance` for the manual steps.

## Context and Orientation

Current repository state is a minimal macOS SwiftUI app generated by XcodeGen:

- `project.yml` defines a single macOS application target named `RewriteText` with sources under `RewriteText/`.
- `RewriteText/RewriteTextApp.swift` starts the app and shows `ContentView` in a window.
- `RewriteText/ContentView.swift` shows a placeholder "Hello, world!" view.
- `RewriteText.xcodeproj` is generated output from `xcodegen generate`.

Terms used in this plan:

- “Prompt preset” (or “prompt filter”): a named rewrite mode the user can select (like radio buttons). Each preset corresponds to instructions that are applied to the text before returning the rewrite.
- “Global hotkey”: a keyboard shortcut that works even when RewriteText is not the frontmost app.
- “Accessibility permission”: macOS permission (Privacy & Security -> Accessibility) required for an app to control other apps, including posting synthetic key events for copy/paste.
- “Responses API”: OpenAI HTTP API endpoint that takes an input prompt and returns a generated text response.

## Plan of Work

We will implement the feature in small, observable steps:

First, we will establish a reliable way to provide an OpenAI API key and verify it with a simple smoke request to the Responses API using model `gpt-5.2`. This avoids debugging the UI and hotkey while the API is not working.

Next, we will refactor the app into a macOS menu bar app that has a simple UI to choose among a few built-in prompt presets (two to start), shows the currently selected preset, and has a “Rewrite Selection Now” menu item for manual triggering (useful while hotkey work is in progress).

Then we will add global hotkey registration (default `Cmd+Shift+R`) and wire it to the same “rewrite selection” action as the menu item.

After that we will implement the core selection-rewrite-replace pipeline:

1. Capture selected text by simulating `Cmd+C`, reading the clipboard, and restoring the user’s previous clipboard contents.
2. Send captured text to the OpenAI client with the active preset instructions.
3. Replace the selected text by setting the clipboard to the rewritten result and simulating `Cmd+V`, then restoring the clipboard.

Finally, we will validate behavior across several apps and document limitations (for example, apps that block programmatic paste).

## Concrete Steps

All commands below assume working directory `/Users/georgepickett/rewrite-text`.

1. Generate the Xcode project if needed:

   Run:

       cd /Users/georgepickett/rewrite-text && xcodegen generate

   Expect: a `RewriteText.xcodeproj` exists and `xcodebuild -list -project RewriteText.xcodeproj` shows scheme `RewriteText`.

2. Create a minimal OpenAI smoke check and key handling:

   Add `.env.example` at repo root that contains a single line `OPENAI_API_KEY=...`.

   Add a small script `scripts/openai_smoke.sh` that reads `OPENAI_API_KEY` from the environment (the user can `source .env` manually in their shell), sends a single `curl` request to `https://api.openai.com/v1/responses` with model `gpt-5.2` and a tiny input like “Respond with the single word OK.”, and prints HTTP status plus the response body (never print the API key).

   Expect: running the script prints HTTP 200 and a response payload containing an “OK”-like output.

3. Convert the app to a menu bar app:

   In `RewriteText/RewriteTextApp.swift`, use SwiftUI `MenuBarExtra` (macOS 13+) as the primary UI surface.

   Add menu items for: current preset (radio style), preset list (two built-ins initially), “Rewrite Selection Now”, “Settings…”, and “Quit”.

4. Add settings for the OpenAI API key and selected preset:

   Add a Settings window view (for example `RewriteText/SettingsView.swift`) with a secure text field to paste the API key and a short help text explaining how to grant Accessibility permission and what the hotkey is.

   Store the API key in the macOS Keychain (not in UserDefaults, not committed to git). Store the selected preset identifier in `UserDefaults`.

5. Implement global hotkey and permissions:

   Add a small hotkey manager using Carbon `RegisterEventHotKey` (default: `Cmd+Shift+R`).

   Add an Accessibility permission check using `AXIsProcessTrustedWithOptions` to prompt the user to grant permissions when they first attempt to rewrite selection.

   Ensure the hotkey triggers the same handler as the menu item.

6. Implement selection capture and replacement:

   Implement a single function “rewriteCurrentSelection()” with this behavior: save the current clipboard contents; send synthetic `Cmd+C` to the frontmost app and wait briefly; read the copied selection text from the clipboard and, if empty, show a user-facing error (“No selected text found”); call the OpenAI client with the selected preset and the captured text; then save clipboard again, set clipboard to the rewritten output, send synthetic `Cmd+V`, and finally restore the clipboard.

   Ensure only one rewrite runs at a time (ignore hotkey presses while a request is in flight).

7. Implement OpenAI Responses API client:

   Add `RewriteText/OpenAIClient.swift` that builds a request to `POST /v1/responses` with Authorization header and sends the user’s selected text plus preset instructions.

   During the first implementation, log the raw JSON response body at info level with sensitive fields removed, so we can confirm the response shape and write a correct parser. The client must return a single rewritten string or an actionable error message.

## Validation and Acceptance

Acceptance is user-visible behavior, validated manually:

1. API smoke check: With `OPENAI_API_KEY` set in the shell, running `scripts/openai_smoke.sh` returns HTTP 200 and prints a payload containing an “OK” response.

2. Menu bar UX: Launching the app shows a menu bar item. The menu shows preset choices; selecting a preset updates which prompt is used for subsequent rewrites.

3. Rewrite flow: In at least three apps (for example: Notes, Safari, TextEdit), highlight a sentence, press `Cmd+Shift+R`, and the text is replaced with a rewritten version within a reasonable time. If no text is selected, pressing the hotkey shows a clear error (no silent failure). If the API key is missing or invalid, the app shows a clear error and offers a path to Settings to set the key.

4. Presets: Preset “Lowercase Gen Z” produces lowercase output with casual “gen z” tone. Preset “Prompt Writer” rewrites dictated/rough text into clear, well-structured instructions suitable for pasting into AI chat boxes.

## Idempotence and Recovery

`xcodegen generate` can be run multiple times safely; it rewrites `RewriteText.xcodeproj`.

The rewrite action should restore the clipboard on both success and failure. If an in-flight rewrite fails (network error, missing permission), the user’s clipboard and selected text should not be left in a broken state; show an error and do not paste partial results.

## Artifacts and Notes

Initial built-in presets (names and intent; exact wording can be adjusted during implementation):

- Lowercase Gen Z: Rewrite the text in all lowercase with a casual, modern tone; keep meaning; do not add new facts.
- Prompt Writer: Rewrite the text to be a clear, concise prompt with good instructions, constraints, and desired output; keep it natural and easy to paste into an AI chat box.

## Interfaces and Dependencies

We will use:

- SwiftUI for UI (`MenuBarExtra` and a small Settings window).
- URLSession for HTTPS calls to OpenAI.
- Carbon hotkey APIs for a global hotkey.
- ApplicationServices / Accessibility APIs for permission prompting and synthetic key events (copy/paste).
- Keychain Services for storing the API key securely.

We will not add third-party packages or additional Xcode targets unless we hit a hard blocker.

Change note: Initial plan authored from the user’s brainstorming and the existing minimal macOS SwiftUI project structure. The key decision to avoid scanning the filesystem for secrets is recorded in `Decision Log` for safety and predictability.
