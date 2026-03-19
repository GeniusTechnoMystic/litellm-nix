#!/usr/bin/env bash

# Enable Strict Mode for robust error handling
set -euo pipefail

# ==============================================================================
# Helper Functions
# ==============================================================================
log_info() {
    echo -e "[post-create] $(date +'%Y-%m-%dT%H:%M:%S%z'): $*"
}

log_err() {
    echo -e "[ERROR] $(date +'%Y-%m-%dT%H:%M:%S%z'): $*" >&2
}

# Export functions so they are available in spawned subshells (e.g., nix develop)
export -f log_info log_err

# ==============================================================================
# Main Execution Logic
# ==============================================================================
main() {
    log_info "Initializing Nix-bootstrapped workspace..."

    # Graceful fallback if WORKSPACE_FOLDER is unbound
    cd "${WORKSPACE_FOLDER:-$PWD}"

    if [[ ! -f flake.nix ]]; then
        log_err "flake.nix not found in workspace" >&2
        exit 1
    fi

    if [[ ! -f .envrc ]]; then
        log_err ".envrc not found in workspace" >&2
        exit 1
    fi

    # Hook direnv into all major user shells (Bash, Zsh, Fish)
    log_info "Configuring direnv shell hooks..."

    # Bash -- ( /etc/bash.bashrc set in Dockerfile)
    #if ! grep -q "direnv hook bash" ~/.bashrc 2>/dev/null; then
    #    echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
    #    log_info " - Bash hook injected"
    #fi

    # Zsh
    if ! grep -q "direnv hook zsh" ~/.zshrc 2>/dev/null; then
        echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
        log_info " - Zsh hook injected"
    fi

    # Fish
    local fish_conf_dir=~/.config/fish/conf.d
    local fish_hook_file="${fish_conf_dir}/direnv.fish"
    if [[ ! -f "$fish_hook_file" ]]; then
        mkdir -p "$fish_conf_dir"
        echo 'direnv hook fish | source' > "$fish_hook_file"
        log_info " - Fish hook injected"
    fi

    # Allow direnv to evaluate the local .envrc and bootstrap Nix dependencies
    log_info "Allowing direnv configuration..."
    direnv allow . || true
    nix develop .#fullstack -c true

    log_info "✅ Devcontainer workspace initialization complete."
    log_info "Open a new terminal and direnv will load .envrc (use flake .#fullstack)."
}

# Execute main function with all arguments
main "$@"
