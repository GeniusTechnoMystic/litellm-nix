# Justfile
# Orchestrates the polyglot build pipeline for LiteLLM

set shell := ["bash", "-c"]

# Default command: List all available recipes (replaces the old 'help' awk script)
default:
    @just --list

# ==========================================
# 1. Frontend / JavaScript Layer (Bun)
# ==========================================

# Install UI dependencies and build the React Dashboard
build-ui:
    @echo "🚀 Building React Dashboard with Bun..."
    cd ui/litellm-dashboard && bun install && bun run build

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

# Synchronize the Python environment (Replaces 'pip install -e .')
sync:
    @echo "📦 Syncing Python dependencies with uv..."
    uv sync

# Generate the Prisma database client
generate-prisma:
    @echo "🗄️ Generating Prisma Client..."
    uv sync --locked --dev
    uv run python -m prisma generate --schema=./schema.prisma

# Build the Python sdist and wheel (Automatically includes injected UI and Prisma code)
build-python: inject-ui generate-prisma
    @echo "🐍 Building Python sdist and wheel..."
    uv build --all

# Run the Python test suite in parallel
test: generate-prisma
    @echo "🧪 Running tests..."
    uv run pytest -n auto .

# Run the LiteLLM server locally
run: generate-prisma
    @echo "🚦 Starting LiteLLM server..."
    uv run python -m litellm.main

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
    rm -rf result result-*
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

# Install all JavaScript dependencies across the monorepo using Bun
install-js:
    @echo "📦 Installing JS dependencies..."
    cd ui/litellm-dashboard && bun install
    cd docs/my-website && bun install
    cd litellm-js/spend-logs && bun install
    cd litellm-js/proxy && bun install
    cd tests/proxy_admin_ui_tests && bun install
    cd tests/proxy_admin_ui_tests/ui_unit_tests && bun install

# ==========================================
# 6. Container & Deployment
# ==========================================

# Build the deterministic Docker container image using Nix and load it into Docker
build-container:
    @echo "🐳 Building immutable Docker container with Nix..."
    nix build .#container
    @echo "🚢 Loading image into Docker daemon..."
    #docker load < result
    podman load < result
    @echo "✅ Container image 'litellm:latest' is ready! You can now run 'podman compose up'."

# ==========================================
# 7. Git & Repository Management
# ==========================================

# Safely fetch and rebase updates from the upstream BerriAI repository
sync-upstream:
    @echo "🔄 Fetching upstream changes..."
    git fetch upstream
    
    @echo "🔀 Merging upstream/main..."
    @# We attempt the merge, but automatically resolve the UI 'out' directory conflicts
    @# This prevents the "Modified by them / Deleted by us" manual approval loop

    # Loop: As long as Git is stuck in a rebasing state, keep popping meld!
    git merge upstream/main --no-edit || ( \
        echo "🛠️ Auto-resolving UI artifact conflicts..."; \
        git rm -rf litellm/proxy/_experimental/out > /dev/null 2>&1 || true; \
        git add . > /dev/null 2>&1; \
        git commit --no-edit || true; \
        echo "✅ Conflicts resolved automatically." \
    )

    @echo "🛡️ Purging upstream's legacy lockfiles..."
    
    just clean
    
    @echo "🔒 Regenerating native uv lockfiles..."
    uv lock
    uv sync
    
    @echo "✅ Upstream synced. Run 'just test' to verify integration."

# Clean up stale local branches that have been merged
git-clean-branches:
    @echo "🧹 Deleting merged local branches..."
    git branch --merged | egrep -v "(^\*|main|master)" | xargs git branch -d

# Check for missing or outdated dependencies between our TOML and Upstream
audit-deps:
    @uv run python scripts/audit_deps.py

