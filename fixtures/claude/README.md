# Claude Fixtures

Sanitized Claude Code JSONL fixtures live here.

Do not commit private logs.

Fixtures should be small and deterministic.

## Fixture Format Assumptions

Each non-empty line in `session-usage.jsonl` is a fake JSON object with:

- `type: "usage"`
- optional ISO-8601 `timestamp` and `end_time`
- optional `duration_seconds`
- optional `session_id`
- optional `model`
- optional `cwd` or `project_path`
- optional `project_name`
- `usage.input_tokens`, `usage.output_tokens`, and optional `usage.total_tokens`

When `usage.total_tokens` is absent, the parser derives it from available input
cache, and output token counts. These fixtures are deterministic examples for
parser tests only and are not copied from real user logs.

## Edge Cases

`edge-cases.jsonl` covers:

- assistant transcript usage without a model
- project name derived from `cwd`
- fixture usage without `project_name`
- cache creation and cache read token fields
- one malformed JSONL line inside an otherwise usable file
