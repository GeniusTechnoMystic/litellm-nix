# AGENT Overview for LiteLLM‑NixOS‑Container (nixos/)

Hello, agent! This `nixos/` directory belongs to the
`litellm-nixos-container` project, whose goal is to package the
[LiteLLM](https://github.com/BerriAI/litellm) proxy as a reproducible
service for NixOS. Use this overview to understand where things live and
how to contribute.

## Purpose

This directory contains Nix expressions and deployment assets for
building and running the LiteLLM proxy. It does **not** modify the
upstream Python code. Instead, it provides:

- A NixOS container definition for running the proxy in a homelab.
- A NixOS module to enable the proxy as a system service.
- An overlay to make the packaged proxy available as `pkgs.litellm`.
- Deployment templates (Compose and Kubernetes) for non‑Nix
  environments.
- Developer tooling (dev shell and scripts).

## Directory Layout

  ----------------------------------- ----------------------------------------------------------------------------------------------------------------------------------
  `flake.nix` (root)                  Defines the container build, module exports, overlay and devShells.
  `nixos/AGENTS.md`                   **You are here**---instructions for agent tooling.
  `nixos/README.md`                   High‑level description of the Nix packaging approach.
  `nixos/container/container.nix`     NixOS container definition: sets up environment, volumes, ports.
  `nixos/container/entrypoint.sh`     Entrypoint script that invokes `litellm` and handles signals.
  `nixos/container/litellm.yaml`      Sample configuration file for provider routing and cost tracking.
  `nixos/container/compose.yaml`      Reference Docker Compose service (optional).
  `nixos/modules/litellm-proxy.nix`   NixOS module exposing `services.litellm` options. When enabled, this module pulls the container image and runs it under systemd.
  `nixos/overlay/default.nix`         Overlay overriding `pkgs.litellm` to use this container build.
  `nixos/devshell/shell.nix`          Dev environment with `uv`, `python`, `jq`, `curl`.
  `nixos/scripts/`                    Helper scripts for building and testing the container.
  `nixos/k8s/`                        Kubernetes manifests for deploying the proxy in k3s.
  ----------------------------------- ----------------------------------------------------------------------------------------------------------------------------------

## Usage Guide

- **Build the container**:

  nix build .#packages.x86_64-linux.container

  The resulting image is stored in `./result` as a
  `docker-image.tar.gz`; load it via `docker load < ./result`.

- **Run via NixOS module**: In your system configuration, import the
  module and enable it:
```
  { config, pkgs, \... }:
  {
    imports = \[ inputs.litellm-nixos-container.nixosModules.litellm \];
    services.litellm.enable = true;
    services.litellm.settings.port = 4000;
    *\# Provide API keys via sops‑nix or environment variables*
  }
```
- **Customise** `litellm.yaml`: Copy `nixos/container/litellm.yaml` into
  your secrets and adjust providers, routing, cost tracking. Do not
  commit API keys.

- **Development**: Enter the dev shell:

  nix develop .#nixos

  Use `build-container.sh` and `test-proxy.sh` to build and run locally.

## Contribution Guidelines

- Keep packaging logic in `nixos/`; do not modify upstream code in
  `upstream/` unless necessary. Pull from upstream regularly.
- When adding features, update `nixos/README.md` and this `AGENTS.md`
  accordingly so that agents can discover new files.
- Use descriptive commit messages
  (e.g. `feat(container): add compose file`).
- Test builds with `nix build` before pushing. Use `nix flake check` to
  ensure the flake is valid.

Thank you for contributing to the LiteLLM‑NixOS‑Container project!
Keeping this directory structured and well‑documented ensures that
agents and humans alike can work effectively.
