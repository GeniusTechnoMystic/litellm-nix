# Project Brief: litellm-nix

## Overview
This repository is a Nix-first fork of upstream `BerriAI/litellm`. The goal is to provide reproducible Nix packaging, OCI image builds, and Nix-friendly development tooling without heavily forking the upstream Python application logic.

## Core Requirements
- Maintain close compatibility with upstream LiteLLM.
- Provide Nix dev shells (`#backend`, `#frontend`, `#fullstack`).
- Build a deterministic OCI container image.
- Support local deployment via `nix/container/compose.yaml`.
- Use `just` recipes as canonical task entrypoints.

## Success Criteria
- The root `flake.nix` is the single source of truth for Nix builds.
- Upstream changes can be merged with minimal conflict.
- Developers can use `nix develop` and `just` for all common tasks.
- The container image is reproducible and secure.

## Key Constraints
- Never bake secrets into the image or committed files.
- Prefer smallest possible changes to upstream code.
- Treat legacy Nix files (`nix/flake-old.nix`, older docs) as deprecated unless verified.
