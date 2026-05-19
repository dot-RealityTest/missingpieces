# PiecesTask — catch-up before you code

> **Before you code** — read the headline and action list, then stop if you're ready.
> **The rest** — updates, tools, skills, and links.

---

## Before you code

**Headline:** Safe to open and build again—you are not missing a breaking stack change—but finish or delete the half-wired Pieces sync before adding features.

**Do these first (if any):**

1. Run a quick build to confirm your Mac still compiles it: `xcodebuild -project PiecesTask.xcodeproj -target PiecesTask -configuration Debug build` (see `PROJECT_GUIDE.md`).
2. Start **Pieces OS**, open the app, and confirm Settings → Pieces shows **Connected**.
3. If you target **macOS 26** (Tahoe) soon: read Apple’s note that status bar internals changed (`NSSceneStatusItem`)—only matters if you add libraries that poke at `NSStatusItem` directly; your plain `MenuBarExtra` is fine for now.
4. Before editing API calls: skim the official **Pieces OS TypeScript SDK** (annotations / workstream) if raw REST paths fail—your app uses hand-rolled `POST /annotations` and `GET /workstream_events`, which may not match every Pieces OS version.

**You can ignore for now:** Moving to Swift 6.2 “approachable concurrency” project-wide, Liquid Glass redesign, App Intents, TestFlight—none are required to resume this repo.

---

## The rest (optional)

### Your stack snapshot

| Piece | In this project | Note |
|-------|-----------------|------|
| macOS deployment | 14.0 (`Info.plist`, Xcode) | Your machine may run macOS 26 SDK via Xcode 26.x |
| Swift | 6.0 | Matches current Xcode Swift 6 language mode |
| UI | SwiftUI `MenuBarExtra`, `.window` style | Modern menu bar panel pattern |
| State | `@Observable` `AppState` | Already on Observation, not legacy `ObservableObject` |
| Data | SwiftData `@Model` `TaskItem` | Local persistence, no CloudKit in project |
| Pieces | HTTP `localhost:1000` | Health: `/.well-known/health`; custom REST paths in `PiecesService` |
| Git | Not initialized in folder | No `git log` for this root |
| README / docs | None | You now have `PROJECT_GUIDE.md` |

### Must know

| What | Why it matters to you | Source |
|------|----------------------|--------|
| **Pieces integration in code ≠ product behavior** | UI suggests sync; `saveTask` is never called from add/complete flows | This repo (`AppState`, `AddTaskView`) |
| **Menu bar Settings on macOS 26** | `SettingsLink` / focus issues reported for menu bar apps; you use `NSApp.sendAction(Selector(("showSettingsWindow:")), ...)` | [Zachary Armstead — menu bar settings](https://zacharmstead.com/posts/2025/showing-settings-from-macos-menu-bar-items), [Apple MenuBarExtra](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra) |
| **Pieces SDK moved (mid-2025)** | If you switch from raw HTTP to SDK, annotation APIs had large updates in TS SDK 4.x | [pieces-os-client-sdk-for-typescript](https://github.com/pieces-app/pieces-os-client-sdk-for-typescript) |

### Worth a look — updates & features

- **Swift Observation / `@Observable`:** You already use it for `AppState`; when touching views, prefer `@Environment(AppState.self)` and `@Bindable` patterns per [Apple’s migration guide](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro).
- **SwiftData:** iOS/macOS 26 guides emphasize migrations and production patterns if you add fields to `TaskItem`—plan a schema bump before shipping widely. [Swift Crafted SwiftData guide](https://swiftcrafted.dev/article/swiftdata-from-zero-to-production-models-queries-migrations-and-performance).
- **MenuBarExtra:** Community package [MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) updated for macOS 26 if you need programmatic menu control later—optional, not in your project today.

### Worth a look — tools & integrations

- **Pieces MCP in Cursor** (you already use it): `search_memory`, `ask_pieces_ltm`, `create_pieces_memory` often replace custom REST for agent workflows—useful alongside this app, not a duplicate of it.
- **Things 3 / Apple Reminders (2025–2026):** Reminders gained smarter lists and AI-adjacent features; Things still wins on calm UX for pure tasks—relevant if you question building another list app. [Things vs Reminders discussion](https://medium.com/the-mac-alchemist/things-3-vs-apple-reminders-i-paid-60-for-a-to-do-app-was-i-wrong-7161737e19d5).

### Worth a look — Cursor skills & MCP

| Name | What it helps with | How to try |
|------|-------------------|------------|
| `macos-menubar-swiftui` / `swiftui-menu-bar-extra-patterns` | Menu bar app structure | In Cursor: `@` skill name or install from your Codex skill library |
| `xcodebuildmcp-cli` / `ios-debugger-agent` | Build and run from agent | AGENTS.md in home folder references XcodeBuildMCP |
| `pieces-integration` / Pieces MCP rule | LTM, workstream, memories | Already in workspace rules (`pieces-mcp.mdc`) |
| `explain-new-project` / `project-worth-my-time` / `project-catch-up` | Onboarding docs for any repo | You just used these on PiecesTask |

**Learn:** An **MCP server** is a plug-in that lets Cursor talk to a local app (like Pieces) with structured tools instead of you copying context by hand.

### Nice to have

- Add a minimal `README.md` pointing to `PROJECT_GUIDE.md` and build commands.
- `git init` + first commit after your next working session.
- App icon in `PiecesTaskAssets.xcassets` (catalog exists; icon set may be empty).
- Wire **Launch at Login** properly (`ServiceManagement`) if you rely on menu bar apps daily.

### Ignore for now

- Rewriting in Tuist or SPM-only unless you are standardizing all Mac apps that way.
- Competing with Things/Reminders on features (locations, collaboration, AI lists).
- macOS 26 Liquid Glass pass before core Pieces sync works.

### When you last worked on this

**About May 12, 2026** (evening): built with `xcodebuild`, opened `PiecesTask.app`, iterated `PiecesService` and settings in Xcode/Lapapi sessions. No strong evidence of edits in the last ~4 days before today (May 16, 2026); your attention has been on Lapapi, V8V/KIKA sites, and other shipping work.

### Sources checked

- Project source files under `/Users/kika_hub/Projects/PiecesTask/PiecesTask/`
- Pieces LTM (`get_user_persona`, `ask_pieces_ltm`) — May 2026 activity
- [Apple MenuBarExtra documentation](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra)
- [MenuBarExtraAccess macOS 26 issue](https://github.com/orchetect/MenuBarExtraAccess/issues/20)
- [Observable migration (Apple)](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [Pieces OS TypeScript SDK repo](https://github.com/pieces-app/pieces-os-client-sdk-for-typescript)
- Web search: Things 3 vs Reminders 2025–2026, Cursor menu bar skill tools
