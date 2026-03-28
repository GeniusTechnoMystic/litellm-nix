# Active Context: litellm-nix

## Current Work Focus
Implementing best-practice Cline rules and Memory Bank pattern to improve AI agent effectiveness in this workspace.

## Recent Changes
- Added comprehensive `.clinerules/memory-bank.md` following community standards.
- Created core Memory Bank documents (`projectBrief.md`, `productContext.md`, `systemPatterns.md`, `techContext.md`).
- Updated existing rules with YAML frontmatter for better metadata handling.

## Next Steps
- Complete remaining Memory Bank files (`progress.md`).
- Add self-improving and general development rules.
- Verify that Cline correctly reads the Memory Bank at the start of tasks.

## Active Decisions
- Treating instructions as version-controlled code in `.clinerules/`.
- Enforcing strict context management to prevent token overflow.
- Prioritizing Nix-first workflows in all documentation.

## Important Patterns & Preferences
- Always read Memory Bank first.
- Use temporary files for large outputs.
- Prefer `nix develop` and `just` over ad-hoc commands.
- Keep changes minimal when touching upstream code.
