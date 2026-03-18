# **Architecture Decision: Prisma Client Versioning**

## **Context**

The upstream LiteLLM project relies on prisma-client-py version \>=0.11.0,\<0.12.0. This package contains a hardcoded "bootstrap" loop that attempts to run npm install prisma if it cannot find a cached binary.  
A forensic audit of the v0.11.0 source code and engine binaries (v5.4.2 and v5.22.0) reveals a complex web of environment variables, some of which are legacy aliases or internal flags.

## **1\. The "Hold the Line" Strategy**

**Decision: DO NOT update pyproject.toml to a newer version.**

1. **Upstream Alignment:** Changing the version would cause our uv.lock to diverge significantly, leading to merge conflicts during upstream syncs.  
2. **Persistence of Issue:** Investigation of the v0.15.0 source tree confirms that the ensure\_cached logic remains fundamentally the same, maintaining the intentional reliance on NPM bootstrapping.

## **2\. The Solution: Surgical Build-Time Patching**

Instead of changing the version, we use a **Surgical Nix Patch** during the litellm-app derivation.

* **Mechanism:** We use sed to rewrite prisma/cli/prisma.py inside the site-packages after the environment is constructed but before the generation step.  
* **Effect:** We bypass the ensure\_cached() function entirely by hardcoding it to return a CLICache object (the internal type for v0.11.0) containing absolute Nix store paths for the Prisma CLI and Node.js.  
* **Benefit:** This fix is "invisible" to upstream. It allows us to maintain 100% dependency parity with BerriAI while ensuring a 100% deterministic, offline build.

## **3\. Forensic Environment Mapping**

Based on static scanning of the source trees, we have identified the following high-fidelity mappings to bridge the legacy Python client with modern Nix engines:

| Purpose | Legacy Var (v0.11.0) | Modern/Engine Var (v5.x) | Nix Value |
| :---- | :---- | :---- | :---- |
| **CLI Path** | PRISMA\_CLI\_BINARY | \- | ${pkgs.prisma}/bin/prisma |
| **Node Path** | PRISMA\_USE\_NODEJS\_BIN | \- | ${pkgs.nodejs}/bin/node |
| **Query Engine** | PRISMA\_QUERY\_ENGINE\_BINARY | PRISMA\_QUERY\_ENGINE\_LIBRARY | libquery\_engine.node |
| **Schema Engine** | PRISMA\_MIGRATION\_ENGINE\_BINARY | PRISMA\_SCHEMA\_ENGINE\_BINARY | schema-engine |
| **Global Node** | PRISMA\_USE\_GLOBAL\_NODE | \- | true |

## **4\. The .mise.toml and Engine Trap**

We continue to reject .mise.toml for binary management. Nix provides the Rust engines (v5.22.0) compiled specifically for our isolated environment. The v0.11.0 Python client remains compatible with these newer engines via our environment variable mappings.

## **References**

* **Hardcoded Loop Source:** prisma/cli/prisma.py\#L89 in prisma-client-py v0.11.0.  
* **Verification:** Forensic audit of environment variable strings in v0.11.0, 5.4.2, and 5.22.0.