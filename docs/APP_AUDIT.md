# Full App Audit

> **Note:** This is a point-in-time audit snapshot, not live project status. See `docs/PROJECT_STATUS.md` for current status.

Audit date: 2026-07-11

## Summary

TokenScope is a working local-first macOS menu bar app with parser, ingestion, SQLite persistence, incremental refresh, estimated pricing, popover analytics, and unsigned DMG packaging.

Audit result:

- App architecture is coherent.
- Local-first privacy constraints are preserved.
- Tests are passing.
- Two production-risk issues were found and fixed during audit.

Current validation:

```text
swift test: 97 tests passing
```

## Audit Scope

Reviewed areas:

- App launch
- Storage initialization
- SQLite schema migration behavior
- Local scanner
- Ingestion and incremental source-file index
- Claude parser
- Codex parser
- Normalization
- Tool event extraction and repeated-read analysis
- Pricing estimation
- Menu bar summary
- Popover summary and analytics
- Session display deduplication
- Privacy/network constraints
- Test coverage
- Release packaging flow

## Findings Fixed During Audit

### Fixed: Legacy SQLite Cache Columns

Severity: High

Problem:

An earlier app build could create a SQLite database with schema migration version 1 applied before `cache_creation_input_tokens` and `cache_read_input_tokens` existed. Later builds selected and upserted those columns. Existing users with that older database could hit SQLite errors.

Fix:

- Added compatibility repair in `SQLiteSpendStorage.prepare()`.
- Missing `sessions.cache_creation_input_tokens` and `sessions.cache_read_input_tokens` are added if absent.
- Added a regression test that creates a legacy database and verifies the repaired storage can upsert and read cache-token sessions.

### Fixed: Launch Crash On SQLite Open Failure

Severity: High

Problem:

`AppDelegate` used `try!` when opening SQLite storage. Permission issues or local database problems could crash the app at launch.

Fix:

- Replaced crash behavior with a safe storage factory.
- App now falls back to in-memory storage if SQLite initialization fails.

Follow-up status:

- Storage fallback state is now surfaced in UI diagnostics.

## Current Architecture Assessment

### App Runtime

Current runtime is simple and effective:

```text
AppDelegate
  -> SQLiteSpendStorage or InMemory fallback
  -> UsageRefreshCoordinator
  -> LocalUsageIngestionService
  -> MenuBarController / PopoverViewController
```

Strengths:

- Refresh triggers are centralized.
- UI does not parse raw provider logs.
- Storage implementation is isolated.

Risks:

- Runtime diagnostics are intentionally lightweight; deeper parser/source health still needs a maintenance view.

### Parser Layer

Strengths:

- Claude and Codex parsers are separated.
- Parser behavior is fixture tested.
- Edge fixtures cover missing model/project fields, cache tokens, and malformed partial JSONL.
- Malformed files are skipped by ingestion.
- Cache token fields are extracted where available.
- Supported tool-use/tool-call metadata is extracted without storing prompt text or tool output.

Risks:

- Provider log formats may drift.
- Real-world parser coverage is still limited to observed/tested shapes.
- Tool event extraction is limited to tested Claude/Codex shapes.

Required discipline:

- Add sanitized fixtures for every new log shape.
- Keep parser failures non-fatal.

### Normalization And Pricing

Strengths:

- Pricing is separated from parser logic.
- Unknown model pricing returns nil cost without losing token counts.
- Codex cached input is handled without double-counting standard input cost.
- Manual pricing update process is documented.
- Catalog source version is visible in UI diagnostics.

Risks:

- Pricing is a local snapshot.
- Some model aliases may be missing.
- Costs are estimates, not billing-grade.

Required discipline:

- Keep `PricingCatalog.sourceVersion` current.
- Add tests for every model alias.
- Do not add automatic online pricing updates without an explicit privacy decision.

### Storage

Strengths:

- SQLite persistence is implemented.
- Migrations exist.
- Source-file ingestion index avoids repeated parsing.
- Legacy cache column compatibility is now repaired.
- Tool event metadata is stored in a dedicated `tool_events` table.

Risks:

- Ingestion session upsert and source-file index updates are not one shared storage transaction.
- Database maintenance UI is first-pass and still needs real-world dense-layout stress testing.

### UI

Strengths:

- Popover supports Total, Today, and 7-day views.
- Popover separates Overview, Providers, Activity, and System content to reduce dense scroll length.
- Empty ranges render as one actionable empty-state row instead of several empty sections.
- Provider sections improve classification.
- Token analysis and waste signals add product value.
- First-pass interactive session detail is available for notable rows.
- Session detail includes safe source metadata without raw private paths.
- Display sessions are collapsed to avoid repeated provider records.
- First-pass database maintenance controls and structured action status are available.
- Popover no longer forces a log scan before opening.
- Popover uses a plain white background with subtle colored row highlights for warning, success, info, and system rows.
- Detail text wraps to two lines and values stay in a fixed right column.
- Session insight and provider rows are compacted to reduce dense text blocks.
- Waste signal rows now include short `Fix:` suggestions so findings are paired with improvement direction.

Risks:

- Popover can still become dense with very large histories.
- Menu bar summary uses a simpler summary path than popover.
- Session detail still needs more real-world UI stress testing.
- Maintenance controls still need more dense-layout stress testing.
- Very long project/model names may still need UI stress testing.

### Privacy

Verified constraints:

- No telemetry.
- No cloud sync.
- No OAuth.
- No login.
- No API keys.
- No external network calls in app code.

## Functional Status

Implemented:

- Native macOS menu bar app
- Claude local scanner/parser
- Codex local scanner/parser
- Normalized session model
- Local pricing estimates
- SQLite persistence
- Serialized SQLite wrapper access for background refresh and UI reads
- Incremental ingestion index
- Background refresh on launch/timer/manual action
- Cached popover opening without forced scan
- Popover time ranges
- Provider/model/project breakdowns
- Timeline
- Expensive sessions
- Token analysis
- Waste signals
- Repeated file read signal
- Session-level repeated-read detail rows
- Repeated broad-search signal
- Session-level repeated-search detail rows
- Repeated directory-listing signal
- Session-level repeated-directory-listing detail rows
- Repeated failed-command signal
- Session-level repeated-failed-command detail rows
- Actionable optimization tips for repeated tool behavior and token-heavy sessions
- Waste signals with short improvement suggestions
- Session insights
- First-pass interactive session detail
- Safe session source metadata
- Display-session deduplication
- First-pass database maintenance controls
- Unsigned DMG packaging

Not implemented:

- Signed/notarized release
- Manual pricing catalog update UI
- More provider support
- Semantic activity classification
- More provider-specific failed-command result fixtures

## Recommended Next Tasks

1. Continue stress testing dense popover layout:
   - Long project, model, and session names.
   - Maintenance controls near long diagnostic rows.

2. Finish session detail:
   - Stress test long names and dense histories.

3. Parser robustness:
   - Document supported log formats.
   - Add more sanitized fixtures as new shapes are observed.

4. Release hardening:
   - Signing/notarization plan.
   - Version and changelog process.

## Acceptance Gate For Next Release

Before the next installable build:

- `swift test` passes.
- DMG builds and verifies.
- App launches with existing old SQLite DB.
- App does not crash when SQLite cannot open.
- Refresh diagnostics are visible.
- Privacy constraints remain unchanged.
