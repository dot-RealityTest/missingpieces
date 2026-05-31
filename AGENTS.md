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
- **Popover motion:** shared `PopoverMotion` springs/transitions for expand, copy, and list changes; respect Reduce Motion (skip decorative animation when enabled).
- Work session headers use **pastel accent arrows** (tinted section colors), not plain chevrons; keep row titles calm grey for scanning.
- When Pieces OS is already running, expect the agent to verify connectivity and launch or rebuild the app for smoke testing.

## Learned Workspace Facts

- **missingpieces** is a macOS 14+ menu bar app (SwiftUI `MenuBarExtra`, `.window` style, `LSUIElement` — no Dock icon) using Swift 6 and `@Observable` `AppState`. No SwiftData. Git repo folder is still `PiecesTask/`.
- Git repo: **`main`** is the lean product (Pieces fetch + list + local mark-done). **`lean-core`** keeps the older fuller build (Ollama, hotkey, undo, etc.) for reference.
- Pieces OS is reached on localhost via `PiecesService` with cached port + health checks (typically `39300`, fallback `1000`); application ID `app.missingpieces`.
- Inbound flow: `POST /materials/identifiers` (recent `WORKSTREAM_SUMMARIES`) → `GET /workstream_summary/{id}` → `GET /annotation/{id}` for `SUMMARY` text → `PiecesNextStepsParser` extracts `### **Next Steps**` bullets; `displayTitle` / `displaySubtitle` shorten row text for scanning.
- Popover title: “What you're missing”. Empty state: “You're caught up”. Header: **Check again**, Settings — no Open Pieces OS launcher. List grouped by work session (`AttentionSection`); footer shows tap/done hint and loading state.
- `MenuBarStatusIcon` / `AppStatusGlyphView`: shared app icon + status dot for menu bar and popover header.
- `PopoverGlassBackground` / `PopoverSurfaceModifier`: Liquid Glass on macOS 26+, vibrancy fallback on earlier macOS; `PopoverLayout` sizes the popover (~360× up to ~45% of screen height).
- Settings (`AppSettings` + `SettingsView`): fixed ~480×292 window via **`SettingsWindowPresenter`** (368pt when marked-done restore is shown); single sheet (no tabs): refresh-on-open, lookback, **Show up to** cap, manual refresh, marked-done count + restore; connection status in header subtitle only.
- Fetch uses lookback + visible cap only; fetches enough rows to fill the list after marked-done filtering.
- `FollowUpItemID`: stable SHA256-based IDs from summary ID + normalized step text for local mark-done persistence.
- Right-click menu bar: AppKit `MenuBarRightClickMenu` + `MenuBarStatusItemFinder` (SwiftUI `.contextMenu` does not work with `.window` style).
- Debug: `xcodebuild -project PiecesTask.xcodeproj -target missingpieces -configuration Debug build`; run `python3 generate_xcode.py` after adding Swift files. Release: `./scripts/release.sh` → Developer ID–signed `missingpieces.app` + `release/missingpieces-1.0.0-b2.dmg` (v1.0.0 build 2; signed, notarized, and stapled).
