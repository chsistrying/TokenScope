# Architecture

## Overview

```text
Provider Parsers
      ↓
Normalizer
      ↓
SQLite Storage
      ↓
macOS UI
```

## Principles

Provider-specific logic must not leak into the UI.

The UI should only read normalized data.

No parser should directly update UI state.

## Suggested Module Boundaries

```text
src/
  App/
  Core/
    Models/
    Normalization/
    Pricing/
  Parsers/
    Claude/
    Codex/
  Storage/
  UI/
  Utilities/
tests/
  ParserTests/
  NormalizerTests/
  StorageTests/
fixtures/
  claude/
  codex/
```

## Data Flow

```text
App launch
  ↓
Scan ~/.claude and ~/.codex
  ↓
Check source-file ingestion index
  ↓
Skip unchanged files
  ↓
Parse changed provider logs
  ↓
Normalize records
  ↓
Upsert into SQLite
  ↓
Render menu bar and popover
```

## Runtime Refresh Flow

```text
Launch / timer / popover open / Refresh Now
  ↓
UsageRefreshCoordinator
  ↓
LocalUsageIngestionService
  ↓
LocalLogScanner
  ↓
Provider parsers
  ↓
RawUsageNormalizer + PricingCatalog
  ↓
SQLiteSpendStorage
  ↓
MenuBarController / PopoverViewController
```

## Storage

Persistent storage uses SQLite at:

```text
~/Library/Application Support/TokenScope/TokenScope.sqlite3
```

SQLite is responsible for:

- normalized sessions
- usage events
- schema migrations
- source file ingestion index

`prepare()` on persistent storage applies migrations and must not clear user data.

## Pricing

Pricing is local and versioned in `PricingCatalog`.

Parsers do not calculate cost. They only extract raw token fields. The normalizer applies pricing after provider records are parsed.

Unknown model pricing must produce `nil` estimated cost while preserving token counts.

## UI Aggregation

The popover has two layers:

- Raw normalized sessions for totals and breakdowns.
- Display sessions collapsed by `provider + sessionId + project + model` for timeline, expensive sessions, and session insights.

This prevents repeated provider records from showing as duplicate user-facing sessions.

## Token Analysis

Token analysis uses available normalized fields:

- base input
- cache creation input
- cache read input
- output

It does not infer semantic stages unless those stages exist in source logs.

## Privacy

No telemetry.

No cloud sync.

No external network calls.

No login.

No API keys.
