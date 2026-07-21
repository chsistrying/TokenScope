# Backlog

Last updated: 2026-07-12

## P0 - Before Public MVP

### UI Polish And Diagnostics

Goal: make the current app easier to trust and debug.

Status: Partially completed.

Completed:

- Show refresh diagnostics: discovered, parsed, unchanged, skipped.
- Show pricing catalog version.
- Show storage mode.
- Show database path when SQLite is active.
- Show in-memory fallback when persistence is unavailable.
- Stop forcing a log scan before the popover opens.
- Widen the popover and wrap long detail text.
- Keep popover values in a stable right column.
- Compact session insight and provider rows.

Tasks:

- Show parser/source status without raw private paths unless needed.
- Consider collapsible sections.

Acceptance:

- User can tell whether refresh worked.
- User can tell whether a cost is estimated.
- User can tell whether unchanged files were skipped.

### Interactive Session Detail

Goal: let users inspect one expensive or suspicious session.

Status: Partially completed.

Completed:

- Add clickable session detail for session insights, expensive sessions, and timeline rows.
- Show provider, model, project, time, cost, input, cache write, cache read, output, and total tokens.
- Show waste signal reason and recommendation.
- Add source metadata without exposing full raw paths by default.
- Avoid exposing full raw paths by default.

Tasks:

- Stress test long project/model/session names in the popover.

Acceptance:

- Clicking or expanding a session shows a single-session breakdown.
- Display sessions remain collapsed by provider session.

### Database Maintenance

Goal: give users control over local state.

Status: Partially completed.

Completed:

- Add `Rebuild Database`.
- Add `Open Database Location`.
- Add `Clear Local Data`.
- Add SQLite clear regression coverage.
- Add confirmation prompts before clear/rebuild.
- Add structured status rows for refresh/rebuild/clear/open DB actions.

Tasks:

- Stress test maintenance controls in dense popover content.

Acceptance:

- User can recover from stale/corrupt local state without manually finding SQLite files.

## P1 - Parser Robustness

### More Real-World Fixtures

Goal: reduce parser drift risk.

Status: Partially completed.

Completed:

- Add sanitized Claude edge fixture with missing model, derived project name, cache fields, and malformed partial JSONL.
- Add sanitized Codex summary fixture with missing model/project, cached input, and derived total.
- Add sanitized Codex rollout fixture with missing model, derived project name, cached input, and malformed partial JSONL.
- Keep malformed-only parser failures deterministic.

Tasks:

- Add more sanitized fixtures as new real-world shapes are observed.

Acceptance:

- Parsers remain deterministic and non-fatal on partial logs.

### Provider Format Audit

Goal: document supported and unsupported source formats.

Status: Partially completed.

Completed:

- Create `docs/SUPPORTED_FORMATS.md`.
- Document exact scanner roots and path filters.
- Document current Claude and Codex supported fields, fallbacks, and unsupported shapes.

Tasks:

- Keep supported/unsupported formats updated as new provider shapes are observed.

Acceptance:

- A contributor can add parser support without guessing current behavior.

## P2 - Pricing Management

### Manual Pricing Catalog Update

Goal: update pricing safely without background network calls.

Status: Partially completed.

Completed:

- Add documented manual update process.
- Add visible catalog version in UI diagnostics.
- Add test coverage for catalog source version date format.

Tasks:

- Add tests for new model aliases.
- Keep `docs/PRICING_CATALOG.md` current when pricing assumptions change.

Acceptance:

- Pricing changes are explicit, test-covered, and documented.

## P3 - Release Hardening

### Signed Release Planning

Goal: prepare for distribution outside local testing.

Status: Partially completed.

Completed:

- Add signing and notarization planning document.
- Update release checklist.
- Add changelog discipline.

Tasks:

- Decide signing and notarization approach.
- Add signed DMG packaging script after Apple Developer details are available.

Acceptance:

- A release can be reproduced and verified.

## Icebox

- Local git analytics.
- Cost per commit.
- Additional providers.
- Plugin architecture.
- Optional local-only semantic activity classification.
- Team/cloud features are not part of the local-first MVP.
