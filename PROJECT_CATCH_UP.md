# PiecesTask — catch-up before you code

> **Before you code** — read headline + action list, then stop if ready.
> **The rest** — optional depth.

---

## Before you code

**Headline:** You can pick up safely—the app is now a **read-only Pieces “next steps” glance** with glass UI and local triage—but **`PROJECT_GUIDE.md` and this file’s older version were wrong** (they still described a SwiftData to-do app). Build, smoke-test Pieces on port **39300**, then commit or trim the large uncommitted polish on `main`.

**Do these first (if any):**

1. **Build and launch** (Pieces OS running):  
   `xcodebuild -project PiecesTask.xcodeproj -target PiecesTask -configuration Debug build` → `open build/Debug/PiecesTask.app`  
   Settings → **Connections** → test Pieces + Ollama.
2. **Refresh `PROJECT_GUIDE.md`** — remove to-do/SwiftData/outbound-sync wording; match “What you're missing”, glass Settings, ⌃⌥P shortcut, triage (save/snooze/hide), prompt-only Ollama brief line.
3. **Decide on git** — one initial commit exists (2026-05-19); many local changes (glass, icons, triage, summary prompt, hotkey) are still uncommitted. Commit when the build feels right, or stash what you do not want.
4. **Ollama summary check** — tap sparkles after a refresh; confirm the chip is one short line (prompt enforces 6–10 words, `think: false`). If a thinking model still leaks tags, switch model or tighten the prompt (known Ollama quirk on some models).

**You can ignore for now:** Outbound task sync to Pieces, SwiftData, App Intents, TestFlight, full Swift 6.2 concurrency migration, replacing Carbon hotkeys unless you sandbox the app.

---

## The rest (optional)

### Your stack snapshot

| Piece | In this project | Note |
|-------|-----------------|------|
| macOS | **14.0** deployment (`Info.plist`, Xcode) | Liquid Glass path on **macOS 26+**, vibrancy fallback below |
| Swift | **6.0** | `@Observable` `AppState`; no SwiftData |
| UI | `MenuBarExtra` **`.window`**, `LSUIElement` | AppKit bridge for menu bar right-click + global hotkey |
| Pieces | `PiecesService` → localhost **39300** (fallback **1000**) | Inbound only: workstream summaries → SUMMARY annotations → **Next Steps** parser |
| Ollama | `OllamaService` | Tags + generate; **`think: false`** for brief summary |
| Persistence | **UserDefaults** | Settings, hidden/saved/snoozed follow-up IDs |
| Build | `xcodebuild` + `python3 generate_xcode.py` after new `.swift` files | Bundle ID `app.piecestask` |
| Git | **`main`**, initial commit 2026-05-19 | Large working tree since polish session |
| Agent memory | `AGENTS.md` (project) | Pieces-first, read-only, compact glass UI |

### Must know

| What | Why it matters | Severity |
|------|----------------|----------|
| **Product model changed** | No local task list; no push to Pieces. UI is follow-ups from workstream summaries + local hide/save/snooze only. | **Must know** |
| **`PROJECT_GUIDE.md` is stale** | Still says menu bar to-do, SwiftData, header “Open Pieces OS”. Code and `AGENTS.md` disagree—fix guide before trusting docs. | **Must know** |
| **Pieces port** | Docs and blogs standardize on **39300**; your service already discovers port (logs/cache). Health on wrong port = gray dot, empty list. | **Must know** |
| **Uncommitted polish** | Glass Settings, custom menu bar asset, triage + undo banner, ⌃⌥P, summary prompt tuning—verify before next feature. | **Must know** |
| **Ollama `think: false`** | Required for short summaries; some thinking models may still leak ``-style tags ([Ollama #11010](https://github.com/ollama/ollama/issues/11010)). | **Worth a look** |

### Worth a look — updates & features

- **Liquid Glass (macOS 26):** Apple’s WWDC25 design pushes `.glassEffect()` and updated toolbars; your `PopoverGlassBackground` / `settingsGlassChrome` already gate on OS version—no need to bump deployment target unless you drop pre-26 support. [WWDC25 session 323](https://developer.apple.com/videos/play/wwdc2025/323/)
- **Swift Observation:** You already use `@Observable`; when touching views, keep `@Environment(AppState.self)` / `@Bindable` patterns per [Apple migration guide](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro).
- **Menu bar on macOS 26:** Status item internals shifted (`NSSceneStatusItem`); plain `MenuBarExtra` + custom `NSImage` (your puzzle-piece + dot) is still the right pattern unless you depend on private status-item hacks.
- **Pieces MCP truncation:** `ask_pieces_ltm` may truncate long `combined_string` fields (~400 chars)—use `workstream_summaries_batch_snapshot` or repo files for full context, not only MCP summaries. [pieces-app/support#992](https://github.com/pieces-app/support/issues/992)

### Worth a look — tools & integrations

- **Pieces MCP (Cursor):** `material_identifiers`, `workstream_summaries_batch_snapshot`, `search_memory` complement the app—good for agent debugging, not a replacement for in-app refresh.
- **Pieces OS TypeScript SDK:** If REST paths drift, compare `PiecesService` with [pieces-os-client-sdk-for-typescript](https://github.com/pieces-app/pieces-os-client-sdk-for-typescript) before hand-rolling more endpoints.
- **Global shortcut:** Your `GlobalHotKeyService` likely uses Carbon `RegisterEventHotKey`—fine for a non-sandbox menu bar utility; sandboxed / App Store builds would need **Input Monitoring** + `CGEventTap` or [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) instead.

### Worth a look — Cursor skills & MCP

| Skill / MCP | Use on this repo |
|-------------|------------------|
| `pieces-integration` + **user-pieces** MCP | Debug workstreams, last-session context, memories |
| `macos-menubar-swiftui` / `swiftui-menu-bar-extra-patterns` | Menu bar + `.window` popover patterns |
| `swiftui-glass-ui` / `liquid-glass-design` | Glass chrome tuning |
| `xcodebuildmcp-cli` | Build/run from agent (per home `AGENTS.md`) |
| `ollama-model-picker-ux` / `ollama-error-handling` | Model list + connectivity tests |
| `macos-global-shortcuts` | Review ⌃⌥P implementation |
| `project-catch-up` / `explain-new-project` | Docs you are reading now |

### Nice to have

- Align **README** (if added) → single link to `PROJECT_GUIDE.md`.
- **Commit** after smoke test: icons, glass Settings, triage, hotkey, summary prompt.
- **Featured image / App Store** assets if you ship beyond personal use.
- **Launch at login** — confirm `ServiceManagement` behavior if you rely on always-on menu bar presence.

### Ignore for now

- Rewriting in Tuist/SPM-only unless you standardize all Mac apps that way.
- Competing with Things / Reminders feature depth.
- Moving every hotkey to sandbox-friendly APIs before you need distribution.
- Full macOS 26–only Liquid Glass (dropping macOS 14–25 vibrancy fallback).

### When you last worked on this

- **Pieces LTM:** Heavy **2026-05-18** evening sessions—Pieces integration first, pivot to **read-only** follow-ups, UI polish, continual-learning on `AGENTS.md`, build/launch loops in Cursor.
- **Git:** Last commit **2026-05-19** — “Initial commit: PiecesTask with polished menu bar and settings UI.”
- **Since then (agent/context):** Glass Settings matching popover, custom menu bar icon, follow-up triage + undo, global ⌃⌥P, Ollama brief-line prompt (no UI ellipsis chop), summary panel expand behavior—mostly **uncommitted** as of **2026-05-22**.

### Sources checked

- `/Users/kika_hub/Projects/PiecesTask/PROJECT_GUIDE.md`, `AGENTS.md`, `Info.plist`, `project.pbxproj`
- Pieces MCP: `time_compute` (now), `ask_pieces_ltm` (PiecesTask activity)
- `git log -1` (2026-05-19)
- [Apple MenuBarExtra](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra), [WWDC25 Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Ollama thinking / `think` parameter](https://docs.ollama.com/capabilities/thinking), [Ollama issue #11010](https://github.com/ollama/ollama/issues/11010)
- [Pieces OS port 39300 / MCP](https://docs.pieces.app/products/mcp/google-gemini-cli), [MCP truncation issue](https://github.com/pieces-app/support/issues/992)
- [Apple DTS on global hotkeys](https://developer.apple.com/forums/thread/735223), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- Web: Swift 6.2 / macOS 26 menu bar + Liquid Glass summaries (May 2026)
