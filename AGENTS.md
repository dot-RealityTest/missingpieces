## Learned User Preferences

- Prefer plain, everyday language in project docs and explanations (short sentences, minimal jargon; audience is self-taught, not CS-trained).
- Pieces integration is the top priority when resuming work on this repo.
- Product model is **Pieces-only and read-only**: the app shows “next steps” from recent Pieces workstream summaries; it does not maintain a local task list or push tasks to Pieces.
- Avoid aggressive automatic capture; refresh when the user opens the popover (if that toggle is on) or taps Check again — not background polling.
- Care about a **compact, premium** glanceable UI: popover and Settings should fit in the window without scrolling; cap visible rows, group next steps by work session, fit the screen; **calm grey** next-step row text on titles with optional one-line action subtitle.
- Do not add an **Open Pieces OS** button in the popover header — use the status dot and Settings for connection context.
- Menu bar status should be obvious: custom **`MenuBarIcon`** puzzle-piece asset with a small dot (green = connected, blue = has follow-ups, gray = offline, orange = problem).
- Popover should feel **glassy** (Liquid Glass on macOS 26+); Settings uses **`settingsWindowBackground()`** sidebar vibrancy — not popover glass/container APIs (stacking those on the Settings window caused freezes); Settings **auto-saves** toggles and pickers.
- **Follow-up triage (local only):** click row to expand full text, double-click to copy; right-click → Mark done / Copy; restore marked-done items in Settings.
- When Pieces OS is already running, expect the agent to verify connectivity and launch or rebuild the app for smoke testing.

## Learned Workspace Facts

- PiecesTask is a macOS 14+ menu bar app (SwiftUI `MenuBarExtra`, `.window` style, `LSUIElement` — no Dock icon) using Swift 6 and `@Observable` `AppState`. No SwiftData.
- Git repo: branch **`mvp-trim`** is the trimmed core (Pieces fetch + list + local mark-done only). **`lean-core`** / **`main`** hold fuller builds with Ollama, global shortcut, undo banner, launch-at-login, and Connections settings tab.
- Pieces OS is reached on localhost via `PiecesService` with dynamic port discovery (typically `39300`, fallback `1000`; caches port and can read `OS#port` from Pieces logs); application ID `app.piecestask`.
- Inbound flow: `POST /materials/identifiers` (recent `WORKSTREAM_SUMMARIES`) → `GET /workstream_summary/{id}` → `GET /annotation/{id}` for `SUMMARY` text → `PiecesNextStepsParser` extracts `### **Next Steps**` bullets; `displayTitle` / `displaySubtitle` shorten row text for scanning.
- Popover title: “What you're missing”. Empty state: “You're caught up”. Header: **Check again**, Settings — no Open Pieces OS launcher. List grouped by work session (`AttentionSection`); footer shows tap/done hint and loading state.
- `MenuBarStatusIcon` / `AppStatusGlyphView`: shared app icon + status dot for menu bar and popover header.
- `PopoverGlassBackground` / `PopoverSurfaceModifier`: Liquid Glass on macOS 26+, vibrancy fallback on earlier macOS; `PopoverLayout` sizes the popover (~360× up to ~45% of screen height).
- Settings (`AppSettings` + `SettingsView`): fixed ~480×400 window via **`SettingsWindowPresenter`**; single scroll sheet (no tabs): refresh-on-open, lookback, **Show up to** cap, manual refresh, marked-done count + restore; connection status in header subtitle only.
- Fetch uses lookback + visible cap only; fetches enough rows to fill the list after marked-done filtering.
- Right-click menu bar: AppKit `MenuBarRightClickMenu` + `MenuBarStatusItemFinder` (SwiftUI `.contextMenu` does not work with `.window` style).
- Build with `xcodebuild -project PiecesTask.xcodeproj -target PiecesTask -configuration Debug build`; run `python3 generate_xcode.py` after adding new Swift files under `PiecesTask/`.
