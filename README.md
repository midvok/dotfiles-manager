# Dot - Hybrid Dotfiles Manager

**Dot** is a simple tool for managing user configs (dotfiles) using either **GNU Stow** or **Rsync** under the hood. Modules listed in `.rsync_modules` deploy as physical copies using **Rsync**, while all other modules default to **GNU Stow** symlinks.

1. **GNU Stow method (symlinks)**:\
   Plain, manually edited text configs are best handled with **GNU Stow** and symlinked from your repository into the `$HOME` directory.

2. **Rsync method (physical copies)**:\
   GUI applications (such as KDE Plasma) write settings via **atomic saves** (creating a temporary file and renaming it over the destination). This **_silently destroys symlinks_** upon the first UI change and breaks the Stow workflow. For these apps, **dot** synchronizes physical copies bidirectionally using **Rsync**.

### Example folder structure

By default, **dot** looks for your repository in `~/.dotfiles` (if present) or `~/dotfiles`. Custom paths can be configured in `~/.dotrc`.

Each top-level directory in the repository (excluding ignored patterns like `.*` and `_*`) represents an independent **module**. The directory structure within each module mirrors `$HOME` directly (for example, `dotfiles/MODULE/.config/file` deploys to `~/.config/file`), keeping the repository layout 100% compatible with native **GNU Stow** commands.

```
~/dotfiles/
├── __export__/           # Ignored - for exported settings and shortcuts
│   └── krusader/
│       └── krusader-custom.shortcuts
├── common-shell/         # Stow - hand-edited configs for shell
│   ├── .bash_aliases
│   ├── .bash_custom
│   ├── .bash_functions
│   ├── .inputrc
│   └── .zshrc
├── common-utils/         # Stow - hand-edited configs for extra utils
│   ├── .config/
│   │   ├── fastfetch/
│   │   │   └── config.jsonc
│   │   └── oh-my-posh/
│   └── .local/
│       └── share/
│           └── mc/
├── config-git/           # Stow - Git configuration
├── desktop-kde/          # Rsync - KDE Plasma config files
├── rsync-utils/          # Rsync - user configs that need physical copies
├── scripts/              # Stow - user scripts to be deployed everywhere
├── scripts-os-debian/    # Stow - only deployed on the Debian machine
├── scripts-os-opensuse/  # Stow - only deployed on the openSUSE machine
└── .rsync_modules        # Specify modules deployed as physical copies (Rsync)
```

## Usage

```bash
dot COMMAND [MODULE] [FILE] [OPTIONS]
```

**Options**:

- `-n`, `--dry-run`: Preview actions without modifying the filesystem.
- `-h`, `--help`: Display command-line help and usage instructions.

## Commands

#### `dot list [MODULE]`

Lists all modules and their deployment method (**Stow** or **Rsync**) or show **file tracking status** for a specific `MODULE`:

- **Stow modules**: `Ignored`, `Symlinked`, `Conflicted` (physical file exists), or `Not linked`.
- **Rsync modules**: `Ignored`, `Identical`, `Modified`, or `Not deployed`.

#### `dot deploy MODULE`

Deploys a module's configuration files to `$HOME`.

- **Stow modules**:\
  Links files individually using `stow --no-folding` to prevent untracked files from polluting the repository.

- **Rsync modules**:\
  Copies physical files to `$HOME` and **_backs up_** conflicting destination files into a timestamped directory inside `$BACKUP_DIR`.

#### `dot undeploy MODULE`

Reverses a deployment, removing the module's active files from `$HOME`.

- **Stow modules**:\
  Safely unlinks the module's symlinks from `$HOME`.

- **Rsync modules**:\
  Moves deployed files from `$HOME` to a timestamped backup directory, leaving foreign symlinks and repository sources untouched.

#### `dot pull MODULE`

Pulls live changes from `$HOME` back into the repository (**Rsync modules only**).

#### `dot add MODULE FILE`

Starts tracking a file from `$HOME` inside a module.

- **Stow modules**:\
  Moves the file into the repository and symlinks it back to `$HOME`.

- **Rsync modules**:\
  Copies the file into the repository, leaving the original physical file in `$HOME`.

- **Permissions**:\
  Warns if the file is not world-readable (e.g. `600`), as **Git** cannot preserve file permission modes beyond the executable bit.

#### `dot remove MODULE FILE`

Removes a file from dotfiles tracking and restores the local state.

- **Stow modules**:\
  Removes the symlink from `$HOME` and restores the physical file from the repository back to `$HOME`.

- **Rsync modules**:\
  Deletes the file from the repository, leaving the live copy in `$HOME` untouched.

## Configuration

**Dot** reads repository settings from `.rsync_modules` and optional environment overrides from `~/.dotrc`.

- `.rsync_modules`:

  Placed in the repository root. Defines module glob patterns (one per line, `#` for comments) deployed via **Rsync** copies instead of **GNU Stow** symlinks.

  ```text
  # Modules listed here are deployed as physical copies (Rsync).
  # Everything else defaults to symlinks (GNU Stow).
  desktop-*
  gui-*
  rsync-*
  ```

- `~/.dotrc`:

  Optional user configuration file in `$HOME` (sourced as **Bash**) to override repository paths and ignore rules. If absent, **dot** uses the built-in defaults shown below:

  ```bash
  # Path to dotfiles repository (defaults to ~/.dotfiles if present, else ~/dotfiles)
  DOTFILES_DIR="$HOME/dotfiles"

  # Destination for backups created during deploy and undeploy
  BACKUP_DIR="$HOME/.dotfiles-backup"

  # Top-level directory patterns ignored when discovering modules
  IGNORE_DIRS=(
      ".*"
      "_*"
  )

  # File patterns ignored during deployment, status checks, and syncing
  IGNORE_FILES=(
      "*~"
      ".*~"
      "*.swp"
      "*.bak"
      "*.orig"
      ".directory"
      ".DS_Store"
      ".stowrc"
      "README*"
      "LICENSE*"
  )
  ```

## Installation

### Prerequisites

**Dot** is built for **Linux** systems and requires: **Bash** (>= 4.0), **GNU Stow**, **Rsync** and **curl** (for remote installation).

### Install

You can install **dot** remotely via **curl** or locally from a cloned repository (see [Local setup](#local-setup)):

```bash
# Remote install via curl
curl -fsSL https://raw.githubusercontent.com/midvok/dotfiles-manager/main/install.sh | bash

# Local install from a cloned repo
./install.sh
```

The installer verifies dependencies and deploys files to the following target paths:

- Executable: `~/.local/bin/dot`
- Bash completion: `${XDG_DATA_HOME:-~/.local/share}/bash-completion/completions/dot`

> [!important]
>
> - Ensure `~/.local/bin` is included in your `$PATH`.
> - **_Never run the installer as root._**
> - If **Graphviz** is also installed, add `export GRAPHVIZ_DOT=/usr/bin/dot` to your shell profile to avoid collisions with the Graphviz binary.

### Uninstall

To remove **dot** and its Bash completion script:

```bash
# Remote uninstall via curl
curl -fsSL https://raw.githubusercontent.com/midvok/dotfiles-manager/main/install.sh | bash -s -- --remove

# Local uninstall from a cloned repo
./install.sh --remove
```

## Development and testing

### Local setup

Clone the repository with submodules to include the **Bats** testing framework:

```bash
git clone --recurse-submodules https://github.com/midvok/dotfiles-manager.git
cd dotfiles-manager
```

Link the development executable and Bash completion script into your user environment:

```bash
./install.sh --link
```

### Running tests and linting

The project provides a **Bats** test suite and **ShellCheck** linting, executable through **just** or **make**:

```bash
# Run all tests (including known bugs)
just test

# Format output with colors (-p, --pretty)
just test -p

# Run stable regression tests
just test-stable

# Run known-bug test cases
just test-bugs

# Lint shell scripts with ShellCheck
just lint

# Run a specific test file or filter by test name
just tests=test/add.bats test
just test --filter "^add stow"
```

The same test suite and linter can also be run using **make**:

```bash
make test
make test-stable
make test-bugs
make lint
```
