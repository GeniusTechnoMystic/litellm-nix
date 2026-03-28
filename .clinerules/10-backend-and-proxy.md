---
paths:
  - "litellm/**"
  - "enterprise/**"
  - "tests/**"
  - "schema.prisma"
  - "litellm-proxy-extras/**"
---

# Backend and proxy guidance

## General patterns
- Follow existing LiteLLM provider and proxy patterns before introducing new abstractions.
- Prefer small, backward-compatible changes; this fork should stay close to upstream LiteLLM behavior.
- Keep imports at module scope unless avoiding a real circular import.

## Database and proxy rules
- For proxy database access, use Prisma model methods (`prisma_client.db.<model>`) instead of raw SQL.
- Avoid N+1 query patterns; batch-fetch and batch-write where possible.
- Keep all `schema.prisma` copies and related migrations in sync when schema changes are required.
- Never close cached HTTP/SDK clients during cache eviction paths.

## Model/provider changes
- Do not hardcode model-specific capability flags when the data belongs in `model_prices_and_context_window.json` or existing helpers.
- Preserve OpenAI-format behavior and existing transformation patterns for tool calling, streaming, and error handling.

## Validation
- Add or update focused tests for changed behavior.
- Prefer the smallest relevant test target first instead of jumping straight to the broadest suite.