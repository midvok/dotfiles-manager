#!/usr/bin/env bash
#==============================================================================
# install.sh - Installer for dot (Hybrid Dotfiles Manager)
#==============================================================================
# Description:
# - Installs, links, or removes the dot executable and its bash completion.
# - Supports local execution from a cloned repo or remote piping via curl.
#
# Usage:
# - Local:  ./install.sh [OPTIONS]
# - Remote: curl -fsSL <URL>/install.sh | bash [-s -- --remove]
#
#------------------------------------------------------------------------------
# Author: midvok
# Update: 2026-10-28
#==============================================================================

# Bash strict mode: -e (errexit) aborts immediately if any command fails
set -euo pipefail

#------------------------------------------------------------------------------
# HELP & USAGE
#------------------------------------------------------------------------------
usage() {
    cat <<EOF
Install, link, or remove 'dot' (Hybrid Dotfiles Manager).

Usage: ./install.sh [OPTIONS]

Options:
  (no option)      Install 'dot' (copies local files, or downloads via curl)
  -l, --link       Symlink files from the local repo for development
  -r, --remove     Remove 'dot' and its bash completion
  --no-completion  Skip installing the bash completion script
  -h, --help       Display this help message
EOF
}

#------------------------------------------------------------------------------
# CONSTANTS & GLOBALS
#------------------------------------------------------------------------------
# Use local repo path when run locally, or GitHub raw URL when run via curl
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    SRC_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SRC_BASE="https://raw.githubusercontent.com/midvok/dotfiles-manager/main"
fi

# Source paths
readonly SRC_BIN="$SRC_BASE/bin/dot"
readonly SRC_COMP="$SRC_BASE/completions/dot"

# Target paths
readonly BIN_DIR="$HOME/.local/bin"
readonly COMP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
readonly TARGET_BIN="$BIN_DIR/dot"
readonly TARGET_COMP="$COMP_DIR/dot"

# Globals for CLI args
INSTALL_COMP=1

#------------------------------------------------------------------------------
# HELPERS
#------------------------------------------------------------------------------
die() {
    printf "[ERROR] %s\n" "$*" >&2
    exit 1
}

warn() {
    printf "[WARNING] %s\n" "$*" >&2
}

refuse_root() {
    (( EUID != 0 )) || die "Do not run this installer as root/sudo."
}

#------------------------------------------------------------------------------
# CHECK ENVIRONMENT
#------------------------------------------------------------------------------
# Verifies runtime dependencies and checks whether $BIN_DIR is active in $PATH.
#
# - Warns if 'rsync' or 'stow' is missing.
# - Warns if $BIN_DIR is absent from $PATH or shadowed by another 'dot' binary.
#------------------------------------------------------------------------------
check_env() {
    local resolved_dot

    # 1. Verify runtime dependencies
    local cmd
    for cmd in rsync stow; do
        command -v "$cmd" >/dev/null 2>&1 || \
            warn "Dependency '$cmd' is not installed."
    done

    # 2. Verify ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "'$BIN_DIR' is not in your \$PATH."
        return
    fi

    # 3. Check if another 'dot' binary shadows ~/.local/bin/dot
    resolved_dot="$(command -v dot 2>/dev/null || true)"
    if [[ -n "$resolved_dot" && "$resolved_dot" != "$TARGET_BIN" ]]; then
        warn "'dot' resolves to '$resolved_dot' instead of '$TARGET_BIN'."
        printf "  Place '%s' before '%s' in your \$PATH.\n" \
            "$BIN_DIR" "$(dirname "$resolved_dot")"
    fi
}

#------------------------------------------------------------------------------
# INSTALL COPY
#------------------------------------------------------------------------------
# Installs 'dot' by copying local repository files or downloading via curl.
#
# - Copies $SRC_BIN and $SRC_COMP when run from a local clone.
# - Fetches $SRC_BIN and $SRC_COMP via curl when piped remotely.
#------------------------------------------------------------------------------
install_copy() {
    # 1. Create target directories
    mkdir -p "$BIN_DIR"
    if (( INSTALL_COMP )); then
        mkdir -p "$COMP_DIR"
    fi

    # 2. Copy from local clone or download from GitHub
    if [[ -f "$SRC_BIN" ]]; then
        cp -f "$SRC_BIN" "$TARGET_BIN"
        chmod +x "$TARGET_BIN"
        if (( INSTALL_COMP )); then
            cp -f "$SRC_COMP" "$TARGET_COMP"
        fi
    else
        command -v curl >/dev/null 2>&1 || \
            die "'curl' is required for remote installation."
        curl -fsSL "$SRC_BIN" -o "$TARGET_BIN"
        chmod +x "$TARGET_BIN"
        if (( INSTALL_COMP )); then
            curl -fsSL "$SRC_COMP" -o "$TARGET_COMP"
        fi
    fi

    # 3. Report status and validate environment
    printf "Installed: %s\n" "$TARGET_BIN"
    if (( INSTALL_COMP )); then
        printf "Installed: %s\n" "$TARGET_COMP"
    fi
    check_env
}

#------------------------------------------------------------------------------
# INSTALL LINK
#------------------------------------------------------------------------------
# Symlinks repository files into ~/.local for live development.
#------------------------------------------------------------------------------
install_link() {
    [[ -f "$SRC_BIN" ]] || \
        die "Option --link must be run from a local repository clone."

    # 1. Create target directories
    mkdir -p "$BIN_DIR"
    if (( INSTALL_COMP )); then
        mkdir -p "$COMP_DIR"
    fi

    # 2. Create symlinks
    ln -snf "$SRC_BIN" "$TARGET_BIN"
    printf "Linked: %s -> %s\n" "$TARGET_BIN" "$SRC_BIN"

    if (( INSTALL_COMP )); then
        ln -snf "$SRC_COMP" "$TARGET_COMP"
        printf "Linked: %s -> %s\n" "$TARGET_COMP" "$SRC_COMP"
    fi

    # 3. Validate environment
    check_env
}

#------------------------------------------------------------------------------
# UNINSTALL
#------------------------------------------------------------------------------
# Removes installed 'dot' binary and completion files (physical or symlinked).
#------------------------------------------------------------------------------
uninstall() {
    local removed=0
    local target

    for target in "$TARGET_BIN" "$TARGET_COMP"; do
        if [[ -e "$target" || -L "$target" ]]; then
            rm -f "$target"
            printf "Removed: %s\n" "$target"
            removed=1
        fi
    done

    if (( ! removed )); then
        printf "Nothing to remove ('dot' is not installed).\n"
    fi
}

#------------------------------------------------------------------------------
# ENTRY POINT
#------------------------------------------------------------------------------
main() {
    local mode="copy"

    refuse_root

    while (( $# > 0 )); do
        case "$1" in
            -l|--link)
                mode="link"; shift ;;
            -r|--remove)
                mode="remove"; shift ;;
            --no-completion)
                INSTALL_COMP=0; shift ;;
            -h|--help)
                usage; exit 0 ;;
            *)
                die "Unknown option: $1 (see --help)" ;;
        esac
    done

    case "$mode" in
        copy)   install_copy ;;
        link)   install_link ;;
        remove) uninstall ;;
    esac
}

main "$@"
