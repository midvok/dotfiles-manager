#!/usr/bin/env bash
#==============================================================================
# test_helper.bash - Shared sandbox, fixtures and assertions for dot tests
#==============================================================================
# Description:
# - Test helper library sourced by Bats test suites.
# - Runs every test in a temporary sandbox to prevent touching the real $HOME
#   or dotfiles repository.
# - Saves runtime temporary files under $BATS_TEST_TMPDIR, specifically:
#     ${TMPDIR:-/tmp}/bats-run-<pid>/test/<index>/home
#   which houses the sandbox $HOME, $DOTFILES ($HOME/dotfiles), and
#   $BACKUPS ($HOME/.dotfiles-backup). Bats removes this directory after
#   each test unless invoked with --no-tempdir-cleanup.
# - Provides module fixtures, file generators, and filesystem assertions.
#
# Usage:
#   load test_helper  # In setup() of test/*.bats suites
#
#------------------------------------------------------------------------------
# Update: 2026-10-29
#==============================================================================

#------------------------------------------------------------------------------
# CONSTANTS & ENVIRONMENT
#------------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DOT_BIN="$REPO_ROOT/bin/dot"

# Bats extension libraries (bats-support, bats-assert, bats-file)
load "$REPO_ROOT/test/libs/bats-support/load"
load "$REPO_ROOT/test/libs/bats-assert/load"
load "$REPO_ROOT/test/libs/bats-file/load"

#------------------------------------------------------------------------------
# SANDBOX SETUP
#------------------------------------------------------------------------------
# Configures an isolated sandbox for a test case within Bats temporary storage.
#
# Approach:
# - Points $HOME to $BATS_TEST_TMPDIR/home to isolate tests from the real host.
# - Sets $DOTFILES to $HOME/dotfiles and $BACKUPS to $HOME/.dotfiles-backup.
# - Matches dot defaults when ~/.dotrc configuration is absent.
# - Cleansed automatically after each test by Bats unless cleanup is disabled.
#------------------------------------------------------------------------------
sandbox_setup() {
    # 1. Isolate HOME and default fallback paths inside Bats temp directory
    export HOME
    HOME="$(realpath "$BATS_TEST_TMPDIR")/home"
    export DOTFILES="$HOME/dotfiles"
    export BACKUPS="$HOME/.dotfiles-backup"

    # 2. Pre-create dotfiles repository and switch into test HOME
    mkdir -p "$DOTFILES"
    cd "$HOME" || return 1
}

#------------------------------------------------------------------------------
# FIXTURES
#------------------------------------------------------------------------------
# Execute the dot binary with the given arguments.
dot() {
    "$DOT_BIN" "$@"
}

# make_module MODULE [REL_PATH...]
# - Create files under $DOTFILES/$module
make_module() {
    local module="$1"; shift
    local rel

    # Create the module directory
    mkdir -p "$DOTFILES/$module"

    # Create each requested file within the module directory
    for rel in "$@"; do
        mkdir -p "$(dirname "$DOTFILES/$module/$rel")"
        printf "repo:%s\n" "$rel" > "$DOTFILES/$module/$rel"
    done
}

# make_home_file REL_PATH [CONTENT]
# - Create a physical file under $HOME
make_home_file() {
    mkdir -p "$(dirname "$HOME/$1")"
    printf "%s\n" "${2:-home:$1}" > "$HOME/$1"
}

# Append module patterns to .rsync_modules to route them through Rsync.
use_rsync() {
    printf "%s\n" "$@" >> "$DOTFILES/.rsync_modules";
}

# backup_of MODULE REL_PATH [CMD]
# - Resolve newest backup copy of a file
backup_of() {
    local suffix="${3:+_$3}"
    local matches=("$BACKUPS"/*_"$1$suffix"/"$2")
    [[ -e "${matches[-1]}" ]] && printf "%s\n" "${matches[-1]}"
}

#------------------------------------------------------------------------------
# SNAPSHOT TREE
#------------------------------------------------------------------------------
# Generates a state fingerprint of all entries under the sandbox $HOME.
#
# Approach:
# - Lists entry type, permissions, mtime, path, and symlink targets.
# - Computes SHA-1 hashes for all regular files to catch content modifications.
# - Comparing before/after snapshots proves no files were modified on disk.
#------------------------------------------------------------------------------
snapshot_tree() {
    find "$HOME" -mindepth 1 -printf '%y %m %T@ %P -> %l\n' | sort
    find "$HOME" -type f -exec sha1sum {} + | sort -k2
}

#------------------------------------------------------------------------------
# ASSERTIONS
#------------------------------------------------------------------------------
# assert_linked MODULE REL_PATH
# - Verify $HOME/REL symlinks to repo module file
assert_linked() {
    assert_link_exists "$HOME/$2"
    assert_equal "$(realpath "$HOME/$2")" "$(realpath "$DOTFILES/$1/$2")"
}

# assert_copied MODULE REL_PATH
# - $HOME/REL is a regular file matching repo.
assert_copied() {
    assert_link_not_exists "$HOME/$2"
    assert_file_exists "$HOME/$2"
    cmp -s "$HOME/$2" "$DOTFILES/$1/$2" || fail "Content differs: $HOME/$2"
}

# assert_content FILE EXPECTED
# - Verify file content matches expected string
assert_content() {
    assert_equal "$(cat "$1")" "$2"
}

# assert_absent PATH
# - Verify path does not exist as file, dir, or broken link
assert_absent() {
    [[ ! -e "$1" && ! -L "$1" ]] || fail "Expected no entry at: $1"
}

# assert_refused [ARG...]
# - Assert dot fails without modifying files on disk
assert_refused() {
    local before
    before=$(snapshot_tree)
    run dot "$@"
    assert_failure
    assert_equal "$(snapshot_tree)" "$before"
}

# assert_dry_run [ARG...]
# - Assert dot --dry-run succeeds with no disk changes
assert_dry_run() {
    local before
    before=$(snapshot_tree)
    run dot "$@" --dry-run
    assert_success
    assert_equal "$(snapshot_tree)" "$before"
}
