# Parser Spec

## Goal

Parse local AI coding tool logs into normalized usage records.

The parser layer should answer:

- Which provider?
- Which model?
- Which session?
- Which project?
- How many tokens?
- How many cache creation and cache read tokens?
- What estimated cost?
- When did it happen?

## Providers

MVP providers:

- Claude Code
- Codex CLI

## Input

Provider parsers may read:

- JSON
- JSONL
- transcript files
- metadata files
- directory names
- file paths

Do not assume provider formats are stable.

Add fixtures whenever behavior changes.

For currently supported local log shapes, scanner filters, and known unsupported formats, see `docs/SUPPORTED_FORMATS.md`.

## Required Normalized Fields

```text
id
provider
model
project_path
project_name
session_id
start_time
end_time
input_tokens
cache_creation_input_tokens
cache_read_input_tokens
output_tokens
total_tokens
estimated_cost
raw_source_path
```

## Project Inference

Project/repo should be inferred in this order:

1. Explicit project path in log
2. Working directory in log
3. Parent folder from transcript path
4. Git repository name if `.git` can be found
5. "misc" or "unknown"

## Cost Estimation

Cost should be estimated using local pricing tables.

Pricing must be separated from parser logic.

If pricing is unknown:

- keep token counts
- estimated_cost should be null
- UI should display "—" instead of fake cost

## Accuracy Language

All cost should be described as estimated unless known to match official billing.

Avoid claiming billing-grade accuracy.

## Tests

Every parser change should include fixture-based tests.

Fixtures should be small, sanitized, and deterministic.
