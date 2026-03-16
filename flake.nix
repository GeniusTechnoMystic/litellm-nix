{
  description = "LiteLLM Enterprise Polyglot Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";

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

  outputs = { self, nixpkgs, flake-utils, uv2nix, pyproject-nix, pyproject-build-systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # --- 1. Python Foundation ---
        python = pkgs.python313;
        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
        overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
        pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
        }).overrideScope (pkgs.lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
        ]);

        upstreamPythonEnv = pythonSet.mkVirtualEnv "litellm-env" (
          workspace.deps.default // 
          (workspace.deps.dev or {})
        );

        # --- 2. C/C++ Runtime Libraries (Required for Backend Python modules) ---
        runtimeLibs = with pkgs; [
          bash cacert coreutils expat krb5 glib glibc gnutls grpc libaom libgcc
          libsndfile libxml2 libxslt openssl stdenv.cc.cc.lib tzdata zlib
        ];

        # --- 3. Toolchain Categories ---

        # Core Tools (Every shell gets these)
        coreTools = with pkgs; [
          bashInteractive bat direnv eza fd findutils git htop 
          jq just less ripgrep wget yq zlib
        ];

        # Backend Tools (Python/Rust/DBs)
        backendTools = with pkgs; [
          cargo clang cmake gcc libffi lld llvm ninja pkg-config rustc # Native compilation
          mise pre-commit ruff taplo uv # Python eco
          postgresql redis # Local DB clients for testing
          nodejs_24 # REQUIRED FOR PRISMA GENERATE
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

        # --- 4. Shared Environment Hooks ---
        sharedShellHook = ''
          export UV_PROJECT=$PWD
          export UV_LINK_MODE=copy
          export UV_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/uv"
          
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          export CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          export NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

          export OPENSSL_CONF=${pkgs.openssl.out}/etc/ssl/openssl.cnf
          export OPENSSL_MODULES=${pkgs.openssl.out}/lib/ossl-modules

          export PYTHONUNBUFFERED=1
          export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring
        '';

      in {
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
            packages = coreTools ++ backendTools ++ runtimeLibs ++ [ upstreamPythonEnv ];
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
            shellHook = ''
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
            shellHook = ''
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
      }
    );
}
