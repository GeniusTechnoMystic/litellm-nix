---
paths:
  - "flake.nix"
  - "Justfile"
  - ".envrc"
  - "pyproject.toml"
  - "nix/**"
  - "nix/container/compose.yaml"
---

# Nix, packaging, and deployment guidance

## Preferred workflows
- Prefer `nix develop .#backend`, `nix develop .#frontend`, or `nix develop .#fullstack` plus `just` recipes over ad-hoc `pip`, `poetry install`, or `npm install`.
- Use `just sync`, `just generate-prisma`, `just test`, `just lint`, `just format`, `just type-check`, `just run`, and `just build-container` as the canonical task entrypoints when they fit the task.
- When running standalone commands outside an activated shell, prefer `nix develop .#fullstack -c <command>`.

## Architecture constraints
- Keep Nix changes narrow and packaging-focused before changing upstream Python application logic.
- Custom Prisma 5.4.2 packaging is intentional; do not casually replace it without checking `flake.nix` and `nix/prisma*`.
- The frontend is built deterministically in Nix via a fixed-output dependency fetch plus offline build; avoid introducing network-at-build-time assumptions.

## Runtime and deployment
- `nix/container/compose.yaml` is the concrete local deployment shape today and expects a prebuilt `localhost/litellm:latest` image.
- Compose mounts runtime state and workspace directories and expects external services like PostgreSQL and Qdrant via `host.containers.internal`.
- Keep runtime secrets external via `ENV_VAR_FILE`, Compose secrets, or mounted credential files.

## Safety reminders
- Do not commit live secrets, decrypted secret files, or generated runtime state.
- When documentation and implementation disagree, prefer the current tree and the root flake.
