## Learned User Preferences

- Prefer plain, everyday language in project docs and explanations (short sentences, minimal jargon; audience is self-taught, not CS-trained).
- Pieces integration is the top priority when resuming work on this repo.
- Product model is **Pieces-only and read-only**: the app shows “next steps” from recent Pieces workstream summaries; it does not maintain a local task list or push tasks to Pieces.
- Avoid aggressive automatic capture; refresh when the user opens the popover (if that toggle is on) or taps Check again — not background polling.
- Care about a **compact, premium** glanceable UI: popover and Settings should fit in the window without scrolling; cap visible rows, group next steps by work session, fit the screen; **calm grey** next-step row text with **pastel section accents** on headers/icons only (not titles).
- Do not add an **Open Pieces OS** button in the popover header — use the status dot and Settings for connection context.
- Menu bar status should be obvious: custom **`MenuBarIcon`** puzzle-piece asset with a small dot (green = connected, blue = has follow-ups, gray = offline, orange = problem).
- Popover should feel **glassy** (Liquid Glass on macOS 26+); **Settings uses the same glass chrome** (`settingsGlassChrome`, `SettingsGlassSection`); **SettingsDraft** — prefs edit in draft until **Apply** or **Save**; footer **Cancel / Apply / Save** + header **×** close (discard without save); header toolbar uses plain borderless icon buttons, not heavy glass pills.
- **Follow-up triage (local only):** right-click → **Hide**; brief **Undo** banner after accidental hides. **Global shortcut** ⌃⌥P toggles the popover (on by default in Settings → General).
- Ollama: **local only**; prefer **light local models** for summaries; summaries must use **`think: false`**; connectivity test must **not** change the user’s selected model unless it is empty or no longer on the server.
- Ollama AI summary: one **brief verb-first line** enforced in the **prompt** (`think: false`, ~40 tokens); **do not** chop follow-up row text with ellipsis; sparkles expand chip shows the **follow-up list**, not a long AI paragraph.
- When Pieces OS is already running, expect the agent to verify connectivity and launch or rebuild the app for smoke testing.

## Learned Workspace Facts

- PiecesTask is a macOS 14+ menu bar app (SwiftUI `MenuBarExtra`, `.window` style, `LSUIElement` — no Dock icon) using Swift 6 and `@Observable` **`AppState.shared`**. No SwiftData. No `AppModel` wrapper.
- Git repo: feature branch **`lean-core`** trims save/snooze, notifications, and Ollama cloud; **`main`** holds prior fuller build.
- Pieces OS is reached on localhost via `PiecesService` with dynamic port discovery (typically `39300`, fallback `1000`; caches port and can read `OS#port` from Pieces logs); application ID `app.piecestask`.
- Inbound flow: `POST /materials/identifiers` (recent `WORKSTREAM_SUMMARIES`) → `GET /workstream_summary/{id}` → `GET /annotation/{id}` for `SUMMARY` text → `PiecesNextStepsParser` extracts `### **Next Steps**` bullets.
- Popover title: “What you're missing”. Empty state: “You're caught up”. Header: sparkles (Ollama summary), **Check again**, Settings — no Open Pieces OS launcher. List grouped by work session (`AttentionSection`); footer can show “Showing X of Y”.
- `MenuBarStatusIcon` loads custom **`MenuBarIcon`** asset (puzzle-piece branding) with status dot colors into an `NSImage`; SF Symbol fallback if asset missing.
- `PopoverGlassBackground` / `PopoverGlassStyle`: Liquid Glass on macOS 26+, vibrancy fallback on earlier macOS; `PopoverLayout` sizes the popover (~360× up to ~45% of screen height).
- Settings (`AppSettings` + `SettingsView` + **`SettingsDraft`**): fixed ~560×512 window via **`SettingsWindowPresenter`** with **popover-matching glass chrome**; tabs **General**, **Connections**, **Pieces**; draft/edit until Apply or Save (Cancel/× discard); launch at login, refresh-on-open, global shortcut toggle, lookback, list caps, hidden follow-up count + restore action, Ollama URL/model (local), Pieces + Ollama connectivity tests (test state lives in `SettingsView`, not `AppState`).
- Popover interactions: click row to copy; header **Copy all** visible follow-ups; right-click → hide (`dismissedFollowUpIDs`); `PopoverUndoBanner` after hide; `FollowUpSummaryPanel` brief AI line + expand shows follow-up titles only.
- Right-click menu bar: AppKit `MenuBarRightClickMenu` + `MenuBarStatusItemFinder` (SwiftUI `.contextMenu` does not work with `.window` style).
- Build with `xcodebuild -project PiecesTask.xcodeproj -target PiecesTask -configuration Debug build`; run `python3 generate_xcode.py` after adding new Swift files under `PiecesTask/`; **`PROJECT_CATCH_UP.md`** at repo root for pre-coding stack catch-up.
