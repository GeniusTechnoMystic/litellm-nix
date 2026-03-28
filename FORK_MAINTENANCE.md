# **LiteLLM-Nix Fork Maintenance Guide**

This document tracks the structural divergence between this fork and upstream (BerriAI/litellm). Use this as a checklist during just sync-upstream.

## **🛡️ Our Source of Truth (Protected)**

These files are unique to our Nix/uv orchestration. In the event of a conflict, **ours** always wins.

* flake.nix / flake.lock  
* Justfile  
* .envrc / .mise.toml  
* nix/ directory contents  
* schema.prisma (Our source for Prisma 5.4.2 generation)

## **🧹 Upstream Noise (Automatically Purged)**

We do not use these lockfiles. They are purged after every merge to prevent uv or bun from becoming confused.

* \*\*/package-lock.json  
* \*\*/poetry.lock  
* requirements.txt

## **⚖️ Modified Core (Manual Review Required)**

These files exist upstream but have been modified by us to support uv2nix or bun. If upstream changes these, we must ensure our modifications (like hatchling build-backend) remain intact.

* pyproject.toml: Modified to use hatchling and uv workspace.  
* enterprise/pyproject.toml: Shared workspace logic.
* litellm-proxy-extras/pyproject.toml
* docs/my-website/package.json
* litellm-js/spend-logs/package.json
* litellm-js/proxy/package.json
* tests/proxy_admin_ui_tests/package.json
* tests/proxy_admin_ui_tests/ui_unit_tests/package.json
* ui/litellm-dashboard/package.json: Modified for bun compatibility.  

## **🔄 Sync Workflow**

1. Run just sync-upstream.  
2. Check git status for any "Both Modified" files in the **Modified Core** list.  
3. If pyproject.toml has a conflict, resolve it by ensuring upstream's new dependencies are added to our uv compatible format.  
4. Run just build-all to verify the bridge hasn't broken.
