# Scripts

## Unsigned DMG

Build a local unsigned release app and DMG:

```sh
scripts/package_unsigned_dmg.sh
```

Artifacts are written under `dist/TokenScope-0.1.0-unsigned-*`.

This does not sign or notarize the app. macOS Gatekeeper may warn when opening
the app on another machine.
