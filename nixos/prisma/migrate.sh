#!/usr/bin/env bash
# Strict mode: fail on error, undefined variables, and pipe failures
set -euo pipefail

export LITELLM_MIGRATION_DIR="/state/.local/share/litellm/migrations"

# --- Fix the Nix Permission Trap ---
# shutil.copy2 preserves the 444 (read-only) permissions of the Nix store.
# We must force them to be writable in our persistent volume to allow LiteLLM to boot.
if [ -d "/state/.local/share/litellm/migrations" ]; then
    echo "[INIT] Purging read-only migration cache to prevent metadata collision..."
    rm -rf /state/.local/share/litellm/migrations/*
fi

# Ensure the directory exists and is strictly writable
mkdir -p "/state/.local/share/litellm/migrations"
chmod -R 755 "/state/.local/share/litellm/migrations"

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
    
    #prisma db push or prisma migrate deploy.

    # Execute the push. The Prisma engines in your flake.nix will process this.
    prisma db push --schema "$SCHEMA_PATH" --accept-data-loss --skip-generate
    
    echo "[INIT] Database initialization successful."
else
    echo "[FATAL] Could not locate core schema.prisma inside the Python package!" >&2
    exit 1
fi
