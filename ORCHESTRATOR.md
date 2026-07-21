# Orchestrator Workflow

The orchestrator acts as tech lead.

The orchestrator should use the strongest available model.

Codex agents should be used as focused implementation workers.

## Responsibilities

The orchestrator is responsible for:

- Reading product and architecture docs
- Keeping `docs/PROJECT_STATUS.md`, `docs/AUDIT.md`, and `docs/BACKLOG.md` current
- Breaking work into small milestones
- Assigning one milestone per agent
- Preventing scope creep
- Reviewing diffs before merge
- Keeping docs as the source of truth
- Ensuring tests and fixtures are updated
- Ensuring privacy constraints are preserved

## Orchestrator Rules

- Do not ask one agent to implement the whole app.
- Do not assign overlapping files to multiple agents at the same time.
- Do not parallelize before the project skeleton and shared models are stable.
- Any architecture change requires explicit orchestrator approval.
- Any dependency addition requires explicit orchestrator approval.
- Any feature that needs login, OAuth, cloud, telemetry, or network calls is rejected for MVP.
- Parser agents should work fixture-first.
- UI agents should not parse raw logs.
- Storage agents should not know provider-specific details.

## Recommended Agent Sequence

Current implementation has completed the original M0-M10 flow and several post-MVP milestones.

Before assigning new work, read:

- `docs/PROJECT_STATUS.md`
- `docs/APP_AUDIT.md`
- `docs/AUDIT.md`
- `docs/BACKLOG.md`

### Phase 0: Single Agent

Use one agent to create the project skeleton.

Milestone:

- M0 Project Skeleton

### Phase 1: Single Agent

Use one agent to stabilize shared contracts.

Milestones:

- M1 Shared Data Model
- M2 Parser Interfaces
- M3 Storage Interface

### Phase 2: Parallel Agents

Only after shared contracts are stable.

Parallel tasks:

- Agent A: Claude fixture parser
- Agent B: Codex fixture parser

### Phase 3: Single Agent Integration

Use one agent to integrate normalized output into storage.

Milestones:

- SQLite ingestion
- Today queries
- Breakdown queries

### Phase 4: UI Agent

Use one agent for menu bar and popover UI.

Milestones:

- Menu bar display
- Popover breakdown
- Timeline

### Phase 5: Product Hardening

Use focused agents for:

- UI polish and diagnostics
- Interactive session detail
- Database maintenance controls
- Parser robustness
- Release hardening

## Review Checklist

Before accepting an agent's work:

- Does it stay within the assigned milestone?
- Did it avoid unrelated refactors?
- Did it avoid future roadmap features?
- Did it follow file ownership boundaries?
- Did parser behavior include tests and fixtures?
- Did it avoid telemetry/network/cloud/login?
- Did it keep provider-specific logic out of UI?
- Did it update docs only when necessary?
- If behavior changed, did it update `PROJECT_STATUS`, `BACKLOG`, or relevant architecture docs?
