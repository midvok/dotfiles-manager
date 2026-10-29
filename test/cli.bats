#!/usr/bin/env bats
#==============================================================================
# cli.bats - Argument parsing, module lookup and config loading
#==============================================================================
# Description:
# - Each test starts with a 'vim' Stow module (.vimrc) and a real ~/.vimrc,
#   so valid-looking file arguments exist.
# - Refused commands must fail and leave $HOME and the repo untouched.
#==============================================================================

setup() {
    load test_helper
    sandbox_setup
    make_module vim .vimrc
    make_home_file .vimrc
}

#------------------------------------------------------------------------------
# ARGUMENTS
#------------------------------------------------------------------------------
@test "cli: deploy, undeploy and pull refuse anything but exactly one module" {
    local cmd
    for cmd in deploy undeploy pull; do
        assert_refused "$cmd"
        assert_refused "$cmd" vim extra
    done
}

@test "cli: add and remove refuse anything but exactly a module and a file" {
    local cmd
    for cmd in add remove; do
        assert_refused "$cmd" vim
        assert_refused "$cmd" vim "$HOME/.vimrc" extra
    done
}

@test "cli: refuses an unknown command" {
    assert_refused frobnicate vim
}

# Exit code 2 means a usage error; other errors exit with 1.
@test "cli: refuses an unknown option with exit code 2" {
    assert_refused deploy vim --bogus
    assert_failure 2
}

#------------------------------------------------------------------------------
# MODULE LOOKUP
#------------------------------------------------------------------------------
@test "cli: refuses a module that doesn't exist" {
    assert_refused deploy nope
}

# IGNORE_DIRS defaults to '_*' and '.*', e.g. archives and the .git dir.
@test "cli: refuses dirs excluded by IGNORE_DIRS (_archive, .git)" {
    make_module _archive .old
    make_module .git config
    assert_refused deploy _archive
    assert_refused deploy .git
}

#------------------------------------------------------------------------------
# CONFIG FILES
#------------------------------------------------------------------------------
@test "config: .rsync_modules matches globs and skips comments and blank lines" {
    make_module kde-plasma .config/kdeglobals
    printf "# GUI apps\n\nkde-*\n" > "$DOTFILES/.rsync_modules"
    run dot deploy kde-plasma
    assert_success
    assert_copied kde-plasma .config/kdeglobals
}

@test "config: a module matching no .rsync_modules pattern uses Stow" {
    make_module zsh .zshrc
    use_rsync "kde-*"
    run dot deploy zsh
    assert_success
    assert_linked zsh .zshrc
}

# The helpers read $DOTFILES, so it must point where dot looks too.
@test "config: DOTFILES_DIR in .dotrc may use ~ and a trailing slash" {
    DOTFILES="$HOME/src/dots"
    make_module zsh .zshrc
    printf 'DOTFILES_DIR="~/src/dots/"\n' > "$HOME/.dotrc"
    run dot deploy zsh
    assert_success
    assert_linked zsh .zshrc
}

@test "config: BACKUP_DIR in .dotrc sets where rsync backups go" {
    make_module plasma .config/kdeglobals
    use_rsync plasma
    make_home_file .config/kdeglobals "local edit"
    printf 'BACKUP_DIR="~/my-backups"\n' > "$HOME/.dotrc"
    BACKUPS="$HOME/my-backups"
    run dot deploy plasma
    assert_success
    assert_content "$(backup_of plasma .config/kdeglobals)" "local edit"
}

# The same module exists in both repos; the link must point into ~/.dotfiles.
@test "config: without .dotrc, ~/.dotfiles wins over ~/dotfiles" {
    make_module zsh .zshrc
    DOTFILES="$HOME/.dotfiles"
    make_module zsh .zshrc
    run dot deploy zsh
    assert_success
    assert_linked zsh .zshrc
}

@test "config: refuses to run when the dotfiles dir is missing" {
    rm -rf "$DOTFILES"
    assert_refused deploy vim
}
