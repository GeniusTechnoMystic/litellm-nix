# **Architecture Decision: Prisma Client Versioning**

## **Context**

The upstream LiteLLM project relies on prisma-client-py version \>=0.11.0,\<0.12.0. As researched, this package is officially unmaintained by its author (Robert Craigie). The 0.11.x versions expect Prisma engines v5.4.2 / v5.8.0, but our NixOS 24.11 flake provides v5.22.0.  
Should we update pyproject.toml to 0.15.0 and manage the Node CLI via .mise.toml?

## **1\. The .mise.toml Trap (Security & Compatibility)**

**Decision: DO NOT use .mise.toml for Prisma binaries.**  
If you tell .mise.toml to download the Node.js prisma package, its post-install script reaches out to the internet to download pre-compiled Rust engine binaries.

* **The NixOS Problem:** Those downloaded binaries are compiled for standard Ubuntu/Debian (expecting FHS file paths like /lib64/ld-linux-x86-64.so.2). On a NixOS system or inside a pure Nix container, these dynamically linked binaries will instantly crash with "file not found" errors.  
* **The Nix Solution:** This is exactly why we use pkgs.prisma-engines in flake.nix. Nix compiles the Rust engines specifically to work in isolated environments. We *must* rely on Nix for the binaries.

## **2\. The pyproject.toml Trap (The Golden Rule)**

**Decision: DO NOT update pyproject.toml to 0.15.0.**  
While upgrading to 0.15.0 feels cleaner because it explicitly supports 5.17.0, it violates the **Golden Rule of Forking**.  
If you change pyproject.toml, your uv.lock file will massively diverge from upstream. Every time you try to git pull updates from BerriAI, you will face complex merge conflicts resolving dependency trees.

## **3\. The Ticking Time Bomb (Upstream's Responsibility)**

The entire LiteLLM engineering team knows prisma-client-py is dead. They are sitting on a ticking time bomb and will inevitably be forced to migrate off of it (likely to raw asyncpg, SQLModel, or SQLAlchemy).  
If you update the Prisma client on your fork now, you take ownership of that technical debt. When upstream eventually rips Prisma out, your custom fork modifications will make merging their refactor an absolute nightmare.

## **4\. The Recommended Path: "Hold the Line"**

Your just build-all logs from the previous cycle proved something very important: **It already works.**  
Even though the 0.11.0 client expects a 5.4.2 engine, the RPC communication protocol between the Python client and the 5.22.0 engines provided by NixOS 24.11 has not broken.  
**The Action Plan:**

1. Leave pyproject.toml completely untouched (\>=0.11.0,\<0.12.0).  
2. Keep using nixpkgs-prisma5 (which provides 5.22.0) in the flake.nix.  
3. Let the upstream BerriAI team solve the dead Python package problem. Once they migrate off Prisma or bump the version, you simply run git pull and uv sync, inheriting their solution for free without any merge conflicts.

## **References**

* **Python prisma PyPI History:** [https://pypi.org/project/prisma/\#history](https://pypi.org/project/prisma/#history)  
* **Python prisma-client-py Repository (Unmaintained):** [https://github.com/RobertCraigie/prisma-client-py](https://github.com/RobertCraigie/prisma-client-py)  
* **Python prisma-client-py Releases & Engine Mapping:** [https://github.com/RobertCraigie/prisma-client-py/releases](https://github.com/RobertCraigie/prisma-client-py/releases)  
* **NodeJS prisma NPM Package:** [https://www.npmjs.com/package/prisma](https://www.npmjs.com/package/prisma)  
* **Prisma Core Engine Releases:** [https://github.com/prisma/prisma/releases?page=5](https://github.com/prisma/prisma/releases?page=5)
* **NixOS 24.11 Prisma_5 Package:** [https://github.com/NixOS/nixpkgs/tree/nixos-24.11/pkgs/by-name/pr/prisma](https://github.com/NixOS/nixpkgs/tree/nixos-24.11/pkgs/by-name/pr/prisma)