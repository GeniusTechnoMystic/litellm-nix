# **LiteLLM-Nix Project Plan**

This roadmap describes the current direction of the Nix layer in this fork.

It is intentionally conservative: the primary goal is to keep the fork
useful and coherent without making upstream LiteLLM merges painful.

## **Primary Goals**

1. Package LiteLLM into a deterministic Nix build that produces a Docker/OCI image and a reusable NixOS module.
2. Provide practical Nix developer tooling and container deployment assets.
3. Allow seamless integration of the LiteLLM proxy into the home‑AI‑lab stack via flakes and modules.
4. Enable flexible deployment through Docker Compose and Kubernetes manifests.
5. Track upstream changes and keep the package up to date.
6. Apply Software Engineering best-practice patterns to project organization, design, development and deployment processes.
7. Apply best-of-breed, emergent Software Engineering & Development tooling.

## **Secondary Goals**

1. Keep upstream LiteLLM as the product source of truth.
2. Keep docs accurate enough that humans and AI agents can trust them.

## **Current Status Summary**

Already implemented:

* Root-flake-based build pipeline
* Custom Prisma 5.4.2 packaging
* Deterministic frontend build
* OCI image build
* Startup wrapper for the packaged image
* Compose deployment example
* Multiple Nix dev shells
* Justfile automation replacing Makefiles

Not yet implemented:

* Admin shellenv for containers
* Dev-specific OCI containers (DevPod/Codespaces)
* NixOS module
* Overlay exports
* Kubernetes / Helm manifests

## **Planned Tasks**

*Metrics Legend: Priority (P1-Critical, P2-High, P3-Normal) | Difficulty/Effort (Low, Med, High)*

| Task | Status | Priority | Diff/Effort | Time Req | Notes |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Update compose.yaml for Docker Compose | 🟡 In progress | P1 | Low / Low | 1-2 hrs | Needs updates to match the new root flake container entrypoint. |
| Enable runtime secret injection for containers | 🔜 Not started | P1 | Low / Med | 1-2 hrs | Support runtime secrets (Compose/Nix module); NEVER bake at build time. |
| Phase I: Embed admin shellenv into containers | 🔜 Not started | P1 | Low / Med | 2-4 hrs | Inject diagnostics (psql, jq, strace) into dev/prod images. |
| Phase II: Build dev version of container | 🔜 Not started | P1 | Med / Med | 4-8 hrs | Target devcontainer/CodeSpaces/DevPods with a tool-heavy image layer. |
| Phase III: Create overlay nix/overlay/default.nix | 🔜 Not started | P2 | Low / Low | 1-2 hrs | Expose litellm package derivation to the wider Nix ecosystem. |
| Phase IV: Implement NixOS module | 🔜 Not started | P2 | High / Med | 6-10 hrs | Declarative services.litellm.\* options to orchestrate systemd daemon. |
| Phase V: Kubernetes & Helm deployment assets | 🔜 Not started | P3 | Med / High | 8-16 hrs | K8s/Helm manifests (Deployments, ConfigMaps, Secrets, Ingress). |
| CI integration: Build/Publish GHCR via GH Actions | 🔜 Not started | P3 | Med / Med | 4-6 hrs | Automate immutable image builds on push. |
| Refine Justfile upstream sync process | 🟡 In progress | P2 | Low / Low | 1-2 hrs | Automation of UI conflicts and uv lock recreation is largely complete. |
| Document upgrade workflow in doc/UPDATING.md | 🔜 Not started | P3 | Low / Low | 1 hr | Document just sync-upstream and resolution strategies. |

## **Risks & Mitigation**

* **Drift from upstream**: if upstream LiteLLM changes its CLI or config, the container may break. Mitigation: monitor upstream release notes, update promptly.
* **Secrets management**: misconfiguring API keys may leak them into the image. Mitigation: never bake keys into the image; mount them via environment variables or secrets; document clearly.
* **Flake complexity**: Nix flakes can be hard to debug. Mitigation: keep the flake simple; break logic into separate files; test frequently.
