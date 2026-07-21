# Signing And Notarization Plan

Last updated: 2026-07-11

TokenScope currently ships as an unsigned local test DMG.

This document describes the path to a signed and notarized macOS release.

## Current State

- App bundle is produced by `scripts/package_unsigned_dmg.sh`.
- DMG is unsigned.
- App is not notarized.
- Builds are suitable for local testing only.

## Required Decisions

Before signed distribution, decide:

- Apple Developer account and Team ID.
- Bundle identifier ownership for `com.tokenscope.app`.
- Whether releases are distributed only by GitHub Releases or also through a website.
- Whether hardened runtime entitlements are needed beyond the default app sandbox-free local log reader behavior.

## Target Release Flow

1. Run `swift test`.
2. Build release app bundle.
3. Code sign the `.app` bundle with Developer ID Application.
4. Verify code signature.
5. Package signed app into DMG.
6. Code sign the DMG with Developer ID Application.
7. Submit DMG to Apple notarization.
8. Staple notarization ticket.
9. Verify stapled DMG.
10. Attach DMG to release notes with privacy and pricing caveats.

## Expected Commands

These are planning commands only. They are not wired into scripts yet.

```bash
codesign --force --options runtime --timestamp --sign "Developer ID Application: <Name> (<TEAMID>)" TokenScope.app
codesign --verify --deep --strict --verbose=2 TokenScope.app
hdiutil create ...
codesign --force --timestamp --sign "Developer ID Application: <Name> (<TEAMID>)" TokenScope.dmg
xcrun notarytool submit TokenScope.dmg --keychain-profile "<profile>" --wait
xcrun stapler staple TokenScope.dmg
spctl --assess --type open --context context:primary-signature --verbose TokenScope.dmg
```

## Notarization Prerequisites

- Apple Developer Program membership.
- Developer ID Application certificate installed in Keychain or CI secrets.
- `notarytool` keychain profile or App Store Connect API key.
- Release machine or CI runner with Xcode command line tools.

## Privacy Constraints

Signing and notarization must not change app privacy behavior.

The app must remain:

- no telemetry
- no login
- no OAuth
- no API keys
- no provider network calls
- no background pricing network calls

## Release Artifact Naming

Unsigned local test build:

```text
TokenScope-<version>-unsigned.dmg
```

Signed release build:

```text
TokenScope-<version>.dmg
```

## Open Work

- Add `scripts/package_signed_dmg.sh` after Developer ID details are available.
- Add CI or local release script for notarization.
- Add changelog generation discipline before public releases.
