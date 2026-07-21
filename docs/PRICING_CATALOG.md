# Pricing Catalog

Last updated: 2026-07-11

TokenScope uses a local, versioned pricing catalog in `src/Core/Pricing/PricingCatalog.swift`.

Costs are estimates. They are not billing-grade reconciliation and may differ from provider invoices.

## Product Rules

- No background network calls.
- No telemetry.
- No API keys.
- No automatic online pricing updates.
- Unknown model pricing must keep token counts and return unknown cost.

## Current Catalog Version

```text
PricingCatalog.sourceVersion = 2026-07-11
```

The version should be the date the pricing assumptions were reviewed or changed.

## Manual Update Process

1. Review provider pricing from official provider sources.
2. Update `PricingCatalog.sourceVersion` to the review date.
3. Add or update model alias matching in `PricingCatalog.rates(provider:model:)`.
4. Add or update tests in `tests/NormalizerTests/PricingCatalogTests.swift`.
5. Keep unknown models returning `nil` estimated cost.
6. Run `swift test`.
7. Update `docs/PROJECT_STATUS.md` if the source version changes.

## Cache Token Rules

Claude:

- `input_tokens` are charged at input rate.
- `cache_creation_input_tokens` use cache creation rate when available.
- `cache_read_input_tokens` use cache read rate when available.

Codex:

- `cached_input_tokens` are treated as a subset of input tokens.
- Standard input cost subtracts cached input before applying input rate.
- Cached input uses cache read rate when available.

## Adding Model Aliases

Every alias should have a test.

Examples:

- canonical provider model id
- provider display-name variant
- observed local-log variant

Do not add a broad substring match if it can accidentally price a different model family.

## UI Behavior

The popover diagnostics section shows the local catalog version.

When pricing is unknown:

- cost renders as `—`
- token counts remain visible
- expensive-session lists exclude unknown-cost sessions

## Future Work

Manual update UI can be added later, but it should still avoid background network calls unless a new explicit privacy decision is accepted.
