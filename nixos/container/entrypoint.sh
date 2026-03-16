#!/usr/bin/env bash
# Strict mode: fail on error, undefined variables, and pipe failures
set -euo pipefail

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

# -- Execute / Handoff ---
echo "[INIT] Handing execution context to LiteLLM with arguments: $@"
echo "=============================================================="
exec litellm "$@"
