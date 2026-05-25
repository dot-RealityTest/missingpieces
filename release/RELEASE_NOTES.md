# PiecesTask 1.0.0 (build 1)

Lean menu bar app that shows next steps from recent Pieces OS workstream summaries.

## Install

Open `PiecesTask-1.0.0-b1.dmg`, drag to Applications, launch from there.

## Requirements

- macOS 14+
- Pieces OS running locally

## Distribution note

This build is **Developer ID signed** but **not notarized** (no notarytool profile on this machine).
On first open, use right-click → Open if Gatekeeper blocks it.

To notarize later:

```bash
xcrun notarytool store-credentials AC_PASSWORD --apple-id YOUR_APPLE_ID --team-id P5RB3W3D58
xcrun notarytool submit release/PiecesTask-1.0.0-b1.dmg --keychain-profile AC_PASSWORD --wait
xcrun stapler staple release/PiecesTask-1.0.0-b1.dmg
```

## Rebuild

```bash
./scripts/release.sh
```
