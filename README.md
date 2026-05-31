# missingpieces

missingpieces is a small macOS menu bar app for people who use [Pieces OS](https://pieces.app/).
It shows the next steps Pieces already noticed in recent workstream summaries.

The app is intentionally quiet:

- Read-only toward Pieces OS
- No local task database
- No background polling
- Local-only mark done / restore
- Compact menu bar UI for quick triage

[Download the latest DMG](https://github.com/dot-RealityTest/missingpieces/releases/latest/download/missingpieces-1.0.0-b2.dmg)

## What It Does

missingpieces asks Pieces OS for recent workstream summaries, looks for the `Next Steps` section, and turns those bullets into a short list grouped by work session.

You can:

- Open the menu bar popover to scan follow-ups
- Click a row to expand it
- Double-click to copy it
- Right-click to mark it done locally
- Restore marked-done items in Settings

Nothing is written back to Pieces.

## Requirements

- macOS 14 or later
- Pieces OS running locally
- A Mac with access to `localhost`

## Install

1. Download [missingpieces-1.0.0-b2.dmg](https://github.com/dot-RealityTest/missingpieces/releases/latest/download/missingpieces-1.0.0-b2.dmg).
2. Open the DMG.
3. Drag `missingpieces.app` to Applications.
4. Open `missingpieces` from Applications.
5. Keep Pieces OS running.

The release is Developer ID signed, notarized, and stapled.

## Privacy

missingpieces talks to Pieces OS on your Mac, usually on port `39300` with a fallback to `1000`.
Marked-done items are stored locally in `UserDefaults`.

The app does not:

- Upload data to a separate server
- Create tasks in Pieces
- Change or delete Pieces data
- Poll in the background

## Build From Source

```bash
python3 generate_xcode.py
xcodebuild -project PiecesTask.xcodeproj -target missingpieces -configuration Debug build
open build/Debug/missingpieces.app
```

For a signed release build:

```bash
./scripts/release.sh
```

Release signing needs a Developer ID certificate for team `P5RB3W3D58`.
Notarization credentials are not stored in this repo.

## Project Layout

| Path | Purpose |
|------|---------|
| `PiecesTask/` | Swift source |
| `PiecesTask.xcodeproj/` | Generated Xcode project |
| `PiecesTaskAssets.xcassets/` | App and menu bar icons |
| `landing/` | GitHub Pages landing page |
| `release/` | Install notes and release notes |
| `docs/` | Product, design, and pipeline notes |
| `scripts/release.sh` | Developer ID release build script |
| `generate_xcode.py` | Regenerates the Xcode project after adding Swift files |

## Release

Current release:

- Version: `1.0.0`
- Build: `2`
- Bundle ID: `app.missingpieces`
- Artifact: `missingpieces-1.0.0-b2.dmg`
- Notarization: accepted and stapled

See [release notes](release/RELEASE_NOTES.md).

## Site

The landing page lives in [landing/](landing/) and deploys through GitHub Pages.

## License

Source available. All rights reserved unless a separate license is added.

## Credits

missingpieces is an independent companion app for Pieces OS.
Pieces and Pieces OS belong to their respective owners.
