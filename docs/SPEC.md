# SPEC

## Product

TokenScope is a native macOS menu bar app for zero-config AI coding spend analytics.

## One-line Pitch

See where your Claude Code and Codex tokens actually went.

## Product Principles

### 1. Zero Configuration

Download.  
Open.  
Done.

No login.  
No API keys.  
No OAuth.  
No onboarding wizard.

### 2. Local First

Everything stays on the user's Mac.

### 3. Native Experience

The app should feel like a lightweight macOS utility.

### 4. Explain Spending

The app should show not only how much was used, but where it went.

## Target Users

- Claude Code users
- Codex CLI users
- Developers using multiple AI coding agents
- Heavy AI coding users who care about cost, quota, and token usage

## MVP Platform

- macOS only

## Data Sources

The app should automatically detect and parse local logs from:

- Claude Code
- Codex CLI

Expected local directories:

- `~/.claude`
- `~/.codex`

## MVP Features

### 1. Menu Bar

Configurable summary:

- Cost
- Tokens
- Cost + Tokens

Default: Cost.

### 2. Popover Summary

- Total, Today, and 7-day views
- Total estimated cost
- Total tokens
- Session count
- Provider sections
- Model breakdown
- Project/repo breakdown
- Most expensive sessions
- Timeline
- Token phase analysis
- Waste signals
- Session insights
- Selectable session detail

### 3. Session Detail

Current implementation provides first-pass interactive session detail in the popover.

Users can select a row from session insights, expensive sessions, or timeline to show a single-session breakdown.

Current session insight fields:

- provider
- model
- project/repo
- start time
- input/context signal
- cache write signal
- cache read signal
- output signal
- total tokens
- estimated cost where available
- recommendation
- safe source description

Remaining:

- continued long-name and dense-history UI stress testing

### 4. Refresh And Persistence

- Refresh on launch
- Refresh every 60 seconds
- Popover opens from cached local summary state without forcing a log scan first
- Manual `Refresh Now`
- SQLite persistence
- Incremental source-file ingestion index

## Non Goals

Not in MVP:

- GitHub OAuth
- Cloud sync
- Team dashboard
- Windows support
- Linux support
- Ground-truth activity classification
- Planning/coding/debugging breakdown
- PR analytics
- Cost per commit
- Billing-grade cost reconciliation
- Automatic online pricing updates

## Accuracy Language

Costs are estimated from a local pricing catalog.

Token analysis and waste signals are heuristics derived from available token fields. They must not be presented as proof of semantic activity such as planning, coding, debugging, or refactoring.
