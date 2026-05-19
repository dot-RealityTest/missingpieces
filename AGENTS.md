## Learned User Preferences

- Prefer plain, everyday language in project docs and explanations (short sentences, minimal jargon; audience is self-taught, not CS-trained).
- Pieces integration is the top priority when resuming work on this repo.
- Product model is **Pieces-only and read-only**: the app shows “next steps” from recent Pieces workstream summaries; it does not maintain a local task list or push tasks to Pieces.
- Avoid aggressive automatic capture; refresh when the user opens the popover or taps Check again — not background polling.
- Care about a glanceable menu bar popover: cap visible rows, group next steps by work session, fit the screen, neutral follow-up styling (not long error-style lists), plus polished Settings and a clear refresh control in the header.
- When Pieces OS is already running, expect the agent to verify connectivity and launch or rebuild the app for smoke testing.

## Learned Workspace Facts

- PiecesTask is a macOS 14+ menu bar app (SwiftUI `MenuBarExtra`, `.window` style, `LSUIElement` — no Dock icon) using Swift 6 and `@Observable` `AppState`. No SwiftData.
- Pieces OS is reached on localhost via `PiecesService` with dynamic port discovery (typically `39300`, fallback `1000`; caches port and can read `OS#port` from Pieces logs); application ID `app.piecestask`.
- Inbound flow: `POST /materials/identifiers` (recent `WORKSTREAM_SUMMARIES`) → `GET /workstream_summary/{id}` → `GET /annotation/{id}` for `SUMMARY` text → `PiecesNextStepsParser` extracts `### **Next Steps**` bullets.
- Popover title: “What you're missing”. Empty state: “You're caught up”. Header/bottom **Check again** calls `AppState.refreshMissingFromPieces()`. List is grouped by work session (`AttentionSection` headers); footer can show “Showing X of Y” when capped by `AppSettings.visibleItemLimit`.
- Settings (`AppSettings` + `SettingsView`): launch at login (`SMAppService`), refresh-on-open toggle, lookback (3/7/14 days), visible list cap (5/8/12), steps per session (1–3), restore locally hidden follow-ups. Connections: Pieces + Ollama test/model.
- Popover interactions: click row to copy; right-click follow-up to hide locally (`dismissedFollowUpIDs` in UserDefaults); header sparkles runs Ollama `/api/generate` summary; `FollowUpSummaryPanel` shows result.
- Summary reminders: Settings → General → interval Off / 15 / 30 / 60 min; `SummaryNotificationService` refreshes Pieces and posts macOS notifications (Ollama summary if configured, else plain text). Requires notification permission.
- Quick win nudges: Settings → General → toggle on (~30 min); `QuickWinNotificationService` + `QuickWinPicker` pick a small follow-up and notify. On by default for new installs.
- Right-click menu bar: AppKit `MenuBarRightClickMenu` + `MenuBarStatusItemFinder` (SwiftUI `.contextMenu` does not work with `.window` style).
- Popover size is computed in `PopoverLayout` (~360× up to 45% of visible screen height, capped around 460pt).
- Build with `xcodebuild -project PiecesTask.xcodeproj -target PiecesTask -configuration Debug build`; run `python3 generate_xcode.py` after adding new Swift files under `PiecesTask/`.
