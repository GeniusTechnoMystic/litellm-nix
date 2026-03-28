# System Patterns: litellm-nix

## Architecture
- **Nix-First**: All packaging and development tooling is defined in the root `flake.nix`.
- **Minimal Forking**: Upstream Python code in `litellm/` is changed as little as possible.
- **Separation of Concerns**: Nix-specific infrastructure lives in `nix/` and root-level files.
- **Deterministic Builds**: Frontend and Prisma packaging use fixed-output derivations.

## Key Technical Decisions
- Custom Prisma 5.4.2 packaging is intentional and pinned.
- Frontend is built offline in Nix to ensure reproducibility.
- Container deployment uses `compose.yaml` with mounted volumes for state.
- Dev shells provide consistent environments across contributors.

## Design Patterns in Use
- Declarative infrastructure via Nix flakes.
- Layered architecture (upstream code vs Nix packaging layer).
- Strict `.clineignore` and context management to prevent token bloat.
- Memory Bank pattern for persistent project knowledge.

## Critical Implementation Paths
- `flake.nix` is the authoritative build definition.
- `nix/container/compose.yaml` defines the runtime shape.
- `.clinerules/` and `memory_bank/` govern AI agent behavior.
- `Justfile` provides the canonical task interface.
