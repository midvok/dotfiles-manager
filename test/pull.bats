#!/usr/bin/env bats
#==============================================================================
# pull.bats - Pulling live $HOME changes back into Rsync modules
#==============================================================================
# Description:
# - Each test starts with a deployed 'plasma' Rsync module
#   (.config/kdeglobals, .config/plasmarc), so $HOME holds copies.
# - Pull is the reverse of deploy: it copies $HOME files into the repo, but
#   only those the module already tracks.
#==============================================================================

setup() {
    load test_helper
    sandbox_setup
    make_module plasma .config/kdeglobals .config/plasmarc
    use_rsync plasma
    dot deploy plasma
}

@test "pull: copies files edited in \$HOME back into the repo" {
    printf "local edit\n" > "$HOME/.config/kdeglobals"
    run dot pull plasma
    assert_success
    assert_content "$DOTFILES/plasma/.config/kdeglobals" "local edit"
    assert_content "$DOTFILES/plasma/.config/plasmarc" "repo:.config/plasmarc"
}

@test "pull: ignores \$HOME files that the module doesn't track" {
    make_home_file .config/untracked
    run dot pull plasma
    assert_success
    assert_absent "$DOTFILES/plasma/.config/untracked"
}

# Stow files are symlinks into the repo, so edits already land there.
@test "pull: refuses a Stow module, changes nothing" {
    make_module vim .vimrc
    dot deploy vim
    assert_refused pull vim
}

# Exit code not asserted: today rsync fails with code 23 (some files missing).
# Decide whether that should be an error or just a warning.
@test "pull: a file missing from \$HOME stays in the repo, others still pull" {
    rm "$HOME/.config/plasmarc"
    printf "local edit\n" > "$HOME/.config/kdeglobals"
    run dot pull plasma
    assert_content "$DOTFILES/plasma/.config/kdeglobals" "local edit"
    assert_content "$DOTFILES/plasma/.config/plasmarc" "repo:.config/plasmarc"
}

@test "pull: dry run (-n) changes nothing" {
    printf "local edit\n" > "$HOME/.config/kdeglobals"
    assert_dry_run pull plasma
}

# README.md is never deployed, so ~/README.md is an unrelated user file.
# Bug: pull copies it over the module's README.md today.
# bats test_tags=known-bug
@test "pull: never overwrites repo files matching IGNORE_FILES" {
    make_module plasma README.md
    make_home_file README.md "my own readme"
    run dot pull plasma
    assert_success
    assert_content "$DOTFILES/plasma/README.md" "repo:README.md"
}
