# missingpieces — worth your time?

> **Historical snapshot** — app renamed to **missingpieces**; lean `main` superseded much of this doc.

> **Out of date (May 2026).** Verdict below describes an older task-app direction. Current app: read-only Pieces next-steps on `main`. See **`AGENTS.md`**.

> **Quick verdict** — read the box and "What I'd do", then stop if you have your answer.
> **The rest** — why, your context, alternatives, and honesty checks.

---

## Quick verdict

**Primary:** Cherry-pick

**In one sentence:** Keep this folder as a tight native Mac + Pieces experiment—finish one integration slice if the hook excites you, but do not treat it as your daily task app until sync and capture are real.

## What I'd do

- Run the app once (`PROJECT_GUIDE.md` steps) and decide if the menu bar UX feels good enough to keep polishing.
- If you continue: wire **one** path end-to-end—when you add or complete a task and Pieces is connected, call `PiecesService.saveTask` / `updateTaskStatus` (about 20–40 lines in `AppState` or `AddTaskView`).
- If you only need a to-do list today: use **Apple Reminders** or **Things 3** and park this repo; copy the `MenuBarExtra` + SwiftData pattern into a future app instead.
- Do **not** expand scope (subtasks, quick wins, AI scoring) until the Pieces bridge actually runs on add/complete.
- Rename or document the project in a one-line note in your task system: *“Pieces → menu bar tasks; build OK May 12; integration half-done.”*

---

## The rest (optional)

### Why (matched to you)

You build **native macOS utilities** on purpose (V8V method, Apple-quality UI, local-first tools). PiecesTask fits that lane and your **Pieces OS** workflow better than another web dashboard. The code is small (~9 Swift files), already **compiles and launches**, and teaches menu bar + SwiftData + localhost API in one place.

The tension: your recent work shows **several task-app directions at once**—“ultimate task app,” **Ideory / DoIsConnected**, **Lapapi** as a Mac app, and **PiecesTask**. Pieces memory from May 12 shows a successful build, then attention shifted to V8V launch, Lapapi, blogs, and other shipping work. That pattern suggests excitement without a single “daily driver” finish line.

**Cherry-pick** means: steal the architecture and one feature, or spend a focused session to close the Pieces loop—not carry the whole vision until you drop another WIP.

### About you (from your recent work)

You operate as a solo builder (V8V, Shopify/Gumroad, native Mac experiments) with **Cursor**, **Codex**, **Xcode**, and **Pieces** as core tools. You care about visual polish and “AI-ready” project folders (`AGENTS.md`, skills, decisions). **PiecesTask** last had meaningful edits around **May 12, 2026** (Xcode build, launch, `PiecesService` work); since then your focus has been Lapapi, KIKA/V8V content, and other apps—not this repo daily.

You also explored removing Pieces from some apps for simplicity (e.g. AppAudit)—so this project only pays off if the **Pieces ↔ tasks** link is the reason it exists, not generic todos.

### Build vs use something that already exists

| Option | Best for | Tradeoff |
|--------|----------|----------|
| Keep building PiecesTask | Learning, portfolio, **tasks born from Pieces workstream** | You maintain it; many settings are still placeholders |
| [Apple Reminders](https://support.apple.com/guide/reminders/welcome/mac) | Free, Siri/Watch, Smart Lists, improving AI on Apple platforms | No Pieces workstream; not a menu bar-first UX |
| [Things 3](https://culturedcode.com/things/) | Beautiful GTD-style Mac/iOS tasks, one-time purchase | Paid; no Pieces integration |
| [Raycast](https://www.raycast.com/) + extensions | Fast capture from keyboard, extensions ecosystem | Not your custom Pieces pipeline |
| Your **Pieces MCP in Cursor** | Asking memory, annotations, workstream in the IDE | Solves “what should I do?” in chat, not a menu bar todo UI |

**Learn:** **Workstream** here means Pieces’ log of what you copied, typed, or viewed—PiecesTask tries to turn snippets of that into suggested task titles.

Your idea is still worth it for **learning and a niche twist** (menu bar + local DB + Pieces). If you only need reliable tasks, Reminders or Things already win on polish and sync.

### Honesty check

- **Excitement:** The “ultimate task app” and Pieces-brain theme still show up in your chats—there is real interest.
- **Reality:** Core UI works; **Pieces save on add/complete** and **auto-capture** are not finished; settings overpromise (launch at login, global shortcut).
- **Opportunity cost:** Every hour here is an hour not on Lapapi Mac, V8V sales density, or finishing one shipped utility you use daily.

### If you cherry-pick or park

- **Save this idea as:** *Menu bar task list with SwiftData; optional sync to Pieces OS annotations and suggestions from workstream clipboard/OCR.*
- **Worth stealing:** `PiecesTaskApp.swift` (`MenuBarExtra` + `.window` style), `AppState` filter pattern, `PiecesService` localhost health check, `generate_xcode.py` if you scaffold similar apps without hand-editing Xcode XML.

### If you go deep

- **First milestone (small):** Add task → if Pieces connected, `saveTask` succeeds; complete task → `updateTaskStatus` runs; status visible in Settings.
- **Stop if:** You are still not using it daily after that milestone, or you reach for Reminders/Things every time instead.
