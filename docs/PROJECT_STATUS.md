# Project Status

Last updated: 2026-07-12

## Current Product State

TokenScope is a working unsigned native macOS menu bar app.

The app currently:

- Scans local Claude Code logs under `~/.claude`.
- Scans local Codex CLI logs under `~/.codex`.
- Parses supported Claude JSONL and Codex rollout JSONL formats.
- Extracts supported Claude/Codex tool-call metadata for behavior-level waste analysis.
- Keeps parsing deterministic and tolerates malformed partial JSONL lines when usable records exist.
- Normalizes records into shared session models.
- Estimates cost using a local pricing catalog.
- Stores sessions and ingestion metadata in SQLite.
- Stores privacy-preserving tool event metadata in SQLite.
- Serializes SQLite wrapper access so background refresh and popover reads do not share one connection unsafely.
- Refreshes in the background on launch and every 60 seconds, and synchronously when the user clicks `Refresh Now`.
- Opens the popover from cached local summary state instead of forcing a log scan first.
- Skips unchanged source files using an ingestion index.
- Displays Total, Today, and 7-day ranges.
- Splits popover content into Overview, Providers, Activity, and System views.
- Uses a single clear empty-state row when the selected range has no local sessions.
- Groups popover breakdowns by provider.
- Keeps provider sections compact by showing top model/project rows first.
- Displays token phase analysis, waste signals, and session insights.
- Displays waste signals with short improvement suggestions.
- Displays actionable optimization tips for repeated reads, broad searches, directory listings, failed retry loops, and token-heavy sessions.
- Flags repeated reads of the same file within a session.
- Flags repeated broad searches over the same root within a session.
- Flags repeated directory listings over the same folder within a session.
- Flags repeated failed commands within a session when provider logs expose failure metadata.
- Resolves relative shell read paths against provider working directory when available.
- Lets users select a notable session to inspect cost, token breakdown, and safe source details.
- Collapses multiple provider records from the same provider session for display.
- Uses a plain white popover background with subtle colored row highlights for warning, success, info, and system rows.
- Wraps long popover details and keeps the right-side value column stable.
- Displays refresh, storage, and pricing diagnostics.
- Provides first-pass database maintenance controls for rebuild, clear, and open DB location.
- Documents manual pricing catalog updates and shows catalog version in diagnostics.
- Documents signing/notarization plan and changelog discipline.
- Packages as an unsigned DMG.

## Validation

Current test status:

- `swift test`: 97 tests passing

Current release artifact pattern:

- `dist/TokenScope-0.1.0-unsigned-*/TokenScope-0.1.0-unsigned.dmg`

## Current Data Store

Default SQLite path:

```text
~/Library/Application Support/TokenScope/TokenScope.sqlite3
```

## Current Pricing Model

Pricing is local and versioned.

Current catalog source version:

```text
PricingCatalog.sourceVersion = 2026-07-11
```

Pricing estimates are not billing-grade. Unknown models keep token counts and render cost as unknown.

## Important Product Constraints

- No telemetry.
- No cloud sync.
- No login.
- No OAuth.
- No API keys.
- No background network calls.
- Local logs must never leave the user's Mac.

## Known Limitations

- The app is unsigned.
- Pricing is a local snapshot and does not auto-update online.
- If SQLite cannot open, the app falls back to in-memory storage and shows this in diagnostics.
- Token analysis uses available token fields only; it is not semantic activity classification.
- Behavior-level waste analysis is first-pass and only covers supported tool-call shapes and conservative repeated-read detection.
- Session insights are heuristic and should be framed as signals, not proof.
- Parser support is limited to currently tested Claude and Codex log shapes, including current sanitized edge fixtures.
- Session drill-down is first-pass only; more real-world dense-history UI stress testing is still useful.
- Database maintenance controls are first-pass only; more dense-layout stress testing is still useful.

## Next Recommended Work

1. Add more real-world failed-command fixture shapes as they are observed.
2. Continue stress testing popover layout with long project/model/session names.
3. Decide Apple Developer signing/notarization details for public distribution.
