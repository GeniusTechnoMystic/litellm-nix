# litellm-nix workspace orientation

## Repository identity
- This repo is a Nix-first fork of upstream `BerriAI/litellm`, not a replacement product fork.
- Upstream application code mostly lives in `litellm/`, `tests/`, `ui/litellm-dashboard/`, `docs/my-website/`, and `enterprise/`.
- Fork-specific source-of-truth lives in root `flake.nix` and `nix/`.
- Prefer the smallest change that keeps the fork close to upstream.

## Files to consult first
- Use `AI_INDEX.md` as the fast repo map.
- Use `AGENTS.md` and `CLAUDE.md` for LiteLLM engineering conventions.
- Use `nix/AGENT.md` when working on `flake.nix`, `nix/**`, container assets, or Nix deployment docs.

## Working style
- This workspace is Nix-first. If shell assumptions are unclear, prefer `nix develop .#fullstack -c <command>`.
- Prefer `just` recipes for common tasks before inventing ad-hoc command sequences.
- Treat `.envrc` as meaningful: it selects `use flake .#fullstack`, not the minimal default shell.

## Guardrails
- Treat root `flake.nix` as authoritative. Treat `nix/flake-old.nix` and older Nix docs as legacy unless verified.
- Verify referenced files exist before following older documentation.
- Never bake secrets into the image or committed files; keep secrets in env files, Compose secrets, or mounted credentials.
- Do not treat `.claude/settings.json` as portable repo guidance; it contains developer-specific permissions.

## Shell output and context safety
- Treat any shell command with potentially large output (`grep`, `rg`, `find`, recursive listings, `git diff`, logs, broad test output) as unsafe to inline directly into the session context.
- Always redirect potentially large output to a temporary file first, then check its size (`wc -c`, `wc -l`, `du -h`, or similar) before deciding how much to read back into context.
- Only inline the full contents when the saved output is clearly small and safe for the remaining context window.
- If the output is large, summarize it and inspect only targeted slices with `head`, `tail`, narrower filters, or specific line ranges instead of dumping the whole file.
- Prefer reporting the file path plus a concise summary over pasting raw bulk output into the session.