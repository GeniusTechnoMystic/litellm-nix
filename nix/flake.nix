{
  description = "LiteLLM Container";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # The Legacy Anchor for Prisma v5
    nixpkgs-prisma5.url = "github:nixos/nixpkgs/nixos-24.11";

    flake-utils.url = "github:numtide/flake-utils";

    # The uv2nix ecosystem requires these 3 interlocking modules
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

  outputs = { self, nixpkgs, nixpkgs-prisma5, flake-utils, uv2nix, pyproject-nix, pyproject-build-systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Instantiate the v5 package set
        pkgs-prisma5 = import nixpkgs-prisma5 { inherit system; config.allowUnfree = true; };

        # Matching the ">=3.13" from your pyproject.toml
        python = pkgs.python313; 

        # 1. Load the uv workspace
        workspace = uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = ./.;
        };

        # 2. Generate a Nix overlay from the locked uv dependencies
        # Requesting wheels explicitly bypasses complex source-build environments!
        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel"; 
        };

        # 3. Construct the Python package set by combining pyproject-nix with our uv overlay
        pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
        }).overrideScope (pkgs.lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
        ]);

        # 4. Generate the fully isolated virtual environment based on your `dependencies` list
        customPythonEnv = pythonSet.mkVirtualEnv "litellm-env" workspace.deps.default;
       
        # --- RUNTIME CORE ---
        # The absolute minimum for entrypoint.sh and standard container ops
        runtimeTools = with pkgs; [
          tini
          bash              # Required for entrypoint.sh
          coreutils         # Required for 'ls', 'echo', 'mkdir' in scripts
          cacert            # Required for TLS/SSL 
          tzdata            # Required for timezone handling
          nodejs
          openssl

          libaom libgcc glibc expat glib gnutls krb5 libsndfile libxml2 libxslt

          # Use the targeted v5 engine
          pkgs-prisma5.prisma-engines
        ];

        debugShellLauncher = pkgs.writeShellScriptBin "admin-shell" ''
          export PATH=/debug-environment/bin:$PATH
          echo "======================================================="
          echo "💠 ADMIN SHELL ACTIVATED"
          echo "======================================================="

          # Synchronize Cryptographic State
          # We check if the compose.yaml passed the secret file path, and if it exists
          if [ -n "''${ENV_VAR_FILE:-}" ] && [ -f "''${ENV_VAR_FILE}" ]; then
              echo "Synchronizing cryptographic secrets from ''${ENV_VAR_FILE}..."
              set -a
              . "''${ENV_VAR_FILE}"
              set +a
              echo "Secrets successfully loaded into administrative context."
          else
              echo "[WARNING] ENV_VAR_FILE not set or secret vault missing. Proceeding without injected secrets."
          fi

          exec bash
        '';

        # --- THE DEVSHELL (DEBUG LAYER) ---
        # Tools that exist in the image but are NOT in the default PATH
        debugTools = with pkgs; [
          # --- OS/SHELL BASE ---
          bashInteractive coreutils tzdata bash gnugrep gnused findutils procps
          ripgrep gawk less nano fd htop git tini bat eza strace just
          gnutar gzip
          jq yq uv diffutils
          
          # --- NETWORKING ---
          iana-etc curl iproute2 wget netcat-gnu dnsutils

          #redis

          google-cloud-sdk

          debugShellLauncher
        ];

        # We bind the debug tools into a single cohesive derivation
        debugEnv = pkgs.buildEnv {
          name = "debug-env";
          paths = debugTools;
        };

      in {
        packages.container = pkgs.dockerTools.buildLayeredImage {
          name = "litellm";
          tag = "latest";

          # Max layers = Max caching.
          # Nix will automatically split every package into its own layer.
          maxLayers = 100;

          contents = [ customPythonEnv ] ++ runtimeTools;

          extraCommands = ''
            ln -s ${pkgs.tzdata}/share/zoneinfo/UTC ./etc-localtime

            # Create the hermetic debug vault
            mkdir -p ./debug-environment
            ln -s ${debugEnv}/bin ./debug-environment/bin
          '';

          config = {
            # Inject Tini as the master process
            Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
            Cmd = [ "${customPythonEnv}/bin/python" "-m" "litellm" "--config" "/state/.config/litellm/config.yaml" ];
            
            Env = [
              # Path Expansion
              # Restrict PATH to ONLY the runtime tools and python
              "PATH=${customPythonEnv}/bin:${pkgs.lib.makeBinPath runtimeTools}"

              "LANG=C.UTF-8"
              "LC_ALL=C.UTF-8"
              "TZ=UTC"
          
              "HOME=/state"
              "XDG_CONFIG_HOME=/state/.config"
              "XDG_CACHE_HOME=/state/.cache"
              "XDG_DATA_HOME=/state/.local/share"

              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

              "OPENSSL_CONF=${pkgs.openssl.out}/etc/ssl/openssl.cnf"
              "OPENSSL_MODULES=${pkgs.openssl.out}/lib/ossl-modules"

              "NPM_CONFIG_CACHE=/state/.cache/npm"
              "NPM_CONFIG_PREFER_OFFLINE=true"

              "PRISMA_BINARY_CACHE_DIR=/state/.cache/prisma-python/binaries"
              #"PRISMA_CLI_BINARY_TARGETS=debian-openssl-3.0.x"
              "PRISMA_CLI_QUERY_ENGINE_TYPE=binary"
              "PRISMA_CLIENT_ENGINE_TYPE=binary"
              "PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1"
              "PRISMA_FMT_BINARY=${pkgs-prisma5.prisma-engines}/bin/prisma-fmt"
              "PRISMA_HIDE_UPDATE_MESSAGE=1"
              "PRISMA_OFFLINE_MODE=true"
              "PRISMA_QUERY_ENGINE_BINARY=${pkgs-prisma5.prisma-engines}/bin/query-engine"
              "PRISMA_SCHEMA_ENGINE_BINARY=${pkgs-prisma5.prisma-engines}/bin/schema-engine"
              "PRISMA_SKIP_POSTINSTALL_GENERATE=1"
            ];

            # k8s-friendly: don’t assume root; you can override at runtime
            #User = "1000:1000";
            #User = "litellm";
            
            #users.users.litellm = {
            #  isSystemUser = true;
            #  group = "litellm";
            #};

            WorkingDir = "/workspace";
            Volumes = { "/workspace" = {}; };

            SecurityOpt = [ "no-new-privileges" ];

            Labels = {
              "org.opencontainers.image.source" = "local";
              "org.opencontainers.image.title" = "LiteLLM";
            };
          };
        };
      
      # A devShell allowing you to run `nix develop` and test the container context locally
        devShells.default = pkgs.mkShell {
          packages =
            [ customPythonEnv ]
            ++ runtimeTools
            ++ debugTools
            ++ (with pkgs; [
              git 
              gcc
              pkg-config
              libffi
              uv
              direnv
              #hatchling
              mise
              zlib
            ]);
        };
        shellHook = ''
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        '';
      }
    );
}
