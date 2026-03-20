# Making prisma-client-py v0.11.0 Work in a Nix Sandbox for a Production LiteLLM Container

## Context and why this fails under Nix builds

Your situation is a “two-layer bootstrap” problem:

- **`prisma-client-py` (the Python package `prisma`) wraps the Node Prisma CLI**, and it provisions that CLI automatically by (a) ensuring a cache directory exists, then (b) running `npm install prisma@<pinned-version>` into that cache directory, then (c) invoking Node on the installed Prisma CLI entrypoint JS file. citeturn49view0turn46search1turn36view0  
- **Nix sandbox builds typically have no network**, except for carefully-scoped fixed-output derivations (and a couple of other explicit opt-outs), so a build-time invocation that tries to reach the npm registry will fail. citeturn53search1turn53search2  

This exact failure mode shows up in practice when running LiteLLM in an isolated/no-internet environment: the Prisma bootstrap step prints “Installing Prisma CLI” and then fails because it can’t download what it needs. citeturn42search7turn51search0  

Separately, the upstream `prisma-client-py` project is now **archived and no longer maintained** (archived April 15, 2025), and the deprecation issue explains the maintainer’s reasons (time constraints and upstream architecture shifts). citeturn36view0turn41search1  

## What prisma-client-py v0.11.0 is pinning, and what changes in later versions

The Prisma CLI version that `prisma-client-py` pins is explicitly documented in the upstream release notes:

- **v0.11.0**: internal Prisma version bumped **from 4.15.2 → 5.4.2**. citeturn41search2turn38view0  
- **v0.12.0**: internal Prisma version bumped **from 5.4.2 → 5.8.0**. citeturn41search2turn35search1  

So your understanding that v0.11.0 drags in Node Prisma **v5.4.2** is corroborated by the upstream release notes. citeturn41search2turn38view0  

Later `prisma-client-py` versions still follow the same architectural pattern (Node + npm-managed Prisma CLI + cache directory). The official docs continue to describe Prisma Client Python as relying on downloaded Node/Rust binaries, and the config reference still centres around “where do we cache binaries”, “which Prisma version”, and “how do we obtain Node”, not “use an already-installed Prisma CLI from the system”. citeturn44view0turn43view0turn36view0  

## How the Prisma CLI install works internally

The most direct, readable view of what matters is the `ensure_cached()` logic (shown below from a walkthrough that quotes the relevant module source).

Key observed behaviour:

- `binary_cache_dir` is used as the working directory for installing and running Prisma. citeturn49view0  
- The code defines an **expected entrypoint**:
  - `entrypoint = cache_dir / 'node_modules' / 'prisma' / 'build' / 'index.js'` citeturn49view0  
- It writes a “dummy” `package.json` into the cache directory if missing (to keep npm from walking up to other package.json files). citeturn49view0  
- If the entrypoint does **not** exist, it prints **“Installing Prisma CLI”** and runs:
  - `npm install prisma@{config.prisma_version}` with `cwd=config.binary_cache_dir`. citeturn49view0  
- If install fails, it tries to delete a partially-created entrypoint and re-raises. citeturn49view0  
- Finally, if the entrypoint still doesn’t exist, it raises an error. citeturn49view0  

Also important: `prisma-client-py`’s CLI wrapper explicitly talks about downloading a Node binary if needed and installing the CLI via npm. citeturn36view0turn46search1  

This mechanism matches the symptom you’re seeing under Nix (sandboxed build tries to do an npm install).

## Can prisma-client-py v0.11.0 be forced to bypass its own `npm install prisma@...`?

### What you can do without changing source code

Based on the `ensure_cached()` logic, there is one “supported-by-behaviour” bypass:

- **Make the expected entrypoint already exist** at:
  - `${PRISMA_BINARY_CACHE_DIR}/node_modules/prisma/build/index.js`  
  so that `ensure_cached()` never enters the “Installing Prisma CLI” branch. citeturn49view0turn43view0  

In other words: the “bypass” is not a switch; it’s satisfying the cache precondition.

However, there are two important implications for Nix:

- If you point `PRISMA_BINARY_CACHE_DIR` to a **read-only** directory (like the Nix store), you must also ensure `package.json` is present, because otherwise the code will try to write it. citeturn49view0  
- You must ensure the directory itself exists, because `ensure_cached()` will attempt to create it if absent. citeturn49view0  

### What you cannot do via a documented knob

The config reference documents options for:

- where binaries are cached (`binary_cache_dir` / `PRISMA_BINARY_CACHE_DIR`),  
- which Prisma version is used (`prisma_version` / `PRISMA_VERSION` plus a safety pairing `expected_engine_version` / `PRISMA_EXPECTED_ENGINE_VERSION`),  
- and how Node is sourced (`PRISMA_USE_GLOBAL_NODE`, `PRISMA_USE_NODEJS_BIN`, nodeenv-related options). citeturn43view0turn47search0  

But it **does not** document (and does not suggest) an option like:

- “use system `prisma` on PATH”,  
- “skip npm install”, or  
- “provide an explicit Prisma CLI JS entrypoint path”.

The “Binaries” reference page describes manual compilation and environment variables for engine binaries, not for swapping out the Prisma CLI installation mechanism. citeturn44view0  

### Direct answer to question 1

There is **no configuration option** in the exposed configuration surface to tell `prisma-client-py` “do not run npm install; always use an external Prisma CLI”. citeturn43view0turn44view0turn49view0  

The only non-invasive bypass is to **pre-populate** the cache directory so the entrypoint exists and `ensure_cached()` doesn’t try to install. citeturn49view0turn43view0  

## What to do instead under Nix: strategy trade-offs

This section maps closely to the options you listed, but with Nix-specific consequences and a recommended direction.

### Build outside the sandbox

You can make the build succeed by allowing network during the build that triggers npm install, but it’s a poor fit for “production container built by Nix” goals:

- Nix sandboxing with `sandbox = true` isolates builds and (on Linux) uses private namespaces including network; fixed-output derivations are treated specially. citeturn53search1turn53search2  
- Loosening sandboxing (“relaxed” or disabling it) is explicitly a networking policy change in common Nix deployments. citeturn53search0turn53search1  

Downsides for production:
- You lose (or at least weaken) reproducibility guarantees.
- You risk “works on the builder today” failures later if npm registry content, transitive dependencies, or engine downloads shift.

This is reasonable for a **one-off migration** or emergency build, but it’s not a strategy I’d recommend for a reliable long-term production image.

### Hack prisma-client-py to prevent `npm install`

This is the most deterministic approach as long as you keep the patch small and local:

- You can make `ensure_cached()` return an entrypoint that points at a Nix-provided Prisma CLI (or a vendored JS tree), and you can ensure Node comes from Nix as well.
- This aligns with the fact that the project is archived (you’re effectively maintaining your own compatibility layer anyway). citeturn36view0turn41search1  

Downsides:
- You own the patch forever.
- Any internal refactor in the part of `prisma-client-py` you patch could break you (less likely now that it’s archived, but still possible if you ever swap versions).

When this is a good idea:
- You need fast certainty and an auditable, single place where the sandbox escape was removed.

### Prebuild/preseed the Prisma CLI cache directory (no source patch)

This is the most “Nix-native” approach if you can make it work cleanly:

- Since `ensure_cached()` only installs when the expected entrypoint is missing, you can populate:
  - `node_modules/prisma/build/index.js`,
  - plus the dummy `package.json`,
  - inside a directory you control, and set `PRISMA_BINARY_CACHE_DIR` to it. citeturn49view0turn43view0  

Then configure Node sourcing to avoid nodeenv downloads:
- Prefer system Node (from Nix) via `PRISMA_USE_GLOBAL_NODE=True`. citeturn43view0turn47search0  
- You can also disable the `nodejs-bin` path if it complicates your closure (set `PRISMA_USE_NODEJS_BIN=False`). citeturn43view0turn47search0  

This solves the immediate *npm registry access* problem by never calling npm at build/runtime.

Where this tends to get tricky:
- You must align versions carefully if you try to use a different Prisma version than what the Python client expects.
- If you do override `PRISMA_VERSION`, you’re expected to also set `PRISMA_EXPECTED_ENGINE_VERSION` to the corresponding engine hash/version. citeturn43view0turn47search0  

### Using NixOS’ Prisma packages (engines + CLI) safely

Even outside Python, Prisma is sensitive to version alignment between CLI/client/engines. A NixOS 24.11-specific example shows breakage when the engines are at 5.22 but the npm `@prisma/client` is at 6.1.0, and the fix was downgrading to match 5.22. citeturn50search5  

For your use case, the key design point is:

- If you want `prisma-client-py` to use a Nix-provided engine set, you can export engine paths directly (as commonly done on NixOS) so nothing needs to be downloaded at runtime. citeturn50search1turn44view0  

The NixOS wiki provides a standard environment-variable pattern (schema engine, query engine binary and library, prisma-fmt). citeturn50search1  
The Prisma Client Python docs describe a similar “manual engine” approach for query/migration/introspection/fmt engines. citeturn44view0  

This doesn’t automatically solve the **Prisma CLI npm install** issue, but it reduces the remaining “download surface area” significantly.

### Checking v0.12.0–v0.15.0 for the same logic

The behaviour that causes your issue is not specific to v0.11.0:

- v0.12.0 explicitly keeps the same model (still an “internal Prisma version”, just bumped to 5.8.0). citeturn35search1turn41search2  
- The current documentation set still frames operation as “download binaries and run Node Prisma CLI”, with configuration around where to cache and how to obtain Node. citeturn36view0turn43view0turn44view0  
- Real-world LiteLLM reports in isolated environments show the runtime attempting to “Installing Prisma CLI” (i.e., still doing the same bootstrap step) when a cache isn’t already satisfied. citeturn42search7turn51search0  

So while versions may differ in the pinned Prisma version, **the bootstrap pattern remains**.

## Recommended approach for a production-grade Nix container

Given your explicit goal (“production container”, Nix flake, sandboxed build), the strategy that best fits Nix’s model is:

### Preseed the cache and pin everything explicitly

Conceptually:

1. **Pick the Prisma CLI version you will ship**:
   - Either keep the v0.11.0 pinned Prisma 5.4.2. citeturn41search2turn49view0  
   - Or move to a newer `prisma-client-py` (e.g., the Nixpkgs `prisma` Python package shows 0.15.0 is packaged), which reduces “how old is the pinned Prisma”, though it’s still an archived upstream. citeturn50search4turn36view0turn41search1  

2. **Materialise a `PRISMA_BINARY_CACHE_DIR` that already contains**:
   - `package.json` (the dummy one),
   - `node_modules/prisma/build/index.js` (and whatever else Prisma CLI needs under `node_modules`). citeturn49view0turn43view0  

   The key is: entrypoint exists ⇒ no npm install is attempted. citeturn49view0  

3. **Ensure Node comes from Nix, not nodeenv**:
   - Set `PRISMA_USE_GLOBAL_NODE=True`. citeturn43view0turn47search0  
   - Consider `PRISMA_USE_NODEJS_BIN=False` if you don’t want the Python `nodejs-bin` fallback in your closure. citeturn43view0turn47search0  

4. **Provide engines via Nix and point Prisma at them**:
   - Export engine env vars using the NixOS wiki pattern and/or the Prisma Client Python manual-binaries env vars. citeturn50search1turn44view0  

This produces a container that:
- builds without network access inside Nix sandbox, citeturn53search1turn53search2  
- starts without attempting npm downloads (because the cache is already satisfied), citeturn49view0turn42search7  
- and has explicit, auditable runtime dependencies.

### When patching is the better option

If pre-seeding is awkward (for example, you can’t easily reuse the `prisma_5` derivation’s internal node_modules layout, or Prisma’s layout changes), then the pragmatic “production” choice is:

- **Patch `ensure_cached()`** to never run `npm install`, and instead return an entrypoint path you control.

This is consistent with the reality that upstream is archived and you already have to own the integration long-term. citeturn36view0turn41search1  

### What I would avoid as a steady-state solution

- Building with sandbox disabled or network enabled, because Nix’s sandbox and “no undeclared network” model is a core part of why Nix-built production images stay stable over time. citeturn53search1turn53search2  

## Direct answers to your questions

### Can you force v0.11.0 prisma-client-py to bypass installing Prisma via npm?

Not via a documented config switch. The install is performed when the expected CLI entrypoint JS file does not exist, and the logic explicitly runs `npm install prisma@{config.prisma_version}` in that case. citeturn49view0turn43view0  

The only “no-code-change” bypass is to ensure the expected entrypoint already exists in the configured `PRISMA_BINARY_CACHE_DIR` so that the install branch is never taken. citeturn49view0turn43view0  

### If not, what strategy should you use?

For a production Nix container, the strongest long-term options are:

- **Preferred**: preseed the Prisma CLI cache directory and provide Node + engine binaries through Nix, so `ensure_cached()` never attempts npm. citeturn49view0turn50search1turn53search1  
- **Also viable**: patch `ensure_cached()` (or the code path that triggers it) to use a Nix-provided Prisma CLI entrypoint and never call npm. citeturn49view0turn36view0  
- **Last resort / dev convenience**: allow network during the build by relaxing sandboxing. This is explicitly a policy change around network isolation in Nix sandboxing. citeturn53search0turn53search1  

### Should you check v0.12.0–v0.15.0?

Yes, but mainly for *version alignment* and packaging convenience, not because it removes the bootstrap pattern.

- v0.12.0 still uses an internal pinned Prisma version (just newer). citeturn35search1turn41search2  
- The overall model (Node + cached Prisma CLI) persists into later docs and observed behaviour in the LiteLLM ecosystem. citeturn43view0turn42search7turn51search0  
- Nixpkgs has packaged Python `prisma` (showing 0.15.0), which may make overrides easier even though upstream is archived. citeturn50search4turn36view0