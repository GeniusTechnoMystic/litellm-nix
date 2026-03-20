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

        prisma_5_4_2 = pkgs.callPackage ./nix/prisma-5_4_2.nix {
          prisma-engines = prisma-engines_5_4_2;
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
          src = ./ui/litellm-dashboard;
          
          nativeBuildInputs = [ pkgs.bun pkgs.cacert ];
          
          # NIX SANDBOX 102: Fixed-Output Derivations (FODs)
          # By providing a hash, Nix verifies the output is deterministic and grants INTERNET ACCESS.
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          # We use a fake hash first. Nix will fail, calculate the REAL hash, and tell you what to paste here!
          outputHash = "sha256-6Hu6mAl8WJX/DIfYOiDxCvX1fPByyt33h0fhkO4YgL4=";

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
          src = ./ui/litellm-dashboard;
          
          # Next.js (Turbopack/SWC) needs nodejs_24 and standard C++ libraries to compile native bindings
          nativeBuildInputs = [ pkgs.bun pkgs.nodejs_24 pkgs.stdenv.cc.cc.lib ];
          
          buildPhase = ''
            export HOME=$TMPDIR
            export NEXT_TELEMETRY_DISABLED=1

            # 🛡️ Expose C++ libs for Next.js's pre-compiled SWC Rust compiler
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}:$LD_LIBRARY_PATH"
                        
            # 1. Bring in the pre-downloaded dependencies from the FOD
            # We copy and add write permissions because JS bundlers notoriously try to write to node_modules/.cache
            cp -r ${frontend-deps}/node_modules ./node_modules
            chmod -R u+w ./node_modules

            # 🛠️ Fix hardcoded /usr/bin/env paths in node_modules binaries so they can run in the sandbox
            patchShebangs ./node_modules

            # 🛑 NIX OFFLINE FIX: Mock next/font/google so it doesn't crash without internet access
            # We add (props: any) to the mock so TypeScript doesn't complain about "Expected 0 arguments, but got 1"
            echo "Mocking next/font/google..."
            find . -type f -name "*.tsx" -exec sed -i 's/import { Inter } from "next\/font\/google"/const Inter = (props: any) => ({ className: "font-sans", variable: "--font-inter", style: { fontFamily: "sans-serif" } })/g' {} +
            find . -type f -name "*.tsx" -exec sed -i "s/import { Inter } from 'next\/font\/google'/const Inter = (props: any) => ({ className: 'font-sans', variable: '--font-inter', style: { fontFamily: 'sans-serif' } })/g" {} +

            # 2. Build the static UI entirely offline
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
          version = "1.82.3-stable";
          src = ./.;
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

            echo "Using PRISMA_BINARY_CACHE_DIR=$PRISMA_BINARY_CACHE_DIR"
            test -f "$PRISMA_BINARY_CACHE_DIR/node_modules/prisma/build/index.js"
            
            # Generate Prisma Python client into the mutable copied environment
            "$out/bin/python" -m prisma generate --schema=./schema.prisma
            
            # Link the built UI directly into the python proxy tree
            mkdir -p "$out/${sitePackages}/litellm/proxy/_experimental/out"
            cp -r ${frontend-build}/* "$out/${sitePackages}/litellm/proxy/_experimental/out/"

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

        # --- The Container Startup Wrapper ---
        # Replaces complex Docker entrypoint.sh by securely orchestrating migrations -> server start
        startup-wrapper = pkgs.writeShellScriptBin "start-litellm" ''
          set -e
          echo "🚀 Starting LiteLLM Enterprise (Nix Native)..."
          
          if [ "$LITELLM_MIGRATE" != "False" ] && [ "$LITELLM_SKIP_DB_SETUP" != "True" ]; then
            echo "📦 Running Prisma Database Migrations..."
            # Execute migrations using the baked-in schema
            python -m prisma migrate deploy --schema=/workspace/schema.prisma || echo "⚠️ Migration warned/failed, continuing..."
          else
            echo "⏭️ Migrations disabled via environment variable."
          fi
          
          echo "🟢 Handing over to LiteLLM Server..."
          exec python -m litellm "$@"
        '';

        # --- Toolchain Categories for Shells ---

        # Core Tools (Every shell gets these)
        coreTools = with pkgs; [
          bashInteractive coreutils bat direnv nix-direnv eza fd findutils git htop 
          jq just less ripgrep wget yq gnugrep gnused procps ripgrep gawk
          less nano gnutar gzip diffutils
        ];

        # Backend Tools (Python/Rust/DBs)
        backendTools = with pkgs; [
          cargo clang cmake gcc libffi lld llvm ninja pkg-config rustc # Native compilation
          mise pre-commit ruff taplo uv # Python eco
          postgresql redis # Local DB clients for testing
          nodejs_24 # REQUIRED FOR PRISMA GENERATE
          google-cloud-sdk
          strace
        ];

        # Frontend Tools (JS/TS)
        frontendTools = with pkgs; [
          bun nodejs_24 pnpm mise
        ];

        # CI/CD & DevOps Tools
        ciTools = with pkgs; [
          circleci-cli codecov-cli codeql dependabot-cli
          prometheus semgrep skopeo trivy wrangler
        ];

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
        '' + (pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (k: v: "export ${k}=\"${v}\"") prismaEnvVars));

      in {
        packages = {
          default = litellm-app;

          prisma-engines_5_4_2 = prisma-engines_5_4_2;
          prisma_5_4_2 = prisma_5_4_2;

          container = pkgs.dockerTools.buildLayeredImage {
            name = "litellm";
            tag = "latest";
            maxLayers = 100;
            
            # Inject the app, runtime libs, coreutils, and our startup wrapper
            contents = 
              [ litellm-app startup-wrapper prismaCliCache pkgs.nodejs_24 prisma_5_4_2 prisma-engines_5_4_2 ]
              ++ runtimeLibs
              ++ [ pkgs.coreutils pkgs.bash ];

            config = {
              Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
              Cmd = [ "${startup-wrapper}/bin/start-litellm" ];
              
              Env = (pkgs.lib.mapAttrsToList (k: v: "${k}=${v}") prismaEnvVars) ++ [
                "PATH=${litellm-app}/bin:${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.bash startup-wrapper pkgs.nodejs_24 prisma_5_4_2 prisma-engines_5_4_2 ]}"
                "LANG=C.UTF-8"
                "LC_ALL=C.UTF-8"
                "TZ=UTC"
                
                "HOME=/state"
                "XDG_CONFIG_HOME=/state/.config"
                "XDG_CACHE_HOME=/state/.cache"
                "XDG_DATA_HOME=/state/.local/share"

                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "OPENSSL_CONF=${pkgs.openssl.out}/etc/ssl/openssl.cnf"
                "OPENSSL_MODULES=${pkgs.openssl.out}/lib/ossl-modules"

                "PYTHONUNBUFFERED=1"

              ];
              WorkingDir = "/workspace";

              SecurityOpt = [ "no-new-privileges" ];

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
            packages = coreTools ++ backendTools ++ runtimeLibs ++ [ upstreamPythonEnv prisma-engines_5_4_2 ];
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
