{
  description = "LiteLLM/NixOS CI/DevOps Orchestration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    flake-utils.url = "github:numtide/flake-utils";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, uv2nix, pyproject-nix, pyproject-build-systems, fenix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        fenixPkgs = fenix.packages.${system};

        rust179Toolchain = fenixPkgs.fromToolchainName {
          name = "1.79.0";
          #sha256 = pkgs.lib.fakeHash;
          sha256 = "sha256-Ngiz76YP4HTY75GGdH2P+APE/DEIx2R/Dn+BwwOyzZU=";
        };

        rust179Platform = pkgs.makeRustPlatform {
          cargo = rust179Toolchain.toolchain;
          rustc = rust179Toolchain.toolchain;
        };
        
        prisma-engines_5_4_2 = pkgs.callPackage ./nix/prisma-engines-5_4_2.nix {
          rustPlatform = rust179Platform;
        } ;

        # Unify Node version to prevent Node 22 vs 24 double-ups
        prisma_5_4_2 = pkgs.callPackage ./nix/prisma-5_4_2.nix {
          prisma-engines = prisma-engines_5_4_2;
          nodejs = pkgs.nodejs_24; 
        };

        python = pkgs.python313;

        sitePackages = python.sitePackages;

        prismaCliCache = pkgs.runCommand "prisma-cli-cache" {} ''
          set -euo pipefail

          mkdir -p "$out/node_modules"

          # Present the Nix-packaged Prisma CLI under the exact path contract
          # that prisma-client-py v0.11.0 expects:
          #   $PRISMA_BINARY_CACHE_DIR/node_modules/prisma/build/index.js
          ln -s ${prisma_5_4_2}/lib/prisma/packages/cli "$out/node_modules/prisma"

          cat > "$out/package.json" <<'EOF'
          { "name": "prisma-cache", "private": true }
          EOF
        '';

        # --- Python Dependency Resolution ---
        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
        overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
        pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
        }).overrideScope (pkgs.lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
        ]);

        # Developer Environment (Includes Dev Dependencies)
        upstreamPythonEnv = pythonSet.mkVirtualEnv "litellm-env" {
          litellm = [ "dev" ];
        };
        # Production / Container Environment (Strictly runtime deps)
        baseEnv = pythonSet.mkVirtualEnv "litellm-base-env" {
          litellm = [ "prod" ];
        };

        # Forensic Audit Env Mappings (v0.11.0 + v5.22.0)
        prismaEnvVars = {
          # Prisma CLI cache shim: read-only, pre-seeded, no npm install needed
          PRISMA_BINARY_CACHE_DIR = "${prismaCliCache}";

          # Engine binaries from Nix
          PRISMA_QUERY_ENGINE_BINARY = "${prisma-engines_5_4_2}/bin/query-engine";
          PRISMA_QUERY_ENGINE_LIBRARY = "${prisma-engines_5_4_2}/lib/libquery_engine.node";
          PRISMA_SCHEMA_ENGINE_BINARY = "${prisma-engines_5_4_2}/bin/schema-engine";
          #PRISMA_MIGRATION_ENGINE_BINARY = "${prisma-engines_5_4_2}/bin/schema-engine";
          PRISMA_INTROSPECTION_ENGINE_BINARY = "${prisma-engines_5_4_2}/bin/schema-engine";
          PRISMA_FMT_BINARY = "${prisma-engines_5_4_2}/bin/prisma-fmt";
          
          # Runtime/Node Management
          #PRISMA_USE_GLOBAL_NODE = "true";
          #PRISMA_USE_NODEJS_BIN = "true";
          #PRISMA_BINARY_CACHE_DIR = "/tmp/prisma-cache";
          #PRISMA_HOME_DIR = "/tmp/prisma-home";
          #PRISMA_NODEENV_CACHE_DIR = "/tmp/nodeenv-cache";
          
          # Metadata/Versioning
          PRISMA_VERSION = "5.4.2";
          PRISMA_EXPECTED_ENGINE_VERSION = "ac9d7041ed77bcc8a8dbd2ab6616b39013829574";
          
          # Shielding (Preventing modern engines from crashing during generation)
          #PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING = "1";
        };

        # --- C/C++ Runtime Libraries (Required for Backend Python modules) ---
        runtimeLibs = with pkgs; [
          cacert expat krb5 glib glibc gnutls grpc libaom libgcc
          libsndfile libxml2 libxslt openssl stdenv.cc.cc.lib tzdata zlib
        ];

        # --- Deterministic Next.js Frontend Build ---
        # The Dependency Fetcher (Internet ENABLED via Fixed-Output Hash)
        frontend-deps = pkgs.stdenv.mkDerivation {
          pname = "litellm-frontend-deps";
          version = "0.1.0";
          src = pkgs.lib.cleanSource ./ui/litellm-dashboard;
          
          nativeBuildInputs = [ pkgs.bun pkgs.cacert ];
          
          # NIX SANDBOX 102: Fixed-Output Derivations (FODs)
          # By providing a hash, Nix verifies the output is deterministic and grants INTERNET ACCESS.
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          # We use a fake hash first. Nix will fail, calculate the REAL hash, and tell you what to paste here!
          outputHash = "sha256-Rm2lPUlBaoF1OXxAO512yukVvBgLHWtZh3z8t/f9oKw=";

          # 🛑 NEW: Prevent Nix from automatically injecting /nix/store paths into the downloaded scripts!
          dontFixup = true;
          
          buildPhase = ''
            export HOME=$TMPDIR
            # Download everything using the lockfile (network is unlocked here!)
            # 🛑 ADDED --ignore-scripts to prevent postinstall scripts from crashing the sandbox
            bun install --no-progress --frozen-lockfile --ignore-scripts
          '';
          
          installPhase = ''
            mkdir -p $out
            cp -r node_modules $out/
          '';
        };

        # The Offline Builder (Internet DISABLED)
        frontend-build = pkgs.stdenv.mkDerivation {
          pname = "litellm-frontend";
          version = "0.1.0";
          src = pkgs.lib.cleanSource ./ui/litellm-dashboard;
          
          # Next.js (Turbopack/SWC) needs nodejs_24 and standard C++ libraries to compile native bindings
          nativeBuildInputs = [ pkgs.bun pkgs.nodejs_24 pkgs.stdenv.cc.cc.lib ];
          
          buildPhase = ''
            export HOME=$TMPDIR
            export NEXT_TELEMETRY_DISABLED=1

            # Expose C++ libs for Next.js's pre-compiled SWC Rust compiler
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}:$LD_LIBRARY_PATH"
                        
            # Bring in the pre-downloaded dependencies from the FOD
            # We copy and add write permissions because JS bundlers notoriously try to write to node_modules/.cache
            cp -r ${frontend-deps}/node_modules ./node_modules
            chmod -R u+w ./node_modules

            # Fix hardcoded /usr/bin/env paths in node_modules binaries so they can run in the sandbox
            patchShebangs ./node_modules

            # NIX OFFLINE FIX: Mock next/font/google so it doesn't crash without internet access
            # We add (props: any) to the mock so TypeScript doesn't complain about "Expected 0 arguments, but got 1"
            echo "Mocking next/font/google..."
            find . -type f -name "*.tsx" -exec sed -i 's/import { Inter } from "next\/font\/google"/const Inter = (props: any) => ({ className: "font-sans", variable: "--font-inter", style: { fontFamily: "sans-serif" } })/g' {} +
            find . -type f -name "*.tsx" -exec sed -i "s/import { Inter } from 'next\/font\/google'/const Inter = (props: any) => ({ className: 'font-sans', variable: '--font-inter', style: { fontFamily: 'sans-serif' } })/g" {} +

            # Build the static UI entirely offline
            UI_BASE_PATH="/prod/ui" bun run build
          '';

          installPhase = ''
            mkdir -p $out

            # Copy FROM Next.js's local `out/` folder TO the permanent `$out/` Nix store path
            cp -r out/* $out/
          '';
        };

        # --- The Application Artifact (Python + Prisma + UI) ---
        litellm-app = pkgs.stdenv.mkDerivation {
          pname = "litellm-app";
          version = "1.82.6";
          src = pkgs.lib.cleanSource ./.;
          nativeBuildInputs = [ pkgs.nodejs_24 pkgs.coreutils baseEnv prisma_5_4_2 ];
          buildInputs = runtimeLibs; # Added for safe Prisma generation execution inside the sandbox
          
          # We do everything in installPhase so we have a mutable target directory
          dontBuild = true;

          # In this phase, we assemble the final Python package directly into the $out destination.
          installPhase = ''
            set -euo pipefail

            # Fake the home directory again so Prisma/Python caches don't crash the sandbox
            export HOME=$TMPDIR
            export PATH="${pkgs.nodejs_24}/bin:${prisma_5_4_2}/bin:$PATH"

            mkdir -p "$out"
            
            # 🛠️ FIX: Copy baseEnv and explicitly add write permissions. 
            # We avoid --no-preserve=mode because it strips the "executable" bits from bin/python.
            cp -rL ${baseEnv}/* "$out/"
            chmod -R u+w "$out/"
            
            # Inject Prisma environment
            ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (k: v: "export ${k}=\"${v}\"") prismaEnvVars)}

            # Generate the client INTO the new mutable site-packages
            export PYTHONPATH="$out/${sitePackages}"

            #echo "Using PRISMA_BINARY_CACHE_DIR=$PRISMA_BINARY_CACHE_DIR"
            #test -f "$PRISMA_BINARY_CACHE_DIR/node_modules/prisma/build/index.js"
            
            # Generate Prisma Python client into the mutable copied environment
            "$out/bin/python" -m prisma generate --schema=./schema.prisma
            
            # We copy the frontend build directly into the target directory
            # LiteLLM looks for index.html here.
            UI_TARGET="$out/${sitePackages}/litellm/proxy/_experimental/out"
            mkdir -p "$UI_TARGET"
            cp -r ${frontend-build}/* "$UI_TARGET/"
            chmod -R u+w "$UI_TARGET"
            
            # --- PRE-RESTRUCTURE UI FOR READ-ONLY ENV ---
            # FIX: LiteLLM attempts to "restructure" the UI at runtime by moving 'out/_next' 
            # to 'out/next'. We perform a compatible structure here to silence the RO warning.
            if [ -d "$UI_TARGET/_next" ]; then
                echo "[BUILD] Restructuring UI: moving _next to next..."
                mv "$UI_TARGET/_next" "$UI_TARGET/next"
                ln -s next "$UI_TARGET/_next"
            fi

            # Replicate upstream's extensionless route logic natively in bash
            echo "[BUILD] Restructuring UI HTML files for extensionless routes..."
            find "$UI_TARGET" -maxdepth 1 -name "*.html" -not -name "index.html" -not -name "404.html" | while read -r html_file; do
                base_name=$(basename "$html_file" .html)
                mkdir -p "$UI_TARGET/$base_name"
                mv "$html_file" "$UI_TARGET/$base_name/index.html"
            done

            # Drop the primary signal marker required by proxy_server.py
            echo "[BUILD] Dropping .litellm_ui_ready marker..."
            touch "$UI_TARGET/.litellm_ui_ready"
            # --- APPLY SURGICAL SHUTIL METADATA PATCH ---
            # Replace shutil.copy2 and shutil.copy with shutil.copyfile to prevent 
            # preserving the 0444 read-only Nix store permissions.
            # We also inject copy_function=shutil.copyfile into shutil.copytree.
            echo "[BUILD] Applying surgical sed patches to fix shutil mutability traps..."
            
            PROXY_EXTRAS_UTILS="$out/${sitePackages}/litellm_proxy_extras/utils.py"
            if [ -f "$PROXY_EXTRAS_UTILS" ]; then
                sed -i 's/shutil\.copy2(/shutil.copyfile(/g' "$PROXY_EXTRAS_UTILS"
                sed -i 's/shutil\.copy(/shutil.copyfile(/g' "$PROXY_EXTRAS_UTILS"
                sed -i 's/shutil\.copytree(/shutil.copytree(copy_function=shutil.copyfile, /g' "$PROXY_EXTRAS_UTILS"
            fi

            PROXY_SERVER="$out/${sitePackages}/litellm/proxy/proxy_server.py"
            if [ -f "$PROXY_SERVER" ]; then
                sed -i 's/shutil\.copytree(/shutil.copytree(copy_function=shutil.copyfile, /g' "$PROXY_SERVER"
            fi

            # Remove vulnerable wheel-bundled Node binaries after generation
            rm -rf "$out/${sitePackages}"/nodejs_wheel*

            # Normalize lib64 into lib before fixup runs
            if [ -d "$out/lib64" ]; then
              mkdir -p "$out/lib"
              cp -a "$out/lib64/." "$out/lib/"
              rm -rf "$out/lib64"
            fi
          '';
        };

        # =====================================================================
        # TOOLING DEFINITIONS 
        # =====================================================================
        
        # Core tools shared between Host OS Shells and the Container Admin Shell
        coreTools = with pkgs; [
          bashInteractive coreutils bat eza fd findutils htop 
          jq just less ripgrep wget yq gnugrep gnused procps gawk
          nano gnutar gzip diffutils
        ];

        # Network/Diag tools strictly for the container's admin-shell
        adminTools = with pkgs; [
          strace iana-etc curl iproute2 wget
          netcat-gnu dnsutils postgresql redis 
        ];

        # Backend compilers, SDKs, and heavy tooling (Host OS only)
        backendTools = with pkgs; [
          cargo clang cmake direnv gcc git libffi lld llvm ninja pkg-config rustc
          mise pre-commit ruff taplo uv postgresql redis nodejs_24 google-cloud-sdk strace
          nix-direnv
        ];

        # Frontend Tools (JS/TS)
        frontendTools = with pkgs; [ bun direnv git nodejs_24 pnpm mise ];

        # CI/CD & DevOps Tools
        ciTools = with pkgs; [
          circleci-cli codecov-cli codeql dependabot-cli direnv prometheus semgrep skopeo trivy wrangler
        ];

        adminEnv = pkgs.buildEnv {
          name = "admin-env";
          paths = runtimeLibs ++ coreTools ++ adminTools;
          ignoreCollisions = true; # <-- Safely resolves multi-package binary collisions
        };

        # Admin Shell Script
        admin-shell = pkgs.writeShellScriptBin "admin-shell" ''
          #!/usr/bin/env bash
          set -euo pipefail

          # Isolate the admin tools: Prepend the heavy tools ONLY to this shell session's path
          export PATH="${adminEnv}/bin:$PATH"

          echo "======================================================="
          echo "💠 LITELLM FORENSIC ADMIN SHELL ACTIVATED"
          echo "======================================================="
          echo "[DIAGNOSTICS] Available tools: psql, redis-cli, strace, jq, curl, dnsutils..."

          # Opportunistic Secret Auto-Loader (Shared logic with startup wrapper)
          if [[ -n "''${ENV_VAR_FILE:-}" ]] && [[ -f "$ENV_VAR_FILE" ]]; then
              echo "[ADMIN] 🔓 Mounting cryptographic secrets from $ENV_VAR_FILE..."
              set -a
              # shellcheck disable=SC1090
              source "$ENV_VAR_FILE"
              set +a
              echo "[ADMIN] ✅ Secrets loaded successfully."
          else
              echo "[ADMIN] ℹ️ No ENV_VAR_FILE specified. Relying on existing environment variables."
          fi

          echo "Dropping to interactive diagnostic shell..."
          exec bash -i
        '';
        # --- The Container Startup Wrapper ---
        # Replaces complex Docker entrypoint.sh by securely orchestrating migrations -> server start
        startup-wrapper = pkgs.writeShellScriptBin "start-litellm" ''
          #!/usr/bin/env bash
          # Strict mode: fail on error, undefined variables, and pipe failures
          set -euo pipefail

          # Inject the compiled UI app into the Python path early.
          # We use ''${PYTHONPATH:-} to prevent unbound variable errors in strict bash mode.
          export PYTHONPATH="${litellm-app}/${sitePackages}:''${PYTHONPATH:-}"

          # --- Pre-Flight Banner ---
          echo "======================================================="
          echo "[INIT] 🚀 Booting Hermetic LiteLLM AI Gateway"
          echo "[INIT] ------------------------------------------------"
          echo "[INIT] Bash Version : ''${BASH_VERSION}"
          echo "[INIT] Python Ver   : $(python --version 2>&1)"
          echo "[INIT] LiteLLM Ver  : $(litellm --version 2>&1 || echo 'Unknown')"
          echo "======================================================="
          
          # Added persistent directories derived from upstream Dockerfile.non_root
          mkdir -p /workspace /state /state/assets /state/logs /tmp/litellm/migrations

          # --- Opportunistic Secret Auto-Loader ---
          # Supports Podman/Docker (file mounts) OR DevContainer/Codespaces (direct env vars)
          if [[ -n "''${ENV_VAR_FILE:-}" ]]; then
              if [[ -f "$ENV_VAR_FILE" ]]; then
                  echo "[INIT] 🔓 Mounting cryptographic secrets from $ENV_VAR_FILE..."
                  set -a
                  # shellcheck disable=SC1090
                  source "$ENV_VAR_FILE"
                  set +a
                  echo "[INIT] ✅ Secrets loaded successfully."
              else
                  echo "[WARN] ⚠️ ENV_VAR_FILE is set to '$ENV_VAR_FILE', but file does not exist!" >&2
                  echo "[WARN] ⚠️ Assuming secrets are provided directly via environment variables." >&2
              fi
          else
              echo "[INIT] ℹ️ No ENV_VAR_FILE specified. Relying on existing environment variables."
          fi

          # --- Database Migrations ---
          if [[ "''${LITELLM_MIGRATE:-False}" != "False" ]] && [[ "''${LITELLM_SKIP_DB_SETUP:-True}" != "True" ]]; then
            echo "[INIT] 📦 Running Prisma Database Migrations..."
            python -m prisma migrate deploy --schema=/workspace/schema.prisma || echo "[WARN] ⚠️ Migration returned non-zero status, continuing..." >&2
          else
            echo "[INIT] ⏭️  Migrations disabled via environment variable."
          fi
          
          echo "[INIT] 🟢 Handing execution context to LiteLLM with arguments: $@"
          echo "=============================================================="
          
          exec litellm "$@"
        '';

        # --- Shared Environment Hooks ---
        sharedShellHook = ''
          export UV_PROJECT=$PWD
          export UV_LINK_MODE=copy
          export UV_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/uv"

          # 🛠️ Expose standard C/C++ libraries to pre-compiled PyPI wheels (like numpy)
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}:$LD_LIBRARY_PATH"
          
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          export CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          export NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

          export OPENSSL_CONF=${pkgs.openssl.out}/etc/ssl/openssl.cnf
          export OPENSSL_MODULES=${pkgs.openssl.out}/lib/ossl-modules

          export PYTHONUNBUFFERED=1
          export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring

          # 🛡️ Prevent Nix from clobbering the global bash history
          export HISTFILE="$PWD/.nix-bash-history"
          shopt -s histappend
          export PROMPT_COMMAND="history -a; history -n; $PROMPT_COMMAND"

          export SHELL=${pkgs.bashInteractive}/bin/bash

        '' + (pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (k: v: "export ${k}=\"${v}\"") prismaEnvVars)) + "\n";

      in {
        packages = {
          default = litellm-app;

          prisma-engines_5_4_2 = prisma-engines_5_4_2;
          prisma_5_4_2 = prisma_5_4_2;

          # Switch to streamLayeredImage to completely bypass CPU-melting gzip compression
          #container = pkgs.dockerTools.buildLayeredImage {
          container = pkgs.dockerTools.streamLayeredImage {
            name = "litellm";
            tag = "latest";
            maxLayers = 100;
            
            # Integration: Inject the app, runtime libs, startup wrapper and admin-shell to the container payload
            contents = [ litellm-app startup-wrapper admin-shell prismaCliCache pkgs.nodejs_24 prisma_5_4_2 prisma-engines_5_4_2 ] ++ runtimeLibs;

            config = {
              Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
              Cmd = [ "${startup-wrapper}/bin/start-litellm" ];
              
              Env = (pkgs.lib.mapAttrsToList (k: v: "${k}=${v}") prismaEnvVars) ++ [
                "PATH=${litellm-app}/bin:${pkgs.lib.makeBinPath [ startup-wrapper admin-shell pkgs.nodejs_24 prisma_5_4_2 prisma-engines_5_4_2 ]}:${adminEnv}/bin"
                "HOME=/state"
                "LANG=C.UTF-8"
                "LC_ALL=C.UTF-8"
                "TZ=UTC"
                
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "OPENSSL_CONF=${pkgs.openssl.out}/etc/ssl/openssl.cnf"
                "OPENSSL_MODULES=${pkgs.openssl.out}/lib/ossl-modules"

                "PYTHONUNBUFFERED=1"
                "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath runtimeLibs}"

                # --- Encoded Minimal Generic Defaults ---
                "LITELLM_HOSTNAME=0.0.0.0"
                "CONFIG_FILE_PATH=/state/.config/litellm/config.yaml"
                "XDG_CACHE_HOME=/state/.cache"
                "XDG_DATA_HOME=/state/.local/share"
                "XDG_CONFIG_HOME=/state/.config"
                "TIKTOKEN_CACHE_DIR=/tmp/tiktoken"
                "HF_HOME=/tmp/huggingface"
                "LITELLM_MIGRATION_DIR=/tmp/litellm/migrations"
                "LITELLM_SKIP_DB_SETUP=True"
                "LITELLM_MIGRATE=False"
                "UI_DB_PRIMARY=True"
                # --- Non-Root Overrides Derived from Upstream ---
                "LITELLM_NON_ROOT=True"
                "LITELLM_LOGS_DIR=/state/logs"
                "LITELLM_ASSETS_DIR=/state/assets"
              ];
              WorkingDir = "/workspace";

              SecurityOpt = [ "no-new-privileges" ];

              Volumes = {
                "/workspace" = {};
                "/state" = {};
              };

              Labels = {
                "org.opencontainers.image.source" = "local";
                "org.opencontainers.image.title" = "LiteLLM";
              };
            };
          };
        };

        # --- THE DEVELOPER SHELLS ---
        devShells = {
          # ==========================================
          # 1. The Default Shell (Bootstrapping / PMs)
          # Usage: `nix develop`
          # ==========================================
          default = pkgs.mkShell {
            packages = coreTools;
            shellHook = ''
              export SHELL=${pkgs.bashInteractive}/bin/bash
              
              echo "🚀 Welcome to LiteLLM (Core Shell)"
              echo "Run 'just --list' to see available commands."
            '';
          };

          # ==========================================
          # 2. The Backend Shell (Python & Native Ext)
          # Usage: `nix develop .#backend`
          # ==========================================
          backend = pkgs.mkShell {
            # Injects upstreamPythonEnv (pytest/ruff/etc) and the native Prisma engines!
            packages = coreTools ++ backendTools ++ runtimeLibs ++ [ upstreamPythonEnv prisma_5_4_2 prisma-engines_5_4_2 ];
            shellHook = sharedShellHook + ''
              echo "🐍 LiteLLM Backend Environment"
              echo "Python: $(python --version)"
              echo "uv: $(uv --version)"
            '';
          };

          # ==========================================
          # 3. The Frontend Shell (React/UI)
          # Usage: `nix develop .#frontend`
          # ==========================================
          frontend = pkgs.mkShell {
            packages = coreTools ++ frontendTools;
            shellHook = sharedShellHook + ''
              echo "⚛️ LiteLLM Frontend Environment"
              echo "Node: $(node --version)"
              echo "Bun: $(bun --version)"
            '';
          };

          # ==========================================
          # 4. The CI/SecOps Shell (Pipelines)
          # Usage: `nix develop .#ci`
          # ==========================================
          ci = pkgs.mkShell {
            packages = coreTools ++ ciTools;
            shellHook = sharedShellHook + ''
              echo "🛡️ LiteLLM CI & SecOps Environment"
              echo "Ready for Trivy, Semgrep, and Skopeo."
            '';
          };

          # ==========================================
          # 5. The Fullstack Shell (God Mode)
          # Usage: `nix develop .#fullstack`
          # ==========================================
          fullstack = pkgs.mkShell {
            # Inherit everything from backend, frontend, and ci
            inputsFrom = [ 
              self.devShells.${system}.backend 
              self.devShells.${system}.frontend 
              self.devShells.${system}.ci 
            ];
            shellHook = sharedShellHook + ''
              echo "🌌 LiteLLM Fullstack (God Mode)"
              echo "All toolchains loaded."
            '';
          };
        };

        apps.default = {
          type = "app";
          program = "${startup-wrapper}/bin/start-litellm";
        };
      }
    );
}
