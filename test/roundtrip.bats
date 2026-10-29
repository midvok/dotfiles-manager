#!/usr/bin/env bats
#==============================================================================
# roundtrip.bats - Full add/deploy/undeploy/remove lifecycles
#==============================================================================
# Description:
# - Each test chains several commands on one file, the way they're used in
#   real life, and checks the state after every step.
# - The end state must match what the user started with (or the latest edit).
#==============================================================================

setup() {
    load test_helper
    sandbox_setup
}

@test "roundtrip stow: add, undeploy, deploy, remove gives back the original file" {
    make_module vim
    make_home_file .vimrc "my vimrc"

    run dot add vim "$HOME/.vimrc"
    assert_success
    assert_linked vim .vimrc

    run dot undeploy vim
    assert_success
    assert_absent "$HOME/.vimrc"

    run dot deploy vim
    assert_success
    assert_linked vim .vimrc

    run dot remove vim "$HOME/.vimrc"
    assert_success
    assert_link_not_exists "$HOME/.vimrc"
    assert_content "$HOME/.vimrc" "my vimrc"
    assert_absent "$DOTFILES/vim/.vimrc"
}

@test "roundtrip rsync: add, edit, pull, undeploy, deploy keeps the latest edit" {
    make_module plasma
    use_rsync plasma
    make_home_file .config/kdeglobals "v1"

    run dot add plasma "$HOME/.config/kdeglobals"
    assert_success

    # A different size than "v1": rsync skips same-size files edited within
    # the same second, because it compares only size and mtime.
    printf "v2 edited\n" > "$HOME/.config/kdeglobals"
    run dot pull plasma
    assert_success
    assert_content "$DOTFILES/plasma/.config/kdeglobals" "v2 edited"

    run dot undeploy plasma
    assert_success
    assert_absent "$HOME/.config/kdeglobals"

    run dot deploy plasma
    assert_success
    assert_copied plasma .config/kdeglobals
    assert_content "$HOME/.config/kdeglobals" "v2 edited"
}
