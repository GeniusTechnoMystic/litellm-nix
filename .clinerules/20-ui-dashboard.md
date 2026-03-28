---
paths:
  - "ui/litellm-dashboard/**"
  - "litellm/proxy/_experimental/out/**"
---

# UI dashboard guidance

## Component and styling rules
- Do not introduce new Tremor components except the existing Tremor table components when needed.
- Prefer existing common components before creating new UI primitives.
- Keep UI changes aligned with the backend contract; verify whether endpoints expect a single value or an array.

## Testing rules
- Use Vitest and React Testing Library patterns already used in the repo.
- Prefer `screen.getByRole`, then other RTL queries in the documented priority order.
- Test names should start with `should`.
- Use `queryBy*` for absence checks and wrap `fireEvent` interactions in `act()` when needed.

## Build and asset rules
- After changing dashboard source, remember the proxy serves prebuilt assets from `litellm/proxy/_experimental/out/`.
- If the task needs proxy-served UI verification, rebuild the dashboard and copy the output into `litellm/proxy/_experimental/out/`.
- Provider logos used via `<img>` should not rely on `currentColor` fills.