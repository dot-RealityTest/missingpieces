# PiecesTask — plain guide

> **Out of date (May 2026).** The app on `main` is a read-only Pieces next-steps list — no Ollama, no local task list. See **`AGENTS.md`** for the current product.

> **Quick start** — read through “How you run it”, then stop if that is enough.
> **The rest** — optional depth when you want the full picture.

---

## In one minute

**PiecesTask** is a small Mac **menu bar** app (top-right icons). It shows **“What you're missing”**: follow-up items pulled from **Next Steps** sections in your recent **Pieces OS** workstream summaries.

- **Read-only** — it does not add tasks to Pieces or change anything in Pieces.
- **Local only** — hiding a row only affects this app. **Ollama** (optional) runs on your Mac for a short AI summary.
- **No Dock icon** — it lives in the menu bar. Green dot on the icon = Pieces OS is connected.

## How you run it

1. Open **Terminal** and go to the project folder:
   ```bash
   cd /Users/kika_hub/Projects/PiecesTask
   ```
2. Build:
   ```bash
   xcodebuild -project PiecesTask.xcodeproj -target PiecesTask -configuration Debug build
   ```
3. Launch:
   ```bash
   open build/Debug/PiecesTask.app
   ```
4. Click the **menu bar icon** (checkmark or blue list icon) to open the panel.
5. **Pieces OS** should be running on this Mac. Settings → **Connections** → **Test Pieces connection**.
6. After adding new Swift files under `PiecesTask/`, run:
   ```bash
   python3 generate_xcode.py
   ```

**Alternative:** Open `PiecesTask.xcodeproj` in **Xcode** and press **Run** (⌘R).

---

## What you can do in the app

| Action | How |
|--------|-----|
| Refresh from Pieces | Open the list (if enabled in Settings) or tap **Check again** |
| Copy a follow-up | Click a row |
| Hide a follow-up | Right-click a row → **Hide** (Pieces unchanged) |
| Show hidden again | Settings → **General** → **Show hidden follow-ups again** |
| Open Pieces OS | Header button (arrow icon) when connected |
| AI summary | Header **sparkles** button (needs Ollama model in Settings) |
| Settings | Gear in header, **⌘,**, or right-click menu bar icon |

---

## Settings (three tabs)

- **General** — launch at login, refresh when opening the list, restore hidden follow-ups.
- **Connections** — test **Pieces OS** and **Ollama**; set Ollama URL and model.
- **Pieces** — how far back to read (3 / 7 / 14 days), how many rows to show, steps per work session, manual refresh.

---

## How it is organized

| Folder / file | What it is for |
|---------------|----------------|
| `PiecesTask/PiecesTaskApp.swift` | Menu bar app entry, window size |
| `PiecesTask/Services/AppState.swift` | List state, refresh, hide, Ollama summary |
| `PiecesTask/Services/PiecesService.swift` | HTTP client to Pieces OS (localhost) |
| `PiecesTask/Services/OllamaService.swift` | Ollama tags + generate API |
| `PiecesTask/Services/AppSettings.swift` | UserDefaults preferences + hidden IDs |
| `PiecesTask/Views/RootPopoverView.swift` | Main panel UI |
| `PiecesTask/Views/SettingsView.swift` | Settings window |
| `PiecesTask/Components/` | Rows, menu bar icon, summary panel, layout helpers |
| `generate_xcode.py` | Regenerates the Xcode project when you add `.swift` files |
| `build/` | Compiled app (safe to delete; rebuild recreates it) |

---

## Pieces data flow (simple)

1. Health check on localhost (port **39300** or **1000**, discovered automatically).
2. List recent **workstream summary** IDs.
3. For each summary, read **SUMMARY** annotations.
4. Parse the **Next Steps** section into bullet lines.
5. Show up to your chosen cap, grouped by work session name.

---

## Technologies

- macOS 14+, Swift 6, SwiftUI, `@Observable`
- **URLSession** to Pieces OS and Ollama on localhost
- **UserDefaults** for settings and locally hidden follow-up IDs
- No SwiftData, no cloud sync

---

## Things that might confuse you

1. **Hiding is not deleting in Pieces** — it only skips that row in PiecesTask until you restore or the ID changes.
2. **“Showing 8 of 10”** — the list cap in Settings; the rest are still in Pieces.
3. **Ollama summary** — needs Ollama running, a model installed (`ollama pull …`), and a model picked in Settings. First run can take a minute.
4. **`build/` is large** — normal after `xcodebuild`; not source code.
5. **Regenerate Xcode** after new files: `python3 generate_xcode.py`.

---

## If you change code

1. Edit Swift files under `PiecesTask/`.
2. If you added a file: `python3 generate_xcode.py`.
3. Build and run (commands above).
4. Quit the old app from the menu bar (**Close App** in right-click menu) if the icon still looks old.
