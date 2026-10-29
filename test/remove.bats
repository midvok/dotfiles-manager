#!/usr/bin/env bats
#==============================================================================
# remove.bats - Untracking files from Stow and Rsync modules
#==============================================================================
# Description:
# - Each test starts with two deployed modules: 'vim' via Stow (.vimrc,
#   .config/nvim/init.lua) and 'plasma' via Rsync (.config/kdeglobals).
# - Remove is the reverse of add: the file leaves the repo and stays in $HOME
#   as a real file.
#==============================================================================

setup() {
    load test_helper
    sandbox_setup
    make_module vim .vimrc .config/nvim/init.lua
    make_module plasma .config/kdeglobals
    use_rsync plasma
    dot deploy vim
    dot deploy plasma
}

#------------------------------------------------------------------------------
# STOW
#------------------------------------------------------------------------------
@test "remove stow: turns the symlink back into a real file, drops it from the repo" {
    run dot remove vim "$HOME/.vimrc"
    assert_success
    assert_link_not_exists "$HOME/.vimrc"
    assert_content "$HOME/.vimrc" "repo:.vimrc"
    assert_absent "$DOTFILES/vim/.vimrc"
}

@test "remove stow: the other module files stay linked" {
    run dot remove vim "$HOME/.vimrc"
    assert_success
    assert_linked vim .config/nvim/init.lua
}

@test "remove stow: a relative path is resolved from the current dir" {
    cd "$HOME/.config"
    run dot remove vim nvim/init.lua
    assert_success
    assert_content "$HOME/.config/nvim/init.lua" "repo:.config/nvim/init.lua"
    assert_absent "$DOTFILES/vim/.config/nvim/init.lua"
}

@test "remove stow: dry run (-n) changes nothing" {
    assert_dry_run remove vim "$HOME/.vimrc"
}

@test "remove stow: refuses a real file (not deployed by Stow)" {
    make_home_file .gvimrc
    assert_refused remove vim "$HOME/.gvimrc"
}

# ~/.zshrc belongs to the zsh module, so 'dot remove vim' must not touch it.
@test "remove stow: refuses a symlink that points into another module" {
    make_module zsh .zshrc
    dot deploy zsh
    assert_refused remove vim "$HOME/.zshrc"
}

@test "remove stow: refuses a broken symlink" {
    ln -s dotfiles/vim/.missing "$HOME/.broken"
    assert_refused remove vim "$HOME/.broken"
}

#------------------------------------------------------------------------------
# RSYNC
#------------------------------------------------------------------------------
# The local edit proves the $HOME file wasn't replaced by the repo copy.
@test "remove rsync: deletes the repo copy, keeps the \$HOME file as is" {
    printf "local edit\n" > "$HOME/.config/kdeglobals"
    run dot remove plasma "$HOME/.config/kdeglobals"
    assert_success
    assert_absent "$DOTFILES/plasma/.config/kdeglobals"
    assert_content "$HOME/.config/kdeglobals" "local edit"
}

@test "remove rsync: dry run (-n) changes nothing" {
    assert_dry_run remove plasma "$HOME/.config/kdeglobals"
}

@test "remove rsync: refuses a file the module doesn't track" {
    make_home_file .config/untracked
    assert_refused remove plasma "$HOME/.config/untracked"
}

@test "remove rsync: refuses a symlink (Rsync modules use real files)" {
    make_module plasma .config/plasmarc
    ln -s kdeglobals "$HOME/.config/plasmarc"
    assert_refused remove plasma "$HOME/.config/plasmarc"
}

#------------------------------------------------------------------------------
# REFUSED INPUT
#------------------------------------------------------------------------------
# Every case must fail and leave $HOME and the repo untouched.
#------------------------------------------------------------------------------
@test "remove: refuses a file that doesn't exist" {
    assert_refused remove vim "$HOME/.missing"
}

@test "remove: refuses a file outside \$HOME" {
    local outside="$BATS_TEST_TMPDIR/outside"
    printf "x\n" > "$outside"
    assert_refused remove plasma "$outside"
}
