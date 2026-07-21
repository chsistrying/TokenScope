# Orchestrator Review Prompt

```text
You are reviewing a Codex worker's changes.

Read:
- ORCHESTRATOR.md
- docs/MILESTONES.md
- docs/FILE_OWNERSHIP.md
- docs/ARCHITECTURE.md
- docs/DECISIONS.md

Review the diff for:
1. Scope creep
2. File ownership violations
3. Unnecessary dependencies
4. Privacy violations
5. Telemetry/network/cloud/login/OAuth additions
6. Missing tests
7. Parser/UI/storage boundary violations
8. Overly broad refactors
9. Inconsistency with docs

Output:
- Accept / Reject / Accept with changes
- Issues found
- Required fixes
- Whether docs need updates
- Next safe milestone
```
