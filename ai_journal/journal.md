# **AI Knowledge Base & Architectural Journal**

*This file contains critical context for AI agents working on this repository. Read this before suggesting structural changes.*

### **📝 Entry Template**

For future AI agents: When adding a new architectural rule, bugfix, or context note, please use the following format:

* **Date:** YYYY-MM-DD  
* **Agent:** \[e.g., Gemini, Claude, GPT-4\]  
* **Prompt/Trigger:** "\[Brief description of the prompt, bug, or user requirement that triggered this entry\]"  
* **Context/Bug/Rule:** \[The actual details\]

## **1\. The Gunicorn / Nix Immutability Bug**

* **Date:** 2026-03-26  
* **Agent:** Gemini  
* **Prompt/Trigger:** *"Container runtime warnings/errors: PermissionError: \[Errno 13\] Permission denied: '/state/.local/share/litellm/migrations/\_logging.py'"*  
* **Context**: The /nix/store is strictly read-only (0444).  
* **The Bug**: LiteLLM's initialization logic uses shutil.copy2() to copy migration scripts into /tmp. Because copy2 preserves metadata, the copied files in /tmp become read-only. When multiple Gunicorn workers boot concurrently, Worker 2 crashes with a PermissionError when trying to overwrite Worker 1's read-only file.  
* **The Fix**: In flake.nix, we run a sed patch during the installPhase to downgrade shutil.copy2 to shutil.copy across the python source files. **Do not remove this patch.**

## **2\. UI Pathing Strictness**

* **Date:** 2026-03-26  
* **Agent:** Gemini  
* **Prompt/Trigger:** *"Why did you drop out from the end of the UI\_TARGET path? ... proxy\_server.py:1260 \- Packaged UI at ...\_experimental/out is invalid or incomplete."*  
* **Context**: LiteLLM's proxy\_server.py has a hardcoded, rigid check for the Next.js frontend assets.  
* **The Rule**: The UI MUST be placed exactly at litellm/proxy/\_experimental/out. Do not try to flatten this to \_experimental/ or the server will throw an invalid UI error and refuse to serve the dashboard.

## **3\. The "nix-direnv" Bloat Trap**

* **Date:** 2026-03-26  
* **Agent:** Gemini  
* **Prompt/Trigger:** *"Is it expected for each container build to take 922seconds (\~15min) and for the podman image to be \~5.54GB? How can we determine where most of the bloat is coming from?"*  
* **Context**: We use streamLayeredImage to build the OCI container.  
* **The Bug**: We previously included coreTools in the container, which contained nix-direnv. Because nix-direnv requires the entire Nix package manager (and its GCC/C++ dependencies), this silently injected 3.5GB of bloat into the production container.  
* **The Rule**: Keep coreTools strictly for local developer shells. The container must only use containerDiagTools. Do NOT add nix-direnv, google-cloud-sdk, or compilers to coreTools or containerDiagTools. They belong in backendTools.

## **4\. Justfile Podman Caching**

* **Date:** 2026-03-26  
* **Agent:** Gemini  
* **Prompt/Trigger:** *"It still took 971s to build the container. And it still builds every single fucking time whether I changed any fucking thing or not"*  
* **Context**: just build-container pipes uncompressed tar layers to podman load. Even if Nix evaluates instantly, Podman takes \~15 minutes to process the 1.5GB stream.  
* **The Fix**: We cache the /nix/store/... hash in .nix-container-cache. The Justfile checks this hash and bypasses the podman load pipe if the derivation hasn't changed. **Do not modify this caching logic in the Justfile.**