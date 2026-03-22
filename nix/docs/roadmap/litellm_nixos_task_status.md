# LiteLLM-Nix Task Status

This file tracks the status of the Nix-specific work in this fork.

## Legend

- ✅ Completed
- 🟡 In Progress
- 🔜 Not Started
- ⏸ Deferred / Optional

## Tasks

| Task | Status | Notes |
| --- | --- | --- |
| Fork upstream LiteLLM and maintain a dedicated Nix branch | ✅ | Active work is on `nixos-container`, with upstream syncs merged in as needed. |
| Explain fork purpose in `README.md` | ✅ | Root README now frames the repo as an upstream LiteLLM fork with Nix tooling. |
| Add `nix/README.md` describing structure                   | ✅      | Completed; outlines container, module, overlay, etc.   
| Write initial `flake.nix` with container build             | ✅      | Completed using `uv2nix` and `dockerTools`.    
| Create `nix/container/container.nix`                       | n/a     | Moved in to root flake.  
| Write `entrypoint.sh` to launch proxy                      | 🟡     | Script moved into container, embedded in root flake. Needs review. |
| Provide `compose.yaml` for Docker Compose                  | 🟡     | WIP, needs updates due to changes to the container   
| Implement NixOS module in `modules/litellm.nix`      | 🔜     | Not started; should expose `services.litellm` options and run container via systemd. |
| Create overlay in `overlay/default.nix`                    | 🔜     | Not started; to override `pkgs.litellm`.                                             |
| Write dev shells                       | ✅     | Complete. frontend, backend, CI/SecOps & Fullstack devshells created.                                |
| Add helper scripts                         | 🟡     | Created root Justfile instead. Need to review make file to ensure all functions have been added to Justfile
| Write Kubernetes manifests under `k8s/`                    | 🔜     | Not started; for optional k3s deployment.                                            |
| Integrate container into `nixos-config` flake inputs       | 🔜     | Wait until container builds successfully.                                            |
| Document upgrade process and upstream sync                 | 🔜     | To be added in `doc/UPDATING.md`.    
| Add an agent-facing project index | ✅ | `AI_INDEX.md` summarizes the repo, the Nix layer, and the current status for AI agents. |
| Package custom Prisma 5.4.2 engines and CLI | ✅ | Implemented in `nix/prisma-engines-5_4_2.nix/` and `nix/prisma-5_4_2.nix/`. |
| Build the dashboard deterministically in Nix | ✅ | Implemented as a fixed-output dependency fetch plus offline frontend build. |
| Assemble the packaged LiteLLM app output | ✅ | `flake.nix` builds the Python runtime, generates Prisma client code, and embeds the built UI. |
| Build an OCI image from the packaged app | ✅ | Implemented via `dockerTools.buildLayeredImage` in the root flake. |
| Provide a startup wrapper for the packaged image | ✅ | Implemented in the root flake as `start-litellm`. |
| Provide a Prisma migration helper script | ✅ | Implemented in `nix/prisma/migrate.sh`. |
| Refresh stale Nix docs to match the actual tree | ✅ | `nix/AGENT.md`, architecture docs, and roadmap docs now describe the current implementation rather than missing files. |
| Unify the schema/migration story between wrapper and helper script | 🟡 | The startup wrapper and `nix/prisma/migrate.sh` currently assume different schema locations/run modes. |
