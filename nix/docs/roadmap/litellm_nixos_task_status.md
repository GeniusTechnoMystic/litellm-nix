# LiteLLM‑NixOS‑Container: Task Status

This file records the status of tasks for packaging and integrating the
LiteLLM proxy via Nix.

## Legend

- ✅ **Completed**
- 🟡 **In Progress**
- 🔜 **Not Started**

## Tasks

| Task                                                       | Status | Notes                                                                                |
| ---------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------ |
| Fork `BerriAI/litellm` and create `nixos-container` branch | ✅      | Completed via GitHub web interface.                                                  |
| Explain fork purpose in `README.md`                        | ✅      | Upstream link and rationale documented.                                              |
| Add `nixos/README.md` describing structure                 | ✅      | Completed; outlines container, module, overlay, etc.                                 |
| Write initial `flake.nix` with container build             | ✅      | Completed using `uv2nix` and `dockerTools`.                                          |
| Create `nixos/container/container.nix`                     | 🟡     | Partially done; needs ports, volumes and system options.                             |
| Write `entrypoint.sh` to launch proxy                      | 🔜     | Not yet implemented; will call `litellm` CLI via `tini`.                             |
| Draft sample `litellm.yaml` config                         | 🟡     | Basic structure sketched; needs provider entries.                                    |
| Provide `compose.yaml` for Docker Compose                  | 🔜     | Not started; replicate container settings for non-Nix deployments.                   |
| Implement NixOS module in `modules/litellm-proxy.nix`      | 🔜     | Not started; should expose `services.litellm` options and run container via systemd. |
| Create overlay in `overlay/default.nix`                    | 🔜     | Not started; to override `pkgs.litellm`.                                             |
| Write dev shell `devshell/shell.nix`                       | 🔜     | Not started; to provide `uv`, `python`, `jq`, `curl`.                                |
| Add helper scripts under `scripts/`                        | 🔜     | Not started; to build and test container locally.                                    |
| Write Kubernetes manifests under `k8s/`                    | 🔜     | Not started; for optional k3s deployment.                                            |
| Integrate container into `nixos-config` flake inputs       | 🔜     | Wait until container builds successfully.                                            |
| Document upgrade process and upstream sync                 | 🔜     | To be added in `doc/UPDATING.md`.                                                    |
