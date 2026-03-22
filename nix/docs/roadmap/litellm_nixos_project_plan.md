# LiteLLM-Nix Project Plan

This roadmap describes the current direction of the Nix layer in this fork.

It is intentionally conservative: the primary goal is to keep the fork
useful and coherent without making upstream LiteLLM merges painful.

## Primary Goals

1. Package LiteLLM into a deterministic Nix build that produces a
   Docker/OCI image and a reusable NixOS module.
2. Provide practical Nix developer tooling and container deployment assets.   
3. Allow seamless integration of the LiteLLM proxy into the    home‑AI‑lab stack via flakes and modules.
4. Enable flexible deployment through Docker Compose and Kubernetes manifests.
5. Track upstream changes and keep the package up to date.
6. Apply Software Engineering best-practice patterns to project organization, design, development and deployment processes.
7. Apply best-of-breed, emergent Software Engineering & Development tooling.

## Secondary Goals

1. Keep upstream LiteLLM as the product source of truth.
2. Keep docs accurate enough that humans and AI agents can trust them.

## Current Baseline

Already implemented:

- Root-flake-based build pipeline
- Custom Prisma 5.4.2 packaging
- Deterministic frontend build
- OCI image build
- Startup wrapper for the packaged image
- Compose deployment example
- Multiple Nix dev shells

Not yet implemented:

- NixOS module
- Overlay exports
- Kubernetes manifests

## Milestones

### M1: Repository Setup (status: Complete)

| Task                                                                 | Status       | Notes                                                                  |
| -------------------------------------------------------------------- | ------------ | ---------------------------------------------------------------------- |
| Fork upstream `BerriAI/litellm` and create `nixos-container` branch  | ✅ Completed | `GeniusTechnoMystic/litellm-nix` created.                              |
| Write `README.md` explaining purpose of fork and linking to upstream | ✅ Completed | Clarifies that the fork provides packaging, not feature changes.       |
| Outline directory structure in `nix/README.md`                       | ✅ Completed | Shows container, module, overlay, devshell, scripts and k8s dirs.      |
| Add initial `flake.nix` with container build skeleton                | ✅ Completed | Uses `uv2nix` to build Python env and `dockerTools` to assemble image. |

### M2: Container and Module Definition (current)

| Task                                                                                                       | Status         | Notes                                                                                      |
| ---------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------ |
| Create `nix/container/container.nix` defining a NixOS container specification (ports, volumes, networks)   | N/A | Moved into main root flake.                 |
| Write `nix/container/entrypoint.sh` to launch `litellm` with config                                        | N/A | Developed, but have moved code into main root nix flake.|
| Draft `nix/container/litellm.yaml` with sample provider config and routing                                 | 🟡 In progress | Currently at `nix/container/state/.config/litellm/config.yaml`                         |
| Provide `nix/container/compose.yaml` as reference for Docker Compose                                       | 🟡 In progress | Need to update now that the entrypoint script is embedded in the container itself.|
| Implement NixOS module in `nix/modules/litellm-proxy.nix`                                                  | 🔜 Not started | Expose `services.litellm.*` options, pulling container image and running it under systemd. |
| Add overlay `nix/overlay/default.nix` to supply `litellm` package                                          | 🔜 Not started | Should call `flake.inputs.self.packages.<system>.container`.                               |

### M3: Development Tools

- **DevShells**: Have created multiple devshells in the root flake.nix for frontend, backend, CI/SecOps and fullstack. Status: Completed.

- **Scripts**: Have moved helper scripts in to root Justfile. TODO: check all make file functions moved into Justfile and tidied up.

### M4: Deployment Templates

- **Kubernetes manifests**: Write `nix/k8s/deployment.yaml` and
  `service.yaml` to deploy the proxy into k3s. Include resource
  limits, environment variables, ConfigMap/Secret usage. Status: not
  started.
- **CI integration**: Add GitHub Actions to build the image on push;
  optionally publish to GHCR. Status: planned for later.

### M5: Upstream Synchronisation

- Add script to check for new releases of `litellm`; update
  `pyproject.toml` automatically and bump version in `flake.nix`.
- Document upgrade workflow in `doc/UPDATING.md` (e.g. run
  `uv pip compile -o requirements.lock` then
  `nix flake lock --update-input`).

## Risks & Mitigation

- **Drift from upstream**: if upstream LiteLLM changes its CLI or
  config, the container may break. Mitigation: monitor upstream release notes, update promptly.
- **Secrets management**: misconfiguring API keys may leak them into
  the image. Mitigation: never bake keys into the image; mount them
  via environment variables or secrets; document clearly.
- **Flake complexity**: Nix flakes can be hard to debug. Mitigation:
  keep the flake simple; break logic into separate files; test
  frequently.

