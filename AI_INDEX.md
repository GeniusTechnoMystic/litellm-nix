# AI Index

This repository is a fork of upstream LiteLLM focused on Nix-based packaging and deployment.

Use this file as the fast entrypoint for AI agents working in the repo.

## What This Repo Is

- Upstream product code lives in the normal LiteLLM tree: `litellm/`, `tests/`, `ui/litellm-dashboard/`, `docs/my-website/`, `enterprise/`.
- Fork-specific work is concentrated in `flake.nix` and `nix/`.
- The goal of the fork is reproducible Nix packaging, OCI image builds, and Nix-friendly development tooling without heavily forking upstream Python application logic.

## Authoritative Files

- `README.md`
  - High-level explanation of the fork and its relationship to upstream LiteLLM.
- `CLAUDE.md`
  - Best general engineering/onboarding doc for the upstream LiteLLM codebase.
  - Includes architecture, testing, DB, proxy, and UI guidance.
- `flake.nix`
  - Main Nix entrypoint.
  - Treat this as the authoritative flake for current Nix work.
- `nix/docs/roadmap/litellm_nixos_task_status.md`
  - Best current status snapshot for the Nix layer.
  - Note: it is locally modified at the moment.

## Repo Map

- `litellm/`
  - Main Python library and proxy implementation.
- `tests/`
  - Large upstream test suite.
- `ui/litellm-dashboard/`
  - Next.js dashboard source.
- `litellm-proxy-extras/`
  - Prisma migrations and proxy extras package used by LiteLLM.
- `flake.nix`
  - Builds Python envs, Prisma packages, frontend artifact, app package, dev shells, and OCI image.
- `nix/`
  - Supporting Nix docs, Compose deployment assets, Prisma helper scripts, and custom Prisma packaging inputs.

## Nix Components

### Active Path

- `flake.nix`
  - Uses `uv2nix` and `pyproject-nix` to build Python environments.
  - Builds custom Prisma 5.4.2 engines and CLI from:
    - `nix/prisma-engines-5_4_2.nix/default.nix`
    - `nix/prisma-5_4_2.nix/default.nix`
  - Builds the dashboard with a two-stage process:
    - fixed-output dependency fetch
    - offline Next.js build
  - Produces:
    - `packages.default`
    - `packages.container`
    - multiple dev shells: `default`, `backend`, `frontend`, `ci`, `fullstack`
    - `apps.default`

### Runtime / Deployment Helpers

- `nix/container/compose.yaml`
  - Current practical deployment artifact for Podman/Docker Compose.
- `nix/container/entrypoint.sh`
  - Loads secrets from `ENV_VAR_FILE` and execs `litellm`.
- `nix/prisma/migrate.sh`
  - Helper script for schema initialization using the packaged schema inside LiteLLM.

### Legacy / Ambiguous Path

- `nix/flake.nix`
  - Older alternate flake.
  - Uses `nixpkgs-prisma5` instead of the root flake's custom Prisma derivations.
  - Treat as legacy unless explicitly working on reconciliation/removal.

## Important Current State

- Active branch: `nixos-container`
- Remotes:
  - `origin` -> `GeniusTechnoMystic/litellm-nix`
  - `upstream` -> `BerriAI/litellm`
- Recent fork work themes:
  - repo rename to `litellm-nix`
  - rename from `nixos/` to `nix/`
  - custom Prisma 5.4.2 packaging
  - deterministic frontend build in Nix
  - OCI/container packaging and dev shells
  - periodic upstream sync

## Current Local Worktree State

At the time this index was written:

- `flake.nix` has a local modification adding `prisma_5_4_2` to the backend shell.
- `nix/docs/roadmap/litellm_nixos_task_status.md` has local status updates.

Do not revert those changes unless the user asks.

## Known Gaps And Drift

Several Nix docs describe files or exports that do not currently exist.

Examples:

- `nix/AGENT.md`
- `nix/docs/architecture/litellm_nixos_architecture.md`
- `nix/docs/roadmap/litellm_nixos_project_plan.md`

Common stale references include:

- `nix/README.md`
- `nix/container/container.nix`
- `nix/container/litellm.yaml`
- `nix/modules/litellm-proxy.nix`
- `nix/overlay/default.nix`
- `nix/devshell/shell.nix`
- `nix/k8s/*`
- helper scripts under `nix/scripts/`

Before implementing against those docs, verify the file actually exists.

## Nix Status Snapshot

Strongest completed areas:

- custom Prisma 5.4.2 packaging
- root flake-based app/container build
- deterministic frontend packaging
- Compose deployment shape
- multi-shell dev environment

Still incomplete or planned:

- NixOS module
- overlay export
- Kubernetes manifests
- helper scripts in `nix/scripts/`
- sample `litellm.yaml`
- cleanup/reconciliation of `nix/flake.nix`
- formal upstream update process docs

## Useful Commands

- Inspect repo state:
  - `git status --short`
  - `git log --oneline --decorate -n 12`
- General upstream development:
  - `make test-unit`
  - `make lint`
- Nix-oriented entrypoints:
  - `nix develop`
  - `nix develop .#backend`
  - `nix develop .#frontend`
  - `nix build .#packages.x86_64-linux.container`

## Guidance For Future Agents

- Start from `CLAUDE.md` for upstream LiteLLM conventions.
- Start from `flake.nix` for the real Nix implementation.
- Use `nix/docs/roadmap/litellm_nixos_task_status.md` as the status tracker, but verify claims against the tree.
- Treat `nix/flake.nix` and several older Nix docs as potentially stale.
- Prefer small, reconciling changes that keep the fork close to upstream.
