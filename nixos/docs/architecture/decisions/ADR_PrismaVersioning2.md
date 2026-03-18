# **Architecture Decision: Prisma Client Versioning**

## **Context**

The upstream LiteLLM project relies on prisma-client-py version \>=0.11.0,\<0.12.0. This package contains a hardcoded "bootstrap" loop that attempts to run npm install prisma if it cannot find a cached binary. This behavior persists through at least version v0.15.0, where the logic was further refined to prioritize NPM-managed binaries, making it inherently incompatible with isolated, offline Nix build sandboxes.

## **1\. The "Hold the Line" Strategy**

**Decision: DO NOT update pyproject.toml to a newer version.**

1. **Upstream Alignment:** Changing the version would cause our uv.lock to diverge significantly, leading to merge conflicts during upstream syncs.  
2. **Persistence of Issue:** Investigation of the v0.15.0 source tree confirms that the ensure\_cached logic remains fundamentally the same, meaning an upgrade provides no functional benefit for Nix compatibility.

## **2\. The Solution: Surgical Build-Time Patching**

Instead of changing the version, we use a **Surgical Nix Patch** during the litellm-app derivation.

* **Mechanism:** We use sed to rewrite prisma/cli/prisma.py inside the site-packages after the environment is constructed but before the generation step.  
* **Effect:** We bypass the ensure\_cached() function entirely by hardcoding it to return a PrismaBinaries object containing absolute Nix store paths for the Prisma CLI and Node.js.  
* **Benefit:** This fix is "invisible" to upstream and the Python runtime. It allows us to maintain 100% dependency parity with BerriAI while ensuring a 100% deterministic, offline build.

## **3\. The .mise.toml and Engine Trap**

We continue to reject .mise.toml for binary management. Nix provides the Rust engines (v5.22.0) compiled specifically for our isolated environment. The v0.11.0 Python client remains compatible with these newer engines via our environment variable mappings (e.g., PRISMA\_QUERY\_ENGINE\_LIBRARY).

## **References**

* **Hardcoded Loop Source:** prisma/cli/prisma.py\#L89 in prisma-client-py v0.11.0.  
* **Verification:** Commitment history in v0.15.0 confirms intentional reliance on NPM bootstrapping.  
* **Nix Implementation:** See installPhase in flake.nix.