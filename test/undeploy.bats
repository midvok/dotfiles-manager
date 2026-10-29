#!/usr/bin/env bats
#==============================================================================
# undeploy.bats - Removing deployed Stow and Rsync modules from $HOME
#==============================================================================
# Description:
# - Each test starts with a 'vim' Stow module (.vimrc, .config/nvim/init.lua)
#   and a 'plasma' Rsync module (.config/kdeglobals, .config/plasmarc).
# - Most tests deploy a module first, then undeploy it.
# - Stow undeploy deletes symlinks; Rsync undeploy moves copies to a backup.
#==============================================================================

setup() {
    load test_helper
    sandbox_setup
    make_module vim .vimrc .config/nvim/init.lua
    make_module plasma .config/kdeglobals .config/plasmarc
    use_rsync plasma
}

#------------------------------------------------------------------------------
# STOW
#------------------------------------------------------------------------------
@test "undeploy stow: removes the module's symlinks from \$HOME" {
    dot deploy vim
    run dot undeploy vim
    assert_success
    assert_absent "$HOME/.vimrc"
    assert_absent "$HOME/.config/nvim/init.lua"
}

@test "undeploy stow: keeps the files in the repo" {
    dot deploy vim
    run dot undeploy vim
    assert_success
    assert_content "$DOTFILES/vim/.vimrc" "repo:.vimrc"
    assert_content "$DOTFILES/vim/.config/nvim/init.lua" "repo:.config/nvim/init.lua"
}

# Files an app created next to the links aren't part of the module.
@test "undeploy stow: keeps untracked files in the module's dirs" {
    dot deploy vim
    make_home_file .config/nvim/lazy-lock.json
    run dot undeploy vim
    assert_success
    assert_file_exists "$HOME/.config/nvim/lazy-lock.json"
}

# The module was never deployed. Only Stow's own symlinks may be removed.
@test "undeploy stow: leaves a real file at a module path alone" {
    make_home_file .vimrc "local vimrc"
    run dot undeploy vim
    assert_content "$HOME/.vimrc" "local vimrc"
}

@test "undeploy stow: leaves a symlink to elsewhere alone" {
    make_home_file elsewhere/vimrc
    ln -s elsewhere/vimrc "$HOME/.vimrc"
    run dot undeploy vim
    assert_link_exists "$HOME/.vimrc"
    assert_equal "$(readlink "$HOME/.vimrc")" "elsewhere/vimrc"
}

@test "undeploy stow: dry run (-n) changes nothing" {
    dot deploy vim
    assert_dry_run undeploy vim
}

#------------------------------------------------------------------------------
# RSYNC
#------------------------------------------------------------------------------
# Copies look like any user file, so they're moved to a backup, never deleted.
@test "undeploy rsync: moves the copies from \$HOME into a backup" {
    dot deploy plasma
    run dot undeploy plasma
    assert_success
    assert_absent "$HOME/.config/kdeglobals"
    assert_absent "$HOME/.config/plasmarc"
    assert_content "$(backup_of plasma .config/kdeglobals undeploy)" \
        "repo:.config/kdeglobals"
    assert_content "$(backup_of plasma .config/plasmarc undeploy)" \
        "repo:.config/plasmarc"
}

@test "undeploy rsync: local edits survive in the backup" {
    dot deploy plasma
    printf "local edit\n" > "$HOME/.config/kdeglobals"
    run dot undeploy plasma
    assert_success
    assert_content "$(backup_of plasma .config/kdeglobals undeploy)" "local edit"
}

@test "undeploy rsync: keeps the files in the repo" {
    dot deploy plasma
    run dot undeploy plasma
    assert_success
    assert_content "$DOTFILES/plasma/.config/kdeglobals" "repo:.config/kdeglobals"
}

# rsync never creates symlinks, so a symlink here isn't dot's to move.
@test "undeploy rsync: leaves a symlink at a module path alone" {
    make_home_file elsewhere/kdeglobals
    mkdir -p "$HOME/.config"
    ln -s ../elsewhere/kdeglobals "$HOME/.config/kdeglobals"
    run dot undeploy plasma
    assert_success
    assert_link_exists "$HOME/.config/kdeglobals"
}

@test "undeploy rsync: skips files already missing from \$HOME" {
    dot deploy plasma
    rm "$HOME/.config/plasmarc"
    run dot undeploy plasma
    assert_success
    assert_absent "$HOME/.config/kdeglobals"
}

@test "undeploy rsync: dry run (-n) changes nothing" {
    dot deploy plasma
    assert_dry_run undeploy plasma
}

# README.md is never deployed, so ~/README.md is the user's own file.
# Bug: undeploy moves it into the backup today.
# bats test_tags=known-bug
@test "undeploy rsync: leaves \$HOME files matching IGNORE_FILES alone" {
    make_module plasma README.md
    make_home_file README.md "my own readme"
    run dot undeploy plasma
    assert_success
    assert_content "$HOME/README.md" "my own readme"
}
