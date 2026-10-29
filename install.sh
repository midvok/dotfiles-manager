#!/usr/bin/env bash
#==============================================================================
# install.sh - Installer for dot (Hybrid Dotfiles Manager)
#==============================================================================
# Description:
# - Installs, links, or removes the 'dot' executable and its bash completion.
# - Supports local execution from a cloned repo or remote piping via curl.
#
# Usage:
# - Local:  ./install.sh [OPTIONS]
# - Remote: curl -fsSL <URL>/install.sh | bash [-s -- --remove]
#
#------------------------------------------------------------------------------
# Author: midvok
# Update: 2026-10-29
#==============================================================================

# Bash strict mode:
#   -e: exit immediately if a command exits with a non-zero status
#   -u: treat unset variables as an error and exit
#   -o pipefail: a pipeline fails if any command in it fails
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
readonly REPO_URL="https://raw.githubusercontent.com/midvok/dotfiles-manager/main"

# Detect local vs remote source:
# - Use the local source if bin/dot sits next to this install.sh script.
# - Otherwise download from the repo URL.
# - This also covers a standalone install.sh downloaded on its own.
SRC_BASE="$REPO_URL"
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/bin/dot" ]]; then
        SRC_BASE="$script_dir"
    fi
    unset script_dir
fi
readonly SRC_BASE

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

# Temp dir for downloads; global so the EXIT trap can still reach it
TMP_DIR=""

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

cleanup() {
    if [[ -n "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}

#------------------------------------------------------------------------------
# CHECK ENVIRONMENT
#------------------------------------------------------------------------------
check_env() {
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
    local resolved
    resolved="$(command -v dot 2>/dev/null || true)"
    if [[ -n "$resolved" && "$resolved" != "$TARGET_BIN" ]]; then
        warn "'dot' resolves to '$resolved' instead of '$TARGET_BIN'."
        printf "  Place '%s' before '%s' in your \$PATH.\n" \
            "$BIN_DIR" "$(dirname "$resolved")"
    fi
}

#------------------------------------------------------------------------------
# INSTALL FILE
#------------------------------------------------------------------------------
# Installs SRC into DEST with permissions MODE, creating any missing parent
# directories.
#
# - Remote sources (URLs) are downloaded into $TMP_DIR and syntax-checked with
#   'bash -n' before install, so a failed download never replaces a working
#   file.
# - 'install' unlinks an existing DEST first, so an old symlink is replaced
#   rather than followed.
#------------------------------------------------------------------------------
install_file() {
    local src="$1" dest="$2" mode="$3"

    # Download and validate remote source if given a URL
    if [[ "$src" == https://* ]]; then
        local tmp
        tmp="$(mktemp "$TMP_DIR/download.XXXXXX")"
        curl -fsSL "$src" -o "$tmp" || die "Download failed: $src"
        bash -n "$tmp" || die "Downloaded file is not valid Bash: $src"
        src="$tmp"
    fi

    # Install file with specified mode, creating parent directories as needed
    install -D -m "$mode" "$src" "$dest"
}

#------------------------------------------------------------------------------
# INSTALL AS COPY
#------------------------------------------------------------------------------
install_as_copy() {
    # 1. Remote installs need curl
    if [[ "$SRC_BIN" == https://* ]]; then
        command -v curl >/dev/null 2>&1 || \
            die "'curl' is required for remote installation."
    fi

    # 2. Install files
    install_file "$SRC_BIN" "$TARGET_BIN" 755
    printf "Installed: %s\n" "$TARGET_BIN"

    if (( INSTALL_COMP )); then
        install_file "$SRC_COMP" "$TARGET_COMP" 644
        printf "Installed: %s\n" "$TARGET_COMP"
    fi

    # 3. Validate environment
    check_env
}

#------------------------------------------------------------------------------
# INSTALL AS LINK
#------------------------------------------------------------------------------
install_as_link() {
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

    TMP_DIR="$(mktemp -d)"
    trap cleanup EXIT

    case "$mode" in
        copy)   install_as_copy ;;
        link)   install_as_link ;;
        remove) uninstall ;;
    esac
}

main "$@"
