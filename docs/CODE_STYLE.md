# Code Style

## General

- Keep code simple.
- Prefer explicit names.
- Avoid clever abstractions.
- Add tests for parser behavior.
- Avoid unnecessary dependencies.
- Keep provider-specific logic isolated.

## File Size

Try to keep files under 300 lines.

If a file grows beyond that because it owns a coherent workflow, prefer extracting tested helpers over broad refactors.

## Error Handling

Parsers should be resilient.

A malformed log file should not crash the app.

## Privacy

Never add telemetry.

Never add cloud sync.

Never send local logs anywhere.

## UI

The app should feel lightweight, fast, and native.

Default menu bar display: cost.

Avoid exposing raw private paths by default. Show project names and provider/model context first.
