#!/usr/bin/env bash
# Strict mode: fail on error, undefined variables, and pipe failures
set -euo pipefail

export LITELLM_MIGRATION_DIR="/state/.local/share/litellm/migrations"

# --- Pre-Flight Banner ---
echo "======================================================="
echo "[INIT] Booting Hermetic LiteLLM AI Gateway"
echo "[INIT] ------------------------------------------------"
echo "[INIT] Bash Version : ${BASH_VERSION}"
echo "[INIT] Python Ver   : $(python --version 2>&1)"
echo "[INIT] LiteLLM Ver  : $(litellm --version 2>&1 || echo 'Unknown')"
echo "[INIT] CPU Cores    : $(nproc)"
echo "[INIT] Open Files   : $(ulimit -n)"
echo "======================================================="

# --- Environment & Path Verification ---
echo "[INIT] Executable PATH : $PATH"
echo "[INIT] Config Target   : ${CONFIG_FILE_PATH:-UNDEFINED}"
echo "[INIT] Secrets Vault   : ${ENV_VAR_FILE:-UNDEFINED}"

# --- PATH Sanity Check ---
if ! command -v litellm &> /dev/null; then
    echo "[FATAL] 'litellm' executable not found on PATH!" >&2
    exit 1
fi
echo "[INIT] Found litellm at: $(command -v litellm)"

# --- Variables Check ---
if [ -z "${ENV_VAR_FILE:-}" ]; then
    echo "[FATAL] ENV_VAR_FILE variable is not set in compose.yaml!" >&2
    exit 1
fi

# --- Secure Secrets Mount Check ---
if [ ! -f "$ENV_VAR_FILE" ]; then
    echo "[FATAL] Secret file not found at $ENV_VAR_FILE. Did Podman mount the secret vault?" >&2
    exit 1
fi

# --- Load Secrets ---
echo "[INIT] Mounting cryptographic secrets from $ENV_VAR_FILE..."
set -a
. "$ENV_VAR_FILE"
set +a
echo "[INIT] Secrets loaded successfully into environment."

# --- Fix the Nix Permission Trap ---
# shutil.copy2 preserves the 444 (read-only) permissions of the Nix store.
# We must force them to be writable in our persistent volume to allow LiteLLM to boot.
if [ -d "/state/.local/share/litellm/migrations" ]; then
    echo "[INIT] Purging read-only migration cache to prevent metadata collision..."
    rm -rf "/state/.local/share/litellm/migrations/*"
fi

# Ensure the directory exists and is strictly writable
mkdir -p "/state/.local/share/litellm/migrations"
chmod -R 777 "/state/.local/share/litellm/migrations"

# --- Database Initialization (Prisma) ---
echo "[INIT] Locating core LiteLLM Prisma Schema..."

# Deterministically locate the exact schema within the Nix Python module
SCHEMA_PATH=$(python -c "
import litellm
import os

# litellm.__file__ points to .../site-packages/litellm/__init__.py
# We get the directory, then append 'proxy/schema.prisma'
pkg_dir = os.path.dirname(litellm.__file__)
target_schema = os.path.join(pkg_dir, 'proxy', 'schema.prisma')

if os.path.exists(target_schema):
    print(target_schema)
")

if [ -n "$SCHEMA_PATH" ]; then
    echo "[INIT] Core Schema securely locked at: $SCHEMA_PATH"
    echo "[INIT] Pushing declarative state to PostgreSQL..."
    
    # Execute the push. The Prisma engines in your flake.nix will process this.
    prisma db push --schema "$SCHEMA_PATH" --accept-data-loss --skip-generate
    
    echo "[INIT] Database initialization successful."
else
    echo "[FATAL] Could not locate core schema.prisma inside the Python package!" >&2
    exit 1
fi

# -- Execute / Handoff ---
echo "[INIT] Handing execution context to LiteLLM with arguments: $@"
echo "=============================================================="
exec litellm "$@"
