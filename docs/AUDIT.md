# Repository Audit

> **Note:** This is a point-in-time audit snapshot, not live project status. See `docs/PROJECT_STATUS.md` for current status.

Audit date: 2026-07-11

For full runtime/app audit, see `docs/APP_AUDIT.md`.

## Scope

This audit reviewed:

- Product docs
- Architecture docs
- Parser and normalization boundaries
- Storage implementation
- Refresh and ingestion behavior
- UI summary behavior
- Privacy constraints
- Test coverage
- Release packaging flow

## Executive Summary

The repository has moved beyond the original M0-M10 scaffold roadmap and now contains a working local-first MVP with post-MVP analysis features.

Primary finding: code and tests are ahead of the docs. The project needs docs to become the source of truth again.

## Verified Strengths

- Native macOS menu bar app exists.
- Claude and Codex parser modules are separated.
- Parser output is normalized before UI use.
- UI reads normalized sessions, not raw logs.
- SQLite persistence is implemented.
- Incremental ingestion index reduces repeated parsing.
- Local pricing catalog is separated from parser logic.
- Popover supports time ranges and provider sections.
- Token analysis and waste signals are implemented as heuristics.
- Display sessions are collapsed to avoid duplicate provider session rows.
- No dependency was added for SQLite; macOS system SQLite is used.
- No network, telemetry, cloud, OAuth, login, or API key behavior was found.
- `swift test` passes.

## Current Test Coverage

The suite covers:

- Parser interfaces and parser error behavior
- Claude fixture and transcript parsing
- Codex fixture and rollout parsing
- Normalized models and normalizer behavior
- Pricing estimates and unknown model fallback
- Local scanner behavior
- Ingestion success, skipping, and incremental index behavior
- In-memory and SQLite storage
- Menu bar summary formatting
- Popover summaries, ranges, token analysis, waste signals, session insights, and display-session collapse
- Refresh coordinator behavior

Current result:

```text
swift test: 74 tests passing
```

## Risks

### Parser Drift

Claude Code and Codex CLI log formats may change. The parser layer should remain fixture-first and conservative.

Mitigation:

- Add sanitized fixtures for every new observed format.
- Keep malformed files non-fatal.
- Preserve token counts even when cost is unknown.

### Pricing Drift

Pricing is a local snapshot. It can become stale.

Mitigation:

- Version the catalog.
- Add a manual pricing catalog update workflow later.
- Do not add automatic online updates without an explicit privacy/product decision.

### Semantic Overreach

The app can analyze token phases but cannot reliably infer planning/coding/debugging stages from current logs.

Mitigation:

- Label insights as signals.
- Avoid claiming ground truth activity classification.
- Add semantic classification only if supported by reliable log evidence or explicit local-only inference policy.

### UI Density

The popover now contains many sections. It may become crowded for heavy users.

Mitigation:

- Add collapsible sections or drill-down views.
- Keep the first viewport focused on summary and highest-value alerts.

### SQLite Migration Maturity

Schema migrations exist but are still simple.

Mitigation:

- Add migration tests for existing user databases before every schema change.
- Never use `prepare()` as destructive reset for persistent storage.

## Documentation Gaps Addressed

This audit introduced or updated:

- `docs/PROJECT_STATUS.md`
- `docs/AUDIT.md`
- `docs/BACKLOG.md`
- `docs/MILESTONES.md`
- `docs/ROADMAP.md`
- `docs/ARCHITECTURE.md`
- `docs/SPEC.md`
- `docs/DATA_MODEL.md`
- `docs/DECISIONS.md`
- `README.md`

## Acceptance Criteria For Future Work

Any future task should:

- Preserve local-first privacy guarantees.
- Include tests for behavior changes.
- Update docs when product or architecture behavior changes.
- Avoid adding dependencies without orchestrator approval.
- Avoid UI reading raw provider logs.
- Avoid parser logic in UI or storage.
