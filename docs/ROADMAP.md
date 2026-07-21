# Roadmap

## v0.1 - MVP

Goal: zero-config local spend analytics.

Milestones:

1. M0 Project skeleton
2. M1 Shared data model
3. M2 Parser interfaces
4. M3 SQLite storage interface
5. M4 Claude fixture parser
6. M5 Codex fixture parser
7. M6 Real local path scanner
8. M7 Menu bar display
9. M8 Popover breakdown
10. M9 Session timeline
11. M10 DMG release

Status: implemented.

## v0.2 - Runtime Reliability

Status: implemented.

- Refresh on launch, timer, popover open, and manual action
- SQLite persistence
- Incremental ingestion index
- DMG packaging

## v0.3 - Waste Signals

Status: implemented first pass.

- Repeated prompt detection
- Context-heavy session detection
- Cache write/read analysis
- Large session detection
- Output-heavy session detection
- Session insights

## v0.4 - UI Polish And Diagnostics

Status: next.

- Refresh diagnostics
- Pricing catalog version display
- Database path display
- Better dense popover layout
- Interactive session detail

## v0.5 - Activity Estimation

Estimated activity categories:

- planning
- coding
- debugging
- refactoring
- review

Important: these are estimates, not ground truth.

Do not implement until logs or local-only inference can support defensible labeling.

## v0.6 - Local Git Analytics

No GitHub OAuth.

Use local git data only.

## v1.0

- More providers
- Stable parser interface
- Public plugin architecture
- Improved release process
