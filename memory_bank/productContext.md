# Product Context: litellm-nix

## Why This Project Exists
NixOS users prefer declarative infrastructure and reproducible builds. This fork provides a clean way to run LiteLLM within the Nix ecosystem while staying as close as possible to the upstream project.

## Problems It Solves
- Lack of reproducible builds for LiteLLM in Nix environments.
- Inconsistent development setups across contributors.
- Difficulty deploying LiteLLM in containerized NixOS environments.
- Upstream LiteLLM's Python-centric tooling does not integrate well with Nix workflows.

## How It Should Work
- Developers should be able to run `nix develop .#fullstack` and use `just` commands for all tasks.
- The container image should be built deterministically from `flake.nix`.
- Deployment should be simple using `nix/container/compose.yaml`.
- Changes to upstream code should be minimal and clearly separated from Nix-specific infrastructure.

## User Experience Goals
- Seamless onboarding for Nix users.
- Fast feedback loops using Nix dev shells.
- Consistent behavior between development and production containers.
- Easy upstream syncing without breaking Nix packaging.
