# Token Waste Analysis

Last updated: 2026-07-11

## Research Notes

External research and reports support treating agentic coding token use as a product problem, not just a billing display problem:

- The arXiv paper "How Do AI Agents Spend Your Money? Analyzing and Predicting Token Consumption in Agentic Coding Tasks" reports that agentic coding tasks can consume far more tokens than ordinary chat/code-reasoning tasks, that input tokens are a major cost driver, and that more token use does not necessarily imply better task accuracy.
- The arXiv paper "On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents" reports lower median runtime and lower output-token use when coding agents have repository guidance files, which supports adding optimization guidance rather than only reporting totals.
- The arXiv paper "Dive into Claude Code: The Design Space of Agentic Coding" describes the model-tool loop and context compaction design space, which supports analyzing tool-call patterns separately from session token totals.
- Public business reporting, including Wired coverage of high Claude token usage in production coding workflows, reinforces that token volume can become a practical operational concern.

References:

- https://arxiv.org/abs/2604.22750
- https://arxiv.org/abs/2601.20404
- https://arxiv.org/abs/2604.14228
- https://www.wired.com/story/claude-tokens-compute-cost-code-8x8

## Product Direction

TokenScope should treat token waste as two related layers:

- Token-shape signals: input-heavy sessions, high cache writes, large sessions, output-heavy sessions.
- Behavior-shape signals: repeated file reads, repeated broad searches, repeated failed commands, and churn around the same files.

The first layer works from usage counters. The second layer needs provider log tool-call metadata.

## Implemented

Current implementation adds a privacy-preserving `ToolEvent` model and SQLite `tool_events` table.

Stored fields:

- Provider
- Session ID
- Timestamp
- Tool name
- Target path when available
- Shell command when available
- Working directory when available
- Raw source path

Not stored:

- Prompt text
- Tool output text
- Full assistant responses

Current signal:

- `Repeated file reads`: same session reads the same path at least 3 times in the selected time range.
- `Repeated broad searches`: same session runs `rg`, recursive `grep`, or `find` over the same root at least 3 times in the selected time range.
- `Repeated directory listings`: same session runs `ls`, `tree`, or `find -maxdepth 1` over the same folder at least 3 times in the selected time range.
- `Repeated failed commands`: same session runs the same command and fails at least 2 times in the selected time range.
- Repeated-read session insight and selected-session detail rows.
- Repeated-search session insight and selected-session detail rows.
- Repeated-directory-listing session insight and selected-session detail rows.
- Repeated-failed-command session insight and selected-session detail rows.
- Relative shell paths are resolved against the provider working directory when `cwd` is available.

Supported sources:

- Claude `message.content[].tool_use`
- Codex rollout `event_msg.payload.type == "tool_call"`
- Codex rollout `event_msg.payload.type == "exec_command"`

## Limitations

- Shell command parsing is conservative and only handles obvious read commands.
- Broad-search parsing is conservative and only handles obvious `rg`, recursive `grep`, and `find` commands.
- Directory-listing parsing is conservative and only handles obvious `ls`, `tree`, and shallow `find` commands.
- Failed-command parsing depends on provider logs exposing tool result failure metadata.
- Repeated read count is a signal, not proof of waste. Some repeated reads are valid when files are changing.

## Next Work

1. Add more provider-specific failed-command result fixtures as they are observed.
2. Add recommendations tied to each behavior signal.
