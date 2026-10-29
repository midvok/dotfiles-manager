#!/usr/bin/env bats
#==============================================================================
# add.bats - Tracking new $HOME files in Stow and Rsync modules
#==============================================================================
# Description:
# - Each test starts with an empty 'vim' Stow module and an empty 'plasma'
#   Rsync module.
# - Stow add moves the file into the repo and symlinks it back.
# - Rsync add copies the file into the repo and leaves $HOME as it is.
#==============================================================================

setup() {
    load test_helper
    sandbox_setup
    make_module vim
    make_module plasma
    use_rsync plasma
}

#------------------------------------------------------------------------------
# STOW
#------------------------------------------------------------------------------
@test "add stow: moves the file into the repo and symlinks it back" {
    make_home_file .vimrc "my vimrc"
    run dot add vim "$HOME/.vimrc"
    assert_success
    assert_content "$DOTFILES/vim/.vimrc" "my vimrc"
    assert_linked vim .vimrc
}

@test "add stow: a nested file gets real parent dirs in \$HOME" {
    make_home_file .config/nvim/init.lua
    run dot add vim "$HOME/.config/nvim/init.lua"
    assert_success
    assert_linked vim .config/nvim/init.lua
    assert_link_not_exists "$HOME/.config/nvim"
}

# Same as typing 'dot add vim nvim/init.lua' while inside ~/.config.
@test "add stow: a relative path is resolved from the current dir" {
    make_home_file .config/nvim/init.lua
    cd "$HOME/.config"
    run dot add vim nvim/init.lua
    assert_success
    assert_linked vim .config/nvim/init.lua
}

@test "add stow: dry run (-n) changes nothing" {
    make_home_file .vimrc
    assert_dry_run add vim "$HOME/.vimrc"
}

# ~/.gvimrc blocks re-stowing vim, so adding .vimrc can't finish.
# Bug: today .vimrc is moved into the repo first and left unlinked.
# bats test_tags=known-bug
@test "add stow: refuses when another module file has a conflict, changes nothing" {
    make_module vim .gvimrc
    make_home_file .gvimrc "local gvimrc"
    make_home_file .vimrc "my vimrc"
    assert_refused add vim "$HOME/.vimrc"
}

#------------------------------------------------------------------------------
# RSYNC
#------------------------------------------------------------------------------
@test "add rsync: copies the file into the repo, the original stays in \$HOME" {
    make_home_file .config/kdeglobals "my settings"
    run dot add plasma "$HOME/.config/kdeglobals"
    assert_success
    assert_copied plasma .config/kdeglobals
    assert_content "$HOME/.config/kdeglobals" "my settings"
}

@test "add rsync: the repo copy keeps the file's mode" {
    make_home_file .config/kdeglobals
    chmod 640 "$HOME/.config/kdeglobals"
    run dot add plasma "$HOME/.config/kdeglobals"
    assert_success
    assert_equal "$(stat -c '%a' "$DOTFILES/plasma/.config/kdeglobals")" "640"
}

@test "add rsync: dry run (-n) changes nothing" {
    make_home_file .config/kdeglobals
    assert_dry_run add plasma "$HOME/.config/kdeglobals"
}

#------------------------------------------------------------------------------
# REFUSED INPUT
#------------------------------------------------------------------------------
# Every case must fail and leave $HOME and the repo untouched.
#------------------------------------------------------------------------------
@test "add: refuses a symlink (nothing to track)" {
    make_home_file real
    ln -s real "$HOME/.vimrc"
    assert_refused add vim "$HOME/.vimrc"
}

@test "add: refuses a file that doesn't exist" {
    assert_refused add vim "$HOME/.missing"
}

@test "add: refuses a directory" {
    mkdir -p "$HOME/.config/nvim"
    assert_refused add vim "$HOME/.config/nvim"
}

# BATS_TEST_TMPDIR is the parent of the sandbox $HOME, so it's outside it.
@test "add: refuses a file outside \$HOME" {
    local outside="$BATS_TEST_TMPDIR/outside"
    printf "x\n" > "$outside"
    assert_refused add vim "$outside"
    assert_file_exists "$outside"
}

@test "add: refuses a file that is already inside the repo" {
    make_module vim .vimrc
    assert_refused add vim "$DOTFILES/vim/.vimrc"
}

@test "add: refuses a file the module already tracks" {
    make_module vim .vimrc
    make_home_file .vimrc
    assert_refused add vim "$HOME/.vimrc"
}

@test "add: refuses a module that doesn't exist" {
    make_home_file .vimrc
    assert_refused add nope "$HOME/.vimrc"
}
