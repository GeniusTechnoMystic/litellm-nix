# Tech Context: litellm-nix

## Technologies Used
- **Nix**: Core build and packaging system via `flake.nix`.
- **uv2nix / pyproject-nix**: For Python environment management.
- **Prisma 5.4.2**: Custom packaged database ORM (intentional version pin).
- **Just**: Task runner for common development commands.
- **Docker/Podman**: Container runtime for `compose.yaml` deployment.
- **Next.js**: For the admin dashboard UI (built deterministically in Nix).

## Development Setup
- Use `nix develop .#fullstack` for the complete environment.
- Prefer `just <recipe>` over ad-hoc commands.
- `.envrc` activates the fullstack shell automatically.

## Technical Constraints
- Frontend build must be offline and deterministic (no network at build time).
- Keep Nix changes narrow and packaging-focused.
- Do not commit secrets or generated runtime state.
- Large shell output must be redirected to temp files before analysis.

## Tool Usage Patterns
- Always read files fresh before editing with `replace_in_file`.
- Use temporary files for large command output.
- Prefer `nix develop .#fullstack -c <command>` for standalone commands.
- MCP servers should be kept to the minimum required.
