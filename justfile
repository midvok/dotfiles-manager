#==============================================================================
# justfile - Test and lint runner for dot
#==============================================================================
# Description:
# - Runs the bats test suite in test/ and lints the shell scripts.
# - Extra arguments after a recipe name are passed to bats unchanged.
# - Override the test files with 'tests=...' placed BEFORE the recipe name.
#
# Usage:
#   just --list                  # Show available recipes
#   just test                    # All tests, including known bugs
#   just test-bugs               # Only the known-bug tests
#   just test-stable             # All tests except known bugs
#   just lint                    # Run shellcheck
#
#   # Run specific bats files
#   just tests=test/add.bats test
#   just tests="test/add.bats test/remove.bats" test
#
#   # Filter by test name (regex)
#   just test --filter conflict
#   just test --filter "^add stow"
#
#   # Output format: plain TAP is the default
#   # -p, --pretty, -F pretty: Use color output formatter
#   just test -p
#
#   # Keep the sandbox dirs for inspection (bats prints the path)
#   just test --no-tempdir-cleanup
#
#==============================================================================
set positional-arguments

bats := "test/libs/bats-core/bin/bats"

# Dir with test files (*.bats)
tests := "test/"

# Run all tests, including known bugs
test *args:
    {{bats}} "$@" {{tests}}

# Run only the known-bug tests
test-bugs *args:
    {{bats}} --filter-tags known-bug "$@" {{tests}}

# Run all tests except known bugs (regression check)
test-stable *args:
    {{bats}} --filter-tags '!known-bug' "$@" {{tests}}

# Lint the shell scripts
lint:
    shellcheck bin/dot install.sh
