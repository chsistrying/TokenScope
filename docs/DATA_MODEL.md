# Data Model

## Normalized Session

```text
Session {
  id: String
  provider: Provider
  model: String
  projectPath: String?
  projectName: String
  sessionId: String
  startTime: Date
  endTime: Date?
  durationSeconds: Int?
  inputTokens: Int?
  cacheCreationInputTokens: Int?
  cacheReadInputTokens: Int?
  outputTokens: Int?
  totalTokens: Int?
  estimatedCost: Decimal?
  rawSourcePath: String
}
```

## Provider IDs

- `claude`
- `codex`

## Usage Event

```text
UsageEvent {
  id: String
  sessionId: String
  timestamp: Date
  inputTokens: Int?
  outputTokens: Int?
  totalTokens: Int?
  estimatedCost: Decimal?
  rawSourcePath: String
}
```

## Tool Event

Tool events represent local tool calls observed in provider logs. They are used for behavior-level waste signals such as repeated file reads.

```text
ToolEvent {
  id: String
  provider: Provider
  sessionId: String
  timestamp: Date
  toolName: String
  targetPath: String?
  command: String?
  workingDirectory: String?
  toolCallId: String?
  exitCode: Int?
  errorSummary: String?
  rawSourcePath: String
}
```

Tool events intentionally do not store prompt text or tool output content.

## Suggested SQLite Tables

```sql
providers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

models (
  id TEXT PRIMARY KEY,
  provider_id TEXT NOT NULL,
  name TEXT NOT NULL
);

projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  path TEXT
);

sessions (
  id TEXT PRIMARY KEY,
  provider_id TEXT NOT NULL,
  model_id TEXT,
  project_id TEXT,
  session_id TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT,
  duration_seconds INTEGER,
  input_tokens INTEGER,
  cache_creation_input_tokens INTEGER,
  cache_read_input_tokens INTEGER,
  output_tokens INTEGER,
  total_tokens INTEGER,
  estimated_cost REAL,
  raw_source_path TEXT NOT NULL
);

usage_events (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  input_tokens INTEGER,
  output_tokens INTEGER,
  total_tokens INTEGER,
  estimated_cost REAL,
  raw_source_path TEXT NOT NULL
);

source_files (
  provider_id TEXT NOT NULL,
  path TEXT NOT NULL,
  modified_at TEXT,
  byte_size INTEGER,
  content_hash TEXT NOT NULL,
  last_ingested_at TEXT NOT NULL,
  PRIMARY KEY (provider_id, path)
);

tool_events (
  id TEXT PRIMARY KEY,
  provider_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  tool_name TEXT NOT NULL,
  target_path TEXT,
  command TEXT,
  working_directory TEXT,
  tool_call_id TEXT,
  exit_code INTEGER,
  error_summary TEXT,
  raw_source_path TEXT NOT NULL
);
```

## Query Needs

The UI needs fast queries for:

- Today total cost
- Today total tokens
- Sessions today
- Breakdown by provider
- Breakdown by model
- Breakdown by project
- Most expensive sessions
- Timeline
- Token phase analysis
- Waste signals
- Repeated-read tool behavior
- Session insights

## Display Session Aggregation

Provider logs can emit multiple records for one user-visible session.

For display-only sections, records are collapsed by:

```text
provider + sessionId + project + model
```

Raw normalized records remain stored separately so totals and future drill-down can remain accurate.
