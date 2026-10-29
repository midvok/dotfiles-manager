#!/usr/bin/env bats
#==============================================================================
# deploy_stow.bats - Deploying Stow (symlink) modules
#==============================================================================
# Description:
# - Each test starts with a 'vim' Stow module (.vimrc, .config/nvim/init.lua)
#   and an otherwise empty $HOME.
# - Deploy must create one symlink per module file and never touch real files.
#==============================================================================

setup() {
    load test_helper
    sandbox_setup
    make_module vim .vimrc .config/nvim/init.lua
}

@test "deploy stow: links every module file into \$HOME" {
    run dot deploy vim
    assert_success
    assert_linked vim .vimrc
    assert_linked vim .config/nvim/init.lua
}

# --no-folding: ~/.config/nvim must be a real dir, so files that apps create
# there don't silently land in the repo.
@test "deploy stow: creates real parent dirs, not a symlinked dir" {
    run dot deploy vim
    assert_success
    assert_dir_exists "$HOME/.config/nvim"
    assert_link_not_exists "$HOME/.config/nvim"
}

@test "deploy stow: links into an existing dir and keeps the files already there" {
    make_home_file .config/nvim/lazy-lock.json
    run dot deploy vim
    assert_success
    assert_linked vim .config/nvim/init.lua
    assert_content "$HOME/.config/nvim/lazy-lock.json" \
        "home:.config/nvim/lazy-lock.json"
}

@test "deploy stow: deploying twice is safe (idempotent)" {
    dot deploy vim
    run dot deploy vim
    assert_success
    assert_linked vim .vimrc
    assert_linked vim .config/nvim/init.lua
}

# Stow never overwrites. On a conflict it aborts all links, so init.lua must
# not be linked either.
@test "deploy stow: refuses when a real file is in the way, changes nothing" {
    make_home_file .vimrc "local vimrc"
    assert_refused deploy vim
}

# A symlink pointing outside the repo isn't owned by Stow, so it's a conflict.
@test "deploy stow: refuses when a foreign symlink is in the way, changes nothing" {
    make_home_file elsewhere/vimrc
    ln -s elsewhere/vimrc "$HOME/.vimrc"
    assert_refused deploy vim
}

@test "deploy stow: dry run (-n) changes nothing" {
    assert_dry_run deploy vim
}

# Bug: Stow only applies its own ignore list, so these are linked today.
# bats test_tags=known-bug
@test "deploy stow: skips IGNORE_FILES patterns like .directory and *.bak" {
    make_module vim .directory notes.bak
    run dot deploy vim
    assert_success
    assert_absent "$HOME/.directory"
    assert_absent "$HOME/notes.bak"
}
