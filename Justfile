# Justfile
# Orchestrates the polyglot build pipeline for LiteLLM

set shell := ["bash", "-euo", "pipefail", "-c"]

# Default command: List all available recipes
default:
    @just --list

# ==========================================
# 1. Frontend / JavaScript Layer (Bun)
# ==========================================

# Install UI dependencies and build the React Dashboard
build-ui:
    @echo "🚀 Building React Dashboard with Bun..."
    @start_time=$(date +%s); \
    cd ui/litellm-dashboard && bun install && bun run build; \
    end_time=$(date +%s); \
    echo "⏱️  UI Build completed in $((end_time - start_time))s"

# ==========================================
# 2. The Artifact Bridge
# ==========================================

# Inject compiled UI assets into the Python package tree
inject-ui: build-ui
    @echo "🌉 Injecting UI into Python package..."
    mkdir -p litellm/proxy/_experimental/out
    rm -rf litellm/proxy/_experimental/out/*
    cp -R ui/litellm-dashboard/out/* litellm/proxy/_experimental/out/

# ==========================================
# 3. Python Layer (uv & Hatchling)
# ==========================================

# Synchronize the Python environment
sync:
    @echo "📦 Syncing Python dependencies with uv..."

    # Force creation of a local .venv even if running inside a Nix shell
    uv sync --frozen

# Generate the Prisma database client
generate-prisma:
    @echo "🗄️ Generating Prisma Client..."

    # Ensure we have a local mutable .venv
    # Run generation using the LOCAL .venv specifically to avoid Nix Store RO issues.
    # By unsetting VIRTUAL_ENV and PYTHONPATH, we sever the tie to the Nix read-only 
    # environment just for this command, forcing `uv run` to utilize the local mutable .venv
    
    @start_time=$(date +%s); \
    uv sync --locked --dev;\
    env -u VIRTUAL_ENV -u PYTHONPATH uv run python -m prisma generate --schema=./schema.prisma; \
    end_time=$(date +%s); \
    echo "⏱️  Prisma Generation completed in $((end_time - start_time))s"
    
# Build the Python sdist and wheel (Automatically includes injected UI and Prisma code)
build-python: inject-ui generate-prisma
    @echo "🐍 Building Python sdist and wheel..."
    @start_time=$(date +%s); \
    uv build --all; \
    end_time=$(date +%s); \
    echo "⏱️  Python Build completed in $((end_time - start_time))s"

# Run the Python test suite in parallel
test: generate-prisma
    @echo "🧪 Running tests..."
    uv run pytest -n auto .

# Run the LiteLLM server locally
run *ARGS: 
    @echo "🚦 Starting LiteLLM server..."
    PYTHONPATH="$PWD" uv run litellm {{ARGS}}

# ==========================================
# 4. Code Quality & DevOps
# ==========================================

# Check code formatting and linting
lint:
    @echo "🔎 Running ruff checks..."
    uv run ruff check .

# Format code automatically
format:
    @echo "✨ Formatting code with ruff..."
    uv run ruff format .

# Run static type checking
type-check:
    @echo "📏 Running mypy..."
    uv run mypy .

# Clean up all build artifacts, caches, and injected files
clean:
    @echo "🧹 Cleaning monorepo artifacts..."
    rm -rf result result-* .nix-container-cache
    rm -rf dist/ build/ *.egg-info/
    rm -rf litellm/proxy/_experimental/out
    rm -rf ui/litellm-dashboard/out ui/litellm-dashboard/node_modules ui/litellm-dashboard/.next
    rm -f poetry.lock package-lock.json ui/litellm-dashboard/package-lock.json docs/my-website/package-lock.json enterprise/poetry.lock litellm-js/spend-logs/package-lock.json litellm-proxy-extras/poetry.lock package.json requirements.txt tests/proxy_admin_ui_tests/package-lock.json tests/proxy_admin_ui_tests/ui_unit_tests/package-lock.json
    -find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
    -find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    -find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
    -find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
    -find . -type f -name ".DS_Store" -exec rm -f {} + 2>/dev/null || true

# ==========================================
# 5. The Master Build
# ==========================================

# Execute the full monorepo build pipeline (UI -> Bridge -> Python)
build-all: build-python
    @echo "✅ Monorepo build complete! Artifacts are ready in /dist."

# ==========================================
# 6. Container & Deployment
# ==========================================

# Build the deterministic Docker container image using Nix and load it into Podman via stream
build-container:
    @echo "🐳 Building immutable Docker container with Nix..."
    @start_time=$(date +%s); \
    nix build .#container ;\
    NEW_PATH=$(readlink -f result); \
    if [ -f .nix-container-cache ] && [ "$(cat .nix-container-cache)" = "$NEW_PATH" ]; then \
        echo "⏩ Container derivation unchanged ($NEW_PATH)."; \
        echo "⏭️  Skipping expensive Podman load phase."; \
    else \
        echo "⚡ Streaming raw uncompressed layers directly to Podman..."; \
        if ./result | podman load; then \
            echo "$NEW_PATH" > .nix-container-cache; \
        else \
            echo "❌ Podman load failed!"; \
            exit 1; \
        fi; \
    fi; \
    end_time=$(date +%s); \
    echo "⏱️  Container pipeline completed in $((end_time - start_time))s"
    @echo "✅ Container image 'litellm:latest' is ready! You can now run 'just deploy-local'."

# Generate a comprehensive Markdown report of container bloat
build-report:
    @echo "📝 Generating bloat report..."
    @echo "# LiteLLM Container Build Report" > build_report.md
    @echo "## 🏋️ Top 30 Heaviest Individual Packages" >> build_report.md
    @echo "*(This is the exact disk space used by the package itself)*" >> build_report.md
    @echo '```text' >> build_report.md
    @nix path-info -rs ./result | sort -k2n | tail -n 30 | numfmt --field=2 --to=iec-i --suffix=B >> build_report.md
    @echo '```' >> build_report.md
    @echo "## 🌳 Top 30 Heaviest Dependency Chains (Closure Size)" >> build_report.md
    @echo "*(This is the size of the package PLUS everything it dragged in)*" >> build_report.md
    @echo '```text' >> build_report.md
    @nix path-info -rS ./result | sort -k2n | tail -n 30 | numfmt --field=2 --to=iec-i --suffix=B >> build_report.md
    @echo '```' >> build_report.md
    @echo "## 🕸️ Full Dependency Tree" >> build_report.md
    @echo '```text' >> build_report.md
    @nix-store --query --tree ./result >> build_report.md
    @echo '```' >> build_report.md
    @echo "✅ Comprehensive report saved to build_report.md!"

# Usage: just decrypt-secrets ./path/to/specific.sops.env ./path/to/gcp.sops.json
decrypt-secrets SOPS_FILE GCP_SOPS_FILE:
    @echo "🔐 Unsealing environment secrets from {{SOPS_FILE}}..."
    @mkdir -p ./nix/container/secrets
    # Use --output-type dotenv to automatically convert YAML sources to flat key=value env format
    sops --decrypt --output-type dotenv {{SOPS_FILE}} > ./nix/container/secrets/env_secrets.txt
    @chmod 600 ./nix/container/secrets/env_secrets.txt
    @echo "🔐 Unsealing GCP Service Account from {{GCP_SOPS_FILE}}..."
    sops --decrypt {{GCP_SOPS_FILE}} > ./nix/container/secrets/gcp_service_account.json
    @chmod 600 ./nix/container/secrets/gcp_service_account.json

# Usage: just deploy-local ./path/to/specific.sops.env ./path/to/gcp.sops.json
deploy-local SOPS_FILE GCP_SOPS_FILE: (decrypt-secrets SOPS_FILE GCP_SOPS_FILE)
    @echo "🚀 Booting orchestrator..."
    cd ./nix/container && docker compose up -d

# Usage: just logs
logs:
    @echo "📋 Tailing container logs (Press Ctrl+C to exit)..."
    cd ./nix/container && docker compose logs -f

# Usage: just stop
stop:
    @echo "🛑 Stopping orchestrator..."
    cd ./nix/container && docker compose down

# ==========================================
# 7. Git & Repository Management
# ==========================================

# Strategic Sync: Merges upstream changes while protecting our Nix/uv architecture
sync-upstream:
    @echo "🔄 1. Fetching upstream changes..."
    git fetch upstream
    @echo "🔀 2. Attempting merge (Favoring 'ours' for Nix orchestration)..."
    @# We allow the merge to start but don't commit immediately to allow cleanup
    set +e; git merge upstream/main --no-edit --no-commit; set -e
    @echo "🛡️ 3. Protecting Nix Source of Truth..."
    @git checkout HEAD -- flake.nix Justfile .envrc .gitignore .mise.toml nix/ schema.prisma 2>/dev/null || true
    @echo "🧹 4. Purging upstream lockfile noise..."
    @find . -name "package-lock.json" -delete
    @find . -name "poetry.lock" -delete
    @rm -f poetry.lock requirements.txt package-lock.json
    @echo "🛠️ 5. Auto-resolving UI artifact conflicts..."
    @git rm -rf litellm/proxy/_experimental/out > /dev/null 2>&1 || true
    @git add .
    @echo "🔒 6. Regenerating deterministic lockfiles & syncing .venv..."
    @# uv lock at root handles all workspace members
    uv lock
    uv sync
    @# Recursively find and lock Bun projects
    @find . -name "package.json" -not -path "*/node_modules/*" -execdir bun install \;
    @echo "📝 7. Finalizing merge..."
    @git add .
    @if git commit -m "chore: strategic sync with upstream" 2>/dev/null; then \
        echo "✅ Sync complete!"; \
    else \
        echo "ℹ️ No new changes to commit."; \
    fi
    @echo "👀 REVIEW REQUIRED: Check these files for upstream dependency changes:"
    @echo "   - pyproject.toml"
    @echo "   - ui/litellm-dashboard/package.json"
    @echo "   - enterprise/pyproject.toml"

# Clean up stale local branches that have been merged
git-clean-branches:
    @echo "🧹 Deleting merged local branches..."
    git branch --merged | egrep -v "(^\*|main|master)" | xargs git branch -d

# Check for missing or outdated dependencies between our TOML and Upstream
audit-deps:
    @uv run python scripts/audit_deps.py

