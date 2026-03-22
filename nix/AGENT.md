# AGENT Overview for `nix/`

This directory contains the Nix-specific packaging, deployment assets,
and design notes for the `litellm-nix` fork.

The upstream LiteLLM application code still lives in the normal project
tree (`litellm/`, `tests/`, `ui/`, etc.). The purpose of this folder is
to make that upstream project easier to build and run in a reproducible
Nix-centric environment.

## What Is Authoritative

- The root `flake.nix` is the current source of truth for Nix builds.
- `nix/prisma-engines-5_4_2.nix/` and `nix/prisma-5_4_2.nix/` contain
  the custom Prisma packaging used by the root flake.
- `nix/container/compose.yaml` and `nix/container/entrypoint.sh` are the
  most concrete deployment artifacts currently present in `nix/`.
- `nix/docs/roadmap/litellm_nixos_task_status.md` is the best quick
  status snapshot.
- `nix/flake.nix` is a legacy prototype. It is not the active build
  path, but it may still contain ideas worth reusing later.

## What This Directory Currently Contains

- `nix/AGENT.md`
  - This file.
- `nix/container/`
  - Compose deployment assets and the runtime entrypoint script.
- `nix/docs/`
  - Architecture notes, roadmap docs, ADRs, and diagrams for the Nix
    layer.
- `nix/modules/`
  - Reserved for future NixOS modules. Currently empty.
- `nix/prisma/`
  - Helper scripts related to Prisma migrations and schema bootstrap.
- `nix/prisma-5_4_2.nix/`
  - Custom Prisma CLI packaging.
- `nix/prisma-engines-5_4_2.nix/`
  - Custom Prisma engines packaging.
- `nix/scripts/`
  - Reserved for future helper scripts. Currently empty.

## Current Shape of the Project

Implemented and actively used:

- Root-flake-based app and OCI image build
- Custom Prisma 5.4.2 packaging
- Deterministic frontend build embedded into the Python package output
- Compose-based deployment shape
- Multiple Nix dev shells for backend, frontend, CI, and fullstack work

Planned but not yet implemented:

- NixOS module exports
- Overlay exports
- Kubernetes manifests
- Sample `litellm.yaml`
- Convenience scripts under `nix/scripts/`

## Working Guidance for Agents

- Start with the root `flake.nix` when reasoning about the actual Nix
  implementation.
- Use `CLAUDE.md` at repo root for upstream LiteLLM architecture and
  development conventions.
- Verify files exist before trusting older docs; some earlier design
  docs describe planned files that are not in the tree yet.
- Prefer small, well-scoped changes that keep the fork close to
  upstream. Avoid unnecessary edits to upstream Python code when the
  goal is packaging or deployment.

## Common Tasks

- Build the container image:

  ```bash
  nix build .#packages.x86_64-linux.container
  ```

- Enter the default shell:

  ```bash
  nix develop
  ```

- Enter the backend shell:

  ```bash
  nix develop .#backend
  ```

- Enter the frontend shell:

  ```bash
  nix develop .#frontend
  ```

## Documentation Expectations

When you change the Nix layer, update the related docs in `nix/docs/`
so they describe the current tree rather than an intended future tree.

In particular:

- do not describe missing files as if they already exist
- clearly label legacy or prototype artifacts
- prefer documenting the root `flake.nix` flow over old experiments
