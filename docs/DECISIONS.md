# Decisions

## ADR-001: macOS First

Status: Accepted

Reason:

The MVP depends on native menu bar UX and zero-config installation.

## ADR-002: No GitHub OAuth in MVP

Status: Accepted

Reason:

OAuth adds friction, permissions, security concerns, and setup steps.

The product principle is:

Download. Open. Done.

## ADR-003: Local First

Status: Accepted

Reason:

The app reads sensitive local development logs.

No telemetry, cloud sync, login, or API keys in MVP.

## ADR-004: Cost is Default Menu Bar Display

Status: Accepted

Reason:

Cost is easier to compare across providers than raw tokens.

## ADR-005: Activity Classification is Not MVP

Status: Accepted

Reason:

Planning/coding/debugging/refactor classification requires inference and may be inaccurate.

## ADR-006: Orchestrator-Agent Workflow from Day One

Status: Accepted

Reason:

The project will be built with a strong model acting as tech lead and Codex agents executing focused implementation tasks.

To avoid chaos, agents must follow file ownership and milestone boundaries.

## ADR-007: Local Pricing Catalog

Status: Accepted

Reason:

The app must remain local-first and should not make background network calls.

Pricing is stored in a versioned local catalog. Costs are estimates, not billing-grade reconciliation.

Automatic online pricing updates are out of scope until explicitly approved.

Manual pricing updates must follow `docs/PRICING_CATALOG.md` and include tests for changed aliases or rates.

## ADR-008: Incremental Ingestion Index

Status: Accepted

Reason:

Refreshing all logs every minute does not scale for heavy users.

The app records source file metadata and content hash so unchanged files can be skipped without reparsing.

## ADR-009: Token Analysis Is Heuristic

Status: Accepted

Reason:

Current Claude and Codex logs expose token fields but not reliable semantic activity stages.

The app can show token phases and waste signals, but it must not claim ground-truth planning/coding/debugging classification.

## ADR-010: Display Sessions Are Collapsed

Status: Accepted

Reason:

Provider logs may emit multiple records for one visible session.

The app stores raw normalized records separately, but popover timeline, expensive sessions, and session insights collapse by provider, session id, project, and model to avoid duplicate display rows.
