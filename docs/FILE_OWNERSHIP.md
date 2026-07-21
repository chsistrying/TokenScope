# File Ownership

Use this to avoid multi-agent conflicts.

## Parser Agents

May edit:

- `src/Parsers/**`
- `fixtures/**`
- `tests/ParserTests/**`
- `docs/PARSER_SPEC.md` only if parser assumptions change
- `docs/SUPPORTED_FORMATS.md` when supported provider formats change

Must not edit:

- `src/UI/**`
- `src/App/**`
- `src/Storage/**` unless explicitly assigned

## Storage Agents

May edit:

- `src/Storage/**`
- `src/Core/Ingestion/**` when assigned ingestion/index behavior
- `tests/StorageTests/**`
- `tests/IngestionTests/**` when assigned ingestion/index behavior
- `docs/DATA_MODEL.md` if schema changes

Must not edit:

- `src/UI/**`
- provider parser internals

## UI Agents

May edit:

- `src/UI/**`
- `src/App/**`
- UI tests if added
- `docs/SPEC.md` if visible product behavior changes

Must not edit:

- `src/Parsers/**`
- raw parser behavior
- SQLite schema unless explicitly assigned

## Docs Agents

May edit:

- `README.md`
- `ORCHESTRATOR.md`
- `AI.md`
- `docs/**`

Must not edit source unless explicitly assigned.

## App/Runtime Agents

May edit:

- `src/App/**`
- `src/Core/Ingestion/**`
- refresh coordination tests
- `docs/ARCHITECTURE.md` if runtime flow changes

Must not edit parser behavior or SQLite schema unless explicitly assigned.
