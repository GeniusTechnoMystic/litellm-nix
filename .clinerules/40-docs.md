---
paths:
  - "**/*.md"
  - "docs/**"
  - "nix/docs/**"
---

# Documentation guidance

- Follow the docs-as-code approach from `nix/docs/DOCUMENTATION_GUIDELINES.md`: prefer Markdown and text-based diagrams such as Mermaid, PlantUML, DOT, and SVG.
- Preserve the distinction between upstream LiteLLM product code and this fork's Nix/deployment layer.
- Keep documentation aligned with files that actually exist. Clearly label legacy, planned, or prototype artifacts instead of describing them as implemented.
- For Nix docs, document the current root-`flake.nix` flow first; mention legacy paths only when they still matter.
- When behavior or workflows change in `flake.nix`, `nix/**`, `Justfile`, or deployment assets, update nearby docs or status notes in the same change when practical.