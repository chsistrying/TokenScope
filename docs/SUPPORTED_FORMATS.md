# Supported Formats

Last updated: 2026-07-11

This document describes the provider log shapes TokenScope currently scans and parses.

TokenScope only reads local files. It does not upload logs or call provider APIs.

## Scanner

Default roots:

- Claude: `~/.claude`
- Codex: `~/.codex`

Candidate file extensions:

- `.json`
- `.jsonl`
- `.log`

Current path filters:

- Claude candidates must be under `/.claude/projects/` and end with `.jsonl`.
- Codex candidates must be under `/.codex/sessions/` and end with `.jsonl`.

Unreadable roots and files are skipped.

## Claude

Supported shapes:

- Sanitized usage fixture records with `type: "usage"`.
- Claude transcript assistant records with `type: "assistant"` and `message.usage`.
- Claude transcript assistant tool-use blocks with `message.content[].type == "tool_use"`.

Supported fields:

- `timestamp`
- `end_time`
- `duration_seconds`
- `session_id` or `sessionId`
- `model`
- `cwd` or `project_path`
- `project_name`
- `usage.input_tokens`
- `usage.cache_creation_input_tokens`
- `usage.cache_read_input_tokens`
- `usage.output_tokens`
- `usage.total_tokens`
- `message.content[].name`
- `message.content[].input.file_path`
- `message.content[].input.path`
- `message.content[].input.command`

Fallback behavior:

- If `project_name` is absent but `cwd` is present, project name is derived from the last path component.
- If `usage.total_tokens` is absent, total is derived from input, cache creation, cache read, and output tokens where available.
- Non-assistant transcript rows are ignored.
- Malformed JSONL rows are skipped when at least one usable record exists.
- Malformed-only files fail deterministically.
- Tool-use rows are normalized into tool events for waste analysis; prompt text and tool output content are not stored.

Not currently supported:

- Semantic activity classification.
- Provider billing export formats.
- Non-JSON transcript formats.

## Codex

Supported shapes:

- Sanitized summary fixture records under a top-level `records` array.
- Codex rollout JSONL events.

Supported summary fixture fields:

- `session_id`
- `model`
- `started_at`
- `ended_at`
- `duration_seconds`
- `project.path`
- `project.name`
- `usage.input_tokens`
- `usage.cached_input_tokens`
- `usage.output_tokens`
- `usage.total_tokens`

Supported rollout fields:

- `session_meta.payload.id`
- `session_meta.payload.session_id`
- `session_meta.payload.cwd`
- `turn_context.payload.model`
- `turn_context.payload.cwd`
- `event_msg.payload.type == "token_count"`
- `event_msg.payload.info.last_token_usage`
- `event_msg.payload.info.total_token_usage`
- token usage `input_tokens`
- token usage `cached_input_tokens`
- token usage `output_tokens`
- token usage `total_tokens`
- `event_msg.payload.type == "tool_call"`
- `event_msg.payload.type == "exec_command"`
- `event_msg.payload.name`
- `event_msg.payload.tool_name`
- `event_msg.payload.target_path`
- `event_msg.payload.command`
- `event_msg.payload.arguments.file_path`
- `event_msg.payload.arguments.path`
- `event_msg.payload.arguments.command`

Fallback behavior:

- If rollout `session_id` is absent, the parser may derive a session ID from a `rollout-*` filename.
- If project name is absent but `cwd` is present, project name is derived from the last path component.
- Summary fixture totals are derived from input and output tokens when `usage.total_tokens` is absent.
- Rollout totals are not invented when provider rollout usage omits `total_tokens`.
- Malformed JSONL rows are skipped when at least one usable token record exists.
- Malformed-only files fail deterministically.
- Tool-call rows are normalized into tool events for waste analysis; prompt text and tool output content are not stored.

Not currently supported:

- Provider billing export formats.
- Non-rollout Codex log shapes unless represented by sanitized fixtures and tests.
- Semantic activity classification.

## Waste Analysis Inputs

Current behavior-level analysis supports:

- Direct `Read` tool calls with a path.
- Shell read commands that begin with `cat`, `sed`, `nl`, `head`, `tail`, or `wc` and include a path-like argument.
- Relative shell paths are resolved against the provider working directory when `cwd` is available.
- Repeated-read signal when the same normalized session reads the same path at least 3 times in the selected time range.
- Repeated broad-search signal when the same normalized session runs `rg`, recursive `grep`, or `find` over the same root at least 3 times in the selected time range.
- Repeated directory-listing signal when the same normalized session runs `ls`, `tree`, or `find -maxdepth 1` over the same folder at least 3 times in the selected time range.
- Repeated failed-command signal when the same normalized session runs the same command and fails at least 2 times in the selected time range.
- Session insights and session detail rows for repeated-read sessions.
- Session insights and session detail rows for repeated-search sessions.
- Session insights and session detail rows for repeated-directory-listing sessions.
- Session insights and session detail rows for repeated-failed-command sessions.

Current limitations:

- Command parsing is heuristic and intentionally conservative.
- `rg pattern Sources` and `rg --files Sources` are treated as broad searches over `Sources`; `rg pattern` without an explicit root is grouped under the provider working directory.
- `ls` without an explicit folder is grouped under the provider working directory.
- Claude failed-command detection currently uses `tool_use.id` matched to `tool_result.tool_use_id`.
- Codex failed-command detection currently uses rollout payload `exit_code`, `status`, `stderr`, `error`, or `error_summary` fields when present.

## Fixture Discipline

All fixture files must be sanitized and deterministic.

Never commit real local logs. Add small fixture files for every newly observed provider shape before changing parser behavior.
