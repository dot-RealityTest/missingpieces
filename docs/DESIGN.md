# missingpieces — Design

How the lean menu bar UI should look and behave. Written for humans and agents resuming UI work.

> Shipped app name: **missingpieces** (repo folder: `PiecesTask/`).

## Design goals

1. **Glanceable** — see what you might have missed in a few seconds.
2. **Calm** — grey body text; color only on section accents and status, not on every title.
3. **Compact** — popover and Settings fit without scrolling when possible.
4. **Premium glass** — native macOS feel; Liquid Glass on Tahoe, safe fallbacks older macOS.
5. **Purposeful motion** — short springs for expand/copy; full respect for **Reduce Motion**.

---

## Surfaces

### Menu bar icon

- Asset: **`MenuBarIcon`** (puzzle piece), not SF Symbol alone.
- **Status dot** overlaid on the glyph (see features doc for colors).
- Shared rendering: `MenuBarStatusIcon` (bitmap for status item) and `AppStatusGlyphView` (popover header).

### Popover

| Token / component | Role |
|-------------------|------|
| `PopoverLayout` | ~360pt wide, height up to ~45% of screen |
| `PopoverGlassBackground` / `PopoverSurfaceModifier` | Glass chrome; macOS 26+ Liquid Glass path, else vibrancy |
| `PopoverGlassStyle` | Corner radius 12, list panels 8, light borders/shadows |
| `PopoverWindowConfigurator` | Clear non-opaque window, floating panel |

**Header toolbar**

- Plain **borderless** icon buttons (`popoverToolbarButtonStyle`) — not heavy glass pills.
- **Check again** (`RefreshPiecesButton`) — pulse on load when motion allowed.
- **Settings** — opens fixed-size settings window.
- **No** “Open Pieces OS” button — connection context via status dot + Settings subtitle.

**List**

- Title: **“What you're missing”**
- Sections: work session name + **pastel accent** `arrow.turn.down.right` (not plain `chevron.right`).
- Rows: **calm grey** title (`displayTitle`), optional one-line subtitle (`displaySubtitle`).
- Expanded body: full step text **without** duplicating the title (`displayExpandedContent`).
- Inset list panels: `popoverListPanel()` fill at ~4.5% primary opacity.

### Settings

- Window: **~480×400** via `SettingsWindowPresenter`.
- Background: **`settingsWindowBackground()`** — sidebar-style vibrancy only.
- **Do not** stack popover glass/container APIs on the Settings window (caused freezes).
- Sections: `SettingsGlassSection` with `SettingsToggleRow`, `SettingsPickerRow`, `SettingsActionRow`.
- Typography: `SettingsTheme` — label ~52% primary, secondary ~38%, values ~62%.
- **Auto-save** — toggles and pickers write through `AppSettings` immediately.

---

## Color & accent system

### Section accents (`SectionAccentPalette`)

Pastels rotate by section index (headers + row arrow icons only):

| Index mod 3 | RGB (approx) | Use |
|-------------|--------------|-----|
| 0 | 0.50, 0.64, 0.88 | Blue-lavender |
| 1 | 0.64, 0.56, 0.86 | Violet |
| 2 | 0.46, 0.74, 0.74 | Teal |

Row **titles stay grey** — accents do not flood the whole row.

### Status colors (menu bar dot)

- Green — connected
- Blue — has follow-ups
- Gray — offline
- Orange — problem items in list

### Chrome neutrals

- Section dividers: primary @ 10% opacity
- Glass border: ~38% opacity
- Shadow: radius 22, y offset 10

---

## Motion (`PopoverMotion`)

| Animation | Duration / style | Use |
|-----------|------------------|-----|
| `feedback` | snappy 0.26s | Copy flash, mark done |
| `expand` | smooth 0.28s | Row expand/collapse |
| `gentle` | smooth 0.30s | List phase changes |
| `quick` | smooth 0.18s | Toolbar loading icon |
| `spring` | snappy 0.34s | Heavier transitions |

**Reduce Motion:** `PopoverMotion.perform` and `animation(reduceMotion:)` skip `withAnimation`; `revealTransition` degrades to opacity-only.

**Row expand:** first row and later rows use the same expand/collapse behavior (no special-case “first row” motion).

---

## Interaction patterns

```
Click row      → toggle expanded detail
Double-click   → copy to pasteboard (+ brief feedback animation)
Right-click    → Mark done | Copy
```

Marked done removes row from active list; restore via Settings.

---

## Typography

- Popover header title: system, semibold hierarchy via existing `RootPopoverView` styles.
- Row title: ~12.5pt calm grey.
- Row subtitle: smaller, lower contrast when present.
- Settings rows: 12.5pt labels per `SettingsTheme`.

Prefer **Dynamic Type**-friendly stacks where already wired; avoid fixed heights that clip large content sizes on rows.

---

## Accessibility

- Respect **`accessibilityReduceMotion`** in `RefreshPiecesButton`, `MissingRowView`, and `PopoverMotion`.
- Toolbar buttons need `.help()` strings (“Check again”, Settings).
- Status should not rely on color alone — connection errors surface as readable row text.

---

## Anti-patterns (do not reintroduce without explicit ask)

- Heavy glass pills in popover toolbar
- Popover glass on Settings window
- Plain grey chevrons instead of accented arrows on sections
- Bright saturated row titles
- Ellipsis truncation on AI summary (feature removed on `main`)
- Open Pieces OS launcher in popover header

---

## Assets

- `PiecesTaskAssets.xcassets` — `AppIcon`, `MenuBarIcon` (@1x/@2x)

---

## Related

- [FEATURES_AND_PIPELINE.md](./FEATURES_AND_PIPELINE.md)
- [../AGENTS.md](../AGENTS.md)
