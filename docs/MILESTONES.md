# Milestones

Use this file to drive Codex work one milestone at a time.

## Status Summary

The original M0-M10 MVP milestones are implemented.

The project is now in post-MVP hardening and product-quality iteration.

Current validation:

```text
swift test: 97 tests passing
```

## M0 - Project Skeleton

Status: Completed

- Create native macOS app structure
- Add parser module folders
- Add placeholder normalized model files
- Add storage folder
- Add placeholder menu bar UI
- Add test folders
- Add fixture folders

Do not implement real parsing yet.

## M1 - Shared Data Model

Status: Completed

- Define normalized session model
- Define provider enum/type
- Define usage event model
- Define project model
- Add tests for basic model behavior if applicable

## M2 - Parser Interfaces

Status: Completed

- Define provider parser protocol/interface
- Define raw parser result type
- Define parser error type
- Add no-op Claude and Codex parser implementations

## M3 - SQLite Storage Interface

Status: Completed

- Define storage protocol/interface
- Define schema migration location
- Add placeholder implementation or stubs
- Do not build UI-specific queries yet

## M4 - Claude Fixture Parser

Status: Completed

- Add sanitized Claude fixtures
- Parse fixture files
- Extract provider, model, session, token fields where available
- Normalize records
- Add tests

## M5 - Codex Fixture Parser

Status: Completed

- Add sanitized Codex fixtures
- Parse fixture files
- Extract provider, model, session, token fields where available
- Normalize records
- Add tests

## M6 - Local Scanner

Status: Completed

- Scan `~/.claude`
- Scan `~/.codex`
- Ignore unreadable files safely
- Avoid duplicate ingestion
- Add tests where possible

## M7 - Menu Bar UI

Status: Completed

- Show configurable menu bar summary
- Default to cost
- Refresh from storage
- Keep UI lightweight

## M8 - Popover

Status: Completed

- Today summary
- Provider breakdown
- Model breakdown
- Project breakdown
- Most expensive sessions

## M9 - Timeline

Status: Completed

- Chronological session timeline
- Provider, model, project, cost, tokens

## M10 - Packaging

Status: Completed

- Build release app
- Create DMG
- Prepare GitHub release notes

## M11 - Refresh Pipeline

Status: Completed

- Refresh on app launch
- Refresh every 60 seconds
- Automatic launch/timer refresh runs on a background serial queue
- Popover opens from cached local summary state without forcing a log scan first
- Manual `Refresh Now`
- Show last updated time

## M12 - SQLite Persistence

Status: Completed

- Store normalized sessions in SQLite
- Store usage events in SQLite
- Persist across app restarts
- Use schema migrations

## M13 - Incremental Ingestion Index

Status: Completed

- Store source file metadata
- Store source file content hash
- Skip unchanged files
- Skip parsing when content hash is unchanged

## M14 - Token Analysis And Waste Signals

Status: Completed

- Token phase analysis
- Waste signals
- Session insights
- Display-session collapse to avoid duplicate rows
- Behavior-level repeated-read signal from tool events

## M15 - UI Polish And Diagnostics

Status: In Progress

- Show refresh diagnostics
- Show pricing catalog version
- Show database path
- Show storage mode and in-memory fallback state
- Improve popover density
- Add collapsible sections or drill-down affordances

Completed:

- Refresh, storage, database path, pricing catalog, and fallback diagnostics
- Wider popover layout with wrapped detail text and stable value column
- Overview, Providers, Activity, and System popover content tabs
- Single-row empty state for ranges with no local sessions
- Compact session insight rows that keep long recommendations in the selected detail view
- Compact provider sections that show the top model/project rows first
- Plain white popover background with subtle colored row highlights for warning, success, info, and system content

Remaining:

- Consider collapsible sections if dense real-world histories still feel crowded

## M16 - Interactive Session Detail

Status: In Progress

- Open one session insight or expensive session
- Show detailed token and cost breakdown
- Show recommendations and source metadata
- Avoid exposing raw private paths by default

Completed:

- Clickable session rows in insights, expensive sessions, and timeline
- Selected session detail section
- Provider, model, project, time, cost, input, cache write, cache read, output, and total tokens
- Recommendation shown with the selected session
- Safe source description without raw private paths
- Presenter regression coverage that raw private paths are not rendered

Remaining:

- Continue real-world UI stress testing for long names and dense history

## M17 - Database Maintenance

Status: In Progress

- Rebuild database
- Clear local data
- Open database location
- Migration safety tests

Completed:

- Storage maintenance protocol
- SQLite local data clear operation covering sessions, events, providers, models, projects, and source-file ingestion index
- Popover controls for `Rebuild Database`, `Clear Data`, and `Open DB`
- Confirmation prompts before clear/rebuild
- Structured maintenance results for refresh/rebuild/clear/open DB actions
- SQLite regression test proving clear keeps schema usable
- Presenter regression coverage for maintenance status rows

Remaining:

- Continue real-world UI stress testing for maintenance controls in dense popover content

## M18 - Parser Robustness

Status: In Progress

- Add sanitized Claude fixtures for more transcript variants
- Add sanitized Codex fixtures for more rollout variants
- Cover missing model, missing cwd/project, missing cache fields, and malformed partial logs
- Keep parser failures deterministic

Completed:

- Claude edge fixture with missing model, derived project name, cache tokens, and partial malformed JSONL
- Codex fixture edge case with missing model/project, cached input, and derived fixture total
- Codex rollout edge fixture with missing model, derived project name, cached input, and partial malformed JSONL
- Parser behavior now tolerates malformed JSONL lines when usable records exist
- Malformed-only inputs still fail deterministically
- Claude tool-use fixture support for `Read` and `Bash`
- Codex rollout tool-call fixture support for `Read` and `exec_command`

Remaining:

- Add more sanitized fixtures as new real-world shapes are observed

## M19 - Pricing Management

Status: In Progress

- Document manual pricing catalog update process
- Keep pricing changes explicit and test-covered
- Show local catalog version in UI diagnostics

Completed:

- `docs/PRICING_CATALOG.md`
- ADR cross-link for manual pricing updates
- Catalog source version date-format test
- UI diagnostics already show `PricingCatalog.sourceVersion`

Remaining:

- Add tests for new model aliases whenever pricing assumptions change

## M20 - Release Hardening

Status: In Progress

- Plan signing and notarization
- Update release checklist
- Add version and changelog discipline

Completed:

- `docs/SIGNING_NOTARIZATION.md`
- `CHANGELOG.md`
- Release checklist references signing/notarization, changelog, pricing source version, and supported formats

Remaining:

- Decide Apple Developer account, Team ID, and release distribution channel
- Add signed DMG packaging script after Developer ID details are available

## M21 - Behavior-Level Waste Analysis

Status: In Progress

- Extract local tool calls from Claude and Codex logs
- Store privacy-preserving tool metadata in SQLite
- Detect repeated reads of the same file in the same session
- Show repeated-read waste signal in the popover
- Resolve relative shell read paths against provider working directory
- Show repeated-read session insight/detail rows
- Detect repeated broad searches over the same root
- Detect repeated directory listings over the same folder
- Detect repeated failed commands
- Document research basis and supported analysis inputs

Completed:

- `ToolEvent` model and SQLite `tool_events` migration
- `tool_event_working_directory` migration with reingestion trigger
- Claude `message.content[].tool_use` extraction
- Codex rollout `tool_call` and `exec_command` extraction
- Repeated file read signal at 3 or more reads per session/path/range
- Session-level repeated-read insight and detail rows
- Repeated `rg`, recursive `grep`, and `find` broad-search signal at 3 or more searches per session/root/range
- Session-level repeated-search insight and detail rows
- Repeated `ls`, `tree`, and `find -maxdepth 1` directory-listing signal at 3 or more listings per session/folder/range
- Session-level repeated-directory-listing insight and detail rows
- Repeated failed-command signal at 2 or more failures per session/command/range
- Session-level repeated-failed-command insight and detail rows
- Range-level and session-level optimization tips for repeated tool behavior and token-heavy sessions
- Waste signal rows include short `Fix:` suggestions so issues point directly to an improvement path
- `tool_event_failures` migration with reingestion trigger
- Parser, normalizer, storage, and popover tests
- `docs/TOKEN_WASTE_ANALYSIS.md`

Remaining:

- Add observed provider-specific failure result shapes as sanitized fixtures
