BATS := test/libs/bats-core/bin/bats

# Test files or dirs, e.g. `make test TESTS=test/add.bats`
TESTS ?= test/

# Extra bats options:
# make test ARGS="-p"                    # Color output
# make test ARGS="--filter '^add stow'"  # Filter tests by name
ARGS ?=

.PHONY: test test-bugs test-stable lint

# Run all tests, including known bugs
test:
	$(BATS) $(ARGS) $(TESTS)

# Run only the known-bug tests
test-bugs:
	$(BATS) --filter-tags known-bug $(ARGS) $(TESTS)

# Run all tests except known bugs (regression check)
test-stable:
	$(BATS) --filter-tags '!known-bug' $(ARGS) $(TESTS)

# Lint the shell scripts
lint:
	shellcheck bin/dot install.sh
