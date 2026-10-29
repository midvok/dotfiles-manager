#!/usr/bin/env bats
#==============================================================================
# deploy_rsync.bats - Deploying Rsync (physical copy) modules
#==============================================================================
# Description:
# - Each test starts with a 'plasma' Rsync module (.config/kdeglobals,
#   .config/plasmarc) and an otherwise empty $HOME.
# - Deploy must copy files into $HOME and back up anything it overwrites.
#==============================================================================

setup() {
    load test_helper
    sandbox_setup
    make_module plasma .config/kdeglobals .config/plasmarc
    use_rsync plasma
}

@test "deploy rsync: copies every module file into \$HOME as a real file" {
    run dot deploy plasma
    assert_success
    assert_copied plasma .config/kdeglobals
    assert_copied plasma .config/plasmarc
}

# rsync -a preserves both. Mode 600 and a 2020 date make any difference show.
@test "deploy rsync: copies keep the repo file's mode and mtime" {
    local src="$DOTFILES/plasma/.config/kdeglobals"
    chmod 600 "$src"
    touch -d "2020-01-01" "$src"
    run dot deploy plasma
    assert_success
    assert_equal "$(stat -c '%a %Y' "$HOME/.config/kdeglobals")" \
        "$(stat -c '%a %Y' "$src")"
}

@test "deploy rsync: skips IGNORE_FILES patterns like README* and *.bak" {
    make_module plasma README.md .config/kdeglobals.bak
    run dot deploy plasma
    assert_success
    assert_absent "$HOME/README.md"
    assert_absent "$HOME/.config/kdeglobals.bak"
}

# No --delete: files that aren't in the module are never removed from $HOME.
@test "deploy rsync: leaves untracked files in \$HOME alone" {
    make_home_file .config/extra
    run dot deploy plasma
    assert_success
    assert_file_exists "$HOME/.config/extra"
}

@test "deploy rsync: overwrites a locally changed file and backs up the old one" {
    make_home_file .config/kdeglobals "local edit"
    run dot deploy plasma
    assert_success
    assert_copied plasma .config/kdeglobals
    assert_content "$(backup_of plasma .config/kdeglobals)" "local edit"
}

# cp -p copies content and mtime, so rsync's size+mtime check sees no change.
@test "deploy rsync: skips an identical file and makes no backup" {
    mkdir -p "$HOME/.config"
    cp -p "$DOTFILES/plasma/.config/kdeglobals" "$HOME/.config/"
    run dot deploy plasma
    assert_success
    run backup_of plasma .config/kdeglobals
    assert_failure
}

# Happens when a module switches from Stow to rsync. The link must become a
# real file, and rsync must not write through it into the repo.
@test "deploy rsync: replaces an old Stow symlink without writing into the repo" {
    mkdir -p "$HOME/.config"
    ln -s ../dotfiles/plasma/.config/kdeglobals "$HOME/.config/kdeglobals"
    run dot deploy plasma
    assert_success
    assert_copied plasma .config/kdeglobals
    assert_content "$DOTFILES/plasma/.config/kdeglobals" "repo:.config/kdeglobals"
}

# A real deploy would back up the local edit. A dry run must not.
@test "deploy rsync: dry run (-n) changes nothing, not even a backup" {
    make_home_file .config/kdeglobals "local edit"
    assert_dry_run deploy plasma
}

# Bug: 'plasma/' doesn't match the 'plasma' pattern, so it's stowed today.
# Tab completion adds that slash automatically.
# bats test_tags=known-bug
@test "deploy rsync: a trailing slash (plasma/) still deploys by copy" {
    run dot deploy plasma/
    assert_success
    assert_copied plasma .config/kdeglobals
}
