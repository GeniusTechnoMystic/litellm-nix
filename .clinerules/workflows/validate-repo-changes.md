# Validate repository changes

Run the smallest sensible validation set for the current diff in this repository and summarize the outcome.

## Step 1: Inspect the diff
- Check `git status --short`.
- Identify which subsystems changed: Nix/package/deployment, backend Python, Prisma/schema, UI, tests, or docs.

## Step 2: Choose targeted validation
- For `flake.nix`, `nix/**`, `.envrc`, `Justfile`, `pyproject.toml`, `Dockerfile`, or compose changes:
  - Prefer `nix develop .#fullstack -c just lint`.
  - If Prisma-related files changed, include `nix develop .#fullstack -c just generate-prisma`.
  - Ask before expensive builds such as `nix build .#packages.x86_64-linux.container` or `just build-container`.
- For `litellm/**`, `enterprise/**`, or `tests/**` changes:
  - Run the narrowest relevant pytest target first.
- For `ui/litellm-dashboard/**` changes:
  - Run the relevant UI build/test commands and mention when rebuilt artifacts must be copied into `litellm/proxy/_experimental/out/`.
- For docs-only changes:
  - Validate links and consistency unless the user asks for deeper runtime validation.

## Step 3: Run commands
- Execute the selected validation commands.
- Stop on the first meaningful failure and show the error.

## Step 4: Summarize
- Report what changed.
- Report what validation ran, what passed or failed, and what was intentionally skipped.
- Call out any high-cost validation that should still be run manually.