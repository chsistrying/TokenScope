# Release Checklist

## Before Release

- Tests pass
- App launches cleanly
- No telemetry
- No network calls
- No OAuth
- No API keys
- Local fixtures are sanitized
- README is updated
- Project status docs are updated
- Known limitations are updated
- Changelog is updated
- Pricing catalog source version is reviewed
- Supported provider formats are reviewed

## Build

- Build release app
- Package DMG
- Verify DMG checksum with `hdiutil verify`
- For public distribution, sign and notarize using `docs/SIGNING_NOTARIZATION.md`
- Verify DMG install manually
- Launch app from Applications
- Confirm menu bar appears
- Confirm no setup is required
- Confirm popover opens promptly and manual `Refresh Now` works
- Confirm SQLite persistence works across relaunch
- Confirm no duplicate display sessions for multi-turn provider sessions

## GitHub Release

Include:

- Version
- DMG asset
- Summary
- Known limitations
- Privacy note
- Pricing catalog source version
- Supported provider format changes
- Signing/notarization status
