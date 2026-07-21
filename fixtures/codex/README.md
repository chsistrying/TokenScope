# Codex Fixtures

Place sanitized Codex CLI transcript/log fixtures here.

Do not commit private logs.

Fixtures should be small and deterministic.

## `session-usage.json`

Sanitized fixture format for M5 parser tests:

- Top-level JSON object with a `records` array.
- Each record represents one Codex session usage summary.
- Session IDs, project paths, project names, model names, timestamps, and token counts are fake.
- Timestamps are ISO 8601 strings.
- Token fields are raw integer counts under `usage`.
- The parser uses `ParserInput.sourcePath` as `rawSourcePath`; fixture files do not include real local paths.

## Edge Cases

`edge-cases.json` covers:

- missing model
- missing project path and project name
- cached input token fields
- derived totals when fixture `usage.total_tokens` is absent

`rollout-edge-cases.jsonl` covers:

- Codex rollout JSONL with missing model
- project name derived from `cwd`
- cached input token fields
- one malformed JSONL line inside an otherwise usable file
