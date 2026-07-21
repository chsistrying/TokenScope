# AI Agent Instructions

This repository is developed with AI coding agents.

Before writing code, always read:

- ORCHESTRATOR.md
- docs/SPEC.md
- docs/ARCHITECTURE.md
- docs/PROJECT_STATUS.md
- docs/APP_AUDIT.md
- docs/AUDIT.md
- docs/BACKLOG.md
- docs/ROADMAP.md
- docs/DECISIONS.md
- docs/PARSER_SPEC.md
- docs/DATA_MODEL.md
- docs/CODE_STYLE.md
- docs/FILE_OWNERSHIP.md

## Core Rules

- Do not rewrite working code.
- Do not implement future milestones unless explicitly asked.
- Keep parser logic isolated from UI.
- Keep provider-specific logic inside provider parser modules.
- Normalize all provider data into the shared schema.
- UI must read normalized data, not raw logs.
- Prefer simple code over clever abstractions.
- Avoid unnecessary dependencies.
- Add or update tests when changing parser behavior.
- Do not add telemetry, login, cloud sync, OAuth, or external network calls.
- Assume all data is local and private.
- Keep files reasonably small.
- Do not rename public types or files unnecessarily.
- If uncertain about log formats, add fixtures and tests first.

## Development Style

Work milestone by milestone.

When asked to implement a milestone:

1. Read the relevant docs.
2. Inspect existing code.
3. Make the smallest change needed.
4. Add tests.
5. Run tests where possible.
6. Summarize what changed.

When asked to continue product work:

1. Read `docs/PROJECT_STATUS.md`.
2. Check `docs/BACKLOG.md`.
3. Pick the next highest-priority item unless the user explicitly directs otherwise.
4. Keep docs updated when behavior or architecture changes.

## Important Product Constraint

The app must feel like:

Download. Open. Done.

Any feature requiring manual setup is not MVP.
