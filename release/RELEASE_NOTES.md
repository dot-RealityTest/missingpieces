# missingpieces 1.0.0 (build 3)

Lean menu bar app that shows next steps from recent Pieces OS workstream summaries.

Build 3 hardens local privacy: Pieces API reads use an ephemeral no-cache session, and locally marked-done rows store hashed IDs only.

## Install

Open `missingpieces-1.0.0-b3.dmg`, drag to Applications, launch from there.

## Requirements

- macOS 14+
- Pieces OS running locally

## Distribution note

This build is **Developer ID signed, notarized, and stapled**.
Gatekeeper accepts the DMG and app as `Notarized Developer ID`.

## Rebuild

```bash
./scripts/release.sh
```
