# Codex Worker Prompt - M0 Project Skeleton

```text
Read:
- AI.md
- ORCHESTRATOR.md
- docs/SPEC.md
- docs/ARCHITECTURE.md
- docs/MILESTONES.md
- docs/FILE_OWNERSHIP.md
- docs/DATA_MODEL.md
- docs/CODE_STYLE.md

Implement only M0 - Project Skeleton.

Create the initial project skeleton for a native macOS menu bar app called TokenScope.

Scope:
- native macOS app structure
- parser module folders
- parser interface placeholders
- normalized model placeholders
- storage folder and storage interface placeholder
- placeholder menu bar UI
- test folders
- fixture folders

Do not:
- implement actual Claude parsing
- implement actual Codex parsing
- add GitHub integration
- add cloud sync
- add login
- add OAuth
- add telemetry
- add external network calls
- implement future milestones

Architecture rules:
- Keep parser logic isolated from UI.
- Keep provider-specific logic inside parser modules.
- UI should read normalized data only.
- Prefer simple code and minimal dependencies.

After changes, summarize:
1. Files created
2. Architecture decisions
3. How to build/run
4. What the next milestone should be
```
