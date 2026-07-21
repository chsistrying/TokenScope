# Codex Worker Prompt - M4 Claude Fixture Parser

```text
Read AI.md, ORCHESTRATOR.md, docs/PARSER_SPEC.md, docs/DATA_MODEL.md, docs/MILESTONES.md, and docs/FILE_OWNERSHIP.md.

Implement only M4 - Claude Fixture Parser.

Allowed files:
- src/Parsers/Claude/**
- fixtures/claude/**
- tests/ParserTests/**
- docs/PARSER_SPEC.md only if assumptions must be documented

Scope:
- Add sanitized Claude fixture examples
- Parse fixture files
- Extract provider, model, session, token fields where available
- Normalize records into shared schema
- Add tests

Do not:
- edit UI
- edit storage
- add Codex parsing
- add real home directory scanning
- add network/cloud/login/OAuth/telemetry

Summarize:
1. fixture format assumptions
2. files changed
3. tests added
4. limitations
```
