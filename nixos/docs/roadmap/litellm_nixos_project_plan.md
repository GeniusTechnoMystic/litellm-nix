# LiteLLM‑NixOS‑Container: Project Plan / Roadmap

## Goals and Objectives

1. **Package LiteLLM** into a deterministic Nix build that produces a
   Docker/OCI image and a reusable NixOS module.
2. **Allow seamless integration** of the LiteLLM proxy into the
   home‑AI‑lab stack via flakes and modules.
3. **Enable flexible deployment** through Docker Compose and Kubernetes
   manifests.
4. **Track upstream changes** and keep the package up to date.

## Milestones & Tasks

### M1: Repository Setup (status: Complete)

| Task                                                                 | Status      | Notes                                                                  |
| -------------------------------------------------------------------- | ----------- | ---------------------------------------------------------------------- |
| Fork upstream `BerriAI/litellm` and create `nixos-container` branch  | ✅ Completed | `GeniusTechnoMystic/litellm-nixos-container` created.                  |
| Write `README.md` explaining purpose of fork and linking to upstream | ✅ Completed | Clarifies that the fork provides packaging, not feature changes.       |
| Outline directory structure in `nixos/README.md`                     | ✅ Completed | Shows container, module, overlay, devshell, scripts and k8s dirs.      |
| Add initial `flake.nix` with container build skeleton                | ✅ Completed | Uses `uv2nix` to build Python env and `dockerTools` to assemble image. |

### M2: Container and Module Definition (current)

| Task                                                                                                       | Status         | Notes                                                                                      |
| ---------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------ |
| Create `nixos/container/container.nix` defining a NixOS container specification (ports, volumes, networks) | 🟡 In progress | Should set `services.litellm.enable = true` and mount `/etc/litellm.yaml`.                 |
| Write `nixos/container/entrypoint.sh` to launch `litellm` with config                                      | 🔜 Not started | Use `tini` for PID 1; pass through environment variables.                                  |
| Draft `nixos/container/litellm.yaml` with sample provider config and routing                               | 🟡 In progress | Should illustrate cost-based routing and placeholder for API keys.                         |
| Provide `nixos/container/compose.yaml` as reference for Docker Compose                                     | 🔜 Not started | Map port 4000; mount config; set restart policy.                                           |
| Implement NixOS module in `nixos/modules/litellm-proxy.nix`                                                | 🔜 Not started | Expose `services.litellm.*` options, pulling container image and running it under systemd. |
| Add overlay `nixos/overlay/default.nix` to supply `litellm` package                                        | 🔜 Not started | Should call `flake.inputs.self.packages.<system>.container`.                               |

### M3: Development Tools

- **DevShell**: Provide `nixos/devshell/shell.nix` that offers a shell
  with `uv`, `python`, `jq`, `curl` for debugging the container.
  Status: not started.

- **Scripts**: Write helper scripts under `nixos/scripts/`:
  
  - `build-container.sh`: builds the container and tags it.
  - `test-proxy.sh`: runs the proxy locally using the built image
    and sample config.

### M4: Deployment Templates

- **Kubernetes manifests**: Write `nixos/k8s/deployment.yaml` and
  `service.yaml` to deploy the proxy into k3s. Include resource
  limits, environment variables, ConfigMap/Secret usage. Status: not
  started.
- **CI integration**: Add GitHub Actions to build the image on push;
  optionally publish to GHCR. Status: planned for later.

### M5: Upstream Synchronisation

- Add script to check for new releases of `litellm`; update
  `requirements.lock` automatically and bump version in `flake.nix`.
- Document upgrade workflow in `doc/UPDATING.md` (e.g. run
  `uv pip compile -o requirements.lock` then
  `nix flake lock --update-input`).

## Process and Workflow

1. **Work on a feature branch**: for each task, create a branch from
   `nixos-container`. Make changes in `nixos/` subfolders.
2. **Run local builds**: `nix build .#packages.x86_64-linux.container`
   to build the image; run `./result/bin/docker-load` to load it into
   Docker; test via `docker run` or `compose`. Optionally run
   `nix develop` to enter dev shell.
3. **Write docs**: update `nixos/README.md` and `nixos/AGENTS.md` to
   describe new files and usage.
4. **Commit and push**: keep commit messages descriptive
   (e.g. `feat(module): add NixOS module for LiteLLM`).
5. **Pull request**: open PR against `nixos-container` branch;
   self‑review; merge after tests pass.

## Risks & Mitigation

- **Drift from upstream**: if upstream LiteLLM changes its CLI or
  config, the container may break. Mitigation: lock dependencies in
  `requirements.lock`, monitor upstream release notes, update
  promptly.
- **Secrets management**: misconfiguring API keys may leak them into
  the image. Mitigation: never bake keys into the image; mount them
  via environment variables or secrets; document clearly.
- **Flake complexity**: Nix flakes can be hard to debug. Mitigation:
  keep the flake simple; break logic into separate files; test
  frequently.
