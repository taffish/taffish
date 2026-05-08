# TAFFISH Binary Distribution

[English](README.md) | [中文](README-CN.md)

TAFFISH is the local command-line part of the TAFFISH ecosystem:

- `taffish`: compile and run `.taf` programs.
- `taf`: manage TAFFISH app projects and local TAFFISH Hub packages.

This repository currently distributes prebuilt binaries only. The public release
contains the installer, shell completion files, Vim syntax files, and binary
assets for supported platforms.

## Table of Contents

- [TAFFISH Ecosystem](#taffish-ecosystem)
- [Supported Platforms](#supported-platforms)
- [Quick Install](#quick-install)
- [System Requirements](#system-requirements)
  - [macOS Dependencies](#macos-dependencies)
  - [Linux Dependencies](#linux-dependencies)
- [Install Paths](#install-paths)
- [Installer Options](#installer-options)
- [Local or Offline Install](#local-or-offline-install)
- [Container Backends](#container-backends)
  - [Docker](#docker)
  - [Podman](#podman)
  - [Apptainer](#apptainer)
- [GitHub and Publishing Dependencies](#github-and-publishing-dependencies)
- [Shell Completion](#shell-completion)
- [Vim Syntax Highlighting](#vim-syntax-highlighting)
- [Basic Usage](#basic-usage)
- [Troubleshooting](#troubleshooting)
- [Release Interface](#release-interface)
- [Project Status](#project-status)

## TAFFISH Ecosystem

TAFFISH is organized as several GitHub repositories and one static web Hub:

| Resource | Purpose |
| --- | --- |
| [taffish/taffish](https://github.com/taffish/taffish) | This repository. Binary distribution for the local `taf` and `taffish` commands. |
| [TAFFISH Hub](https://taffish.github.io) | Web registry for browsing available TAFFISH apps, tools, flows, versions, dependencies, and install commands. |
| [taffish/taffish-docs](https://github.com/taffish/taffish-docs) | Developer documentation for the TAFFISH language, app projects, Hub architecture, containers, dependencies, `taffish.toml`, and index schema. |
| [taffish/taffish-index](https://github.com/taffish/taffish-index) | Static package index consumed by `taf update`, `taf search`, `taf info`, and `taf install`. |
| [taffish/taffish.github.io](https://github.com/taffish/taffish.github.io) | Source repository for the web Hub. |
| [taffish/.github](https://github.com/taffish/.github) | Organization profile and high-level project overview. |

The current Hub design is intentionally GitHub-based: each TAFFISH app lives in
its own repository, release tags identify immutable app versions, app
repositories build their own container images, and `taffish-index` publishes the
static JSON index used by local `taf` commands.

## Supported Platforms

Current release assets:

| Platform | Asset suffix | Build backend | Notes |
| --- | --- | --- | --- |
| macOS Apple Silicon | `darwin-arm64` | SBCL | Requires Homebrew `zstd` runtime library. |
| Linux x86_64 | `linux-amd64` | LispWorks | Very small runtime dependency surface; requires glibc-based Linux. |

Not currently provided:

- macOS Intel (`darwin-amd64`)
- Linux ARM64 (`linux-arm64`)
- Windows
- Alpine/musl Linux binary assets

You can force platform selection with `--os` and `--arch`, but the selected
binary must exist in the release assets.

## Quick Install

User install, recommended for normal users:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/latest/download/install-taffish.sh | sh -s -- --user
```

System install, recommended for shared servers:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/latest/download/install-taffish.sh | sudo sh -s -- --system
```

Pinned release install:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/download/v0.1.2/install-taffish.sh | sh -s -- --version 0.1.2 --user
```

After installation, verify:

```sh
taf --version
taffish --version
taf doctor
```

If the installer says `~/.local/bin` is not in `PATH`, add this to your shell
profile:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Then open a new shell or run `source ~/.zshrc` / `source ~/.bashrc`.

## System Requirements

The installer needs standard POSIX userland tools:

```text
sh, uname, tar, mktemp, cp, chmod, mkdir, find, dirname
```

For online installation it also needs one downloader:

```text
curl or wget
```

`taf update` downloads the TAFFISH index from GitHub by default. In networks
where GitHub raw content is blocked or unstable, installation can still finish,
but `taf update` may print a warning. You can retry later:

```sh
taf update
```

or use a mirror/custom index:

```sh
taf update --url <INDEX-URL>
```

### macOS Dependencies

The current macOS binary is built with SBCL and dynamically links Homebrew's
`zstd` library:

```text
/opt/homebrew/opt/zstd/lib/libzstd.1.dylib
```

On Apple Silicon macOS, install it with:

```sh
brew install zstd
```

The current macOS asset is `darwin-arm64`, so it is intended for Apple Silicon.
Intel macOS is not covered by the current binary release.

Optional tools for project development and publishing:

```sh
brew install git gh podman zstd squashfs
```

Install only the container backend you actually plan to use.

### Linux Dependencies

The current Linux binary is built with LispWorks and is intentionally light.
It is a dynamically linked x86_64 ELF for glibc-based Linux systems.

Practical baseline:

- x86_64 Linux
- glibc-based distribution, not Alpine/musl
- GNU/Linux kernel baseline shown by the current ELF: `2.6.32`
- simple documented rule: glibc >= 2.6
- current binaries have a low GLIBC symbol requirement

On Debian/Ubuntu, the base system is normally enough for `taf` and `taffish`:

```sh
sudo apt-get update
sudo apt-get install -y curl tar git
```

For project publishing to GitHub:

```sh
sudo apt-get install -y git gh
```

For container execution, install at least one backend. See the container section
below.

## Install Paths

User install defaults:

```text
bin  = ~/.local/bin
home = ~/.local/share/taffish
```

System install defaults:

```text
bin  = /usr/local/bin
home = /opt/taffish
```

TAFFISH home stores local apps, indexes, cached images, command launchers,
completion files, Vim files, logs, and other runtime data.

Relevant environment variables:

```text
TAFFISH_USER_HOME        Override user TAFFISH home
TAFFISH_SYSTEM_HOME      Override system TAFFISH home
TAFFISH_SYSTEM_BIN_DIR   Override system command bin dir
TAFFISH_INDEX_URL        Override default index URL for taf update
```

Example custom user install:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/latest/download/install-taffish.sh \
  | sh -s -- --user --bin-dir "$HOME/bin" --taffish-home "$HOME/.taffish"
```

Example custom prefix install:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/latest/download/install-taffish.sh \
  | sh -s -- --prefix "$HOME/opt/taffish"
```

## Installer Options

```text
--user                    Install for current user [default]
--system                  Install system-wide
--prefix DIR              Set software prefix; implies bin=DIR/bin,
                          home=DIR/share/taffish unless overridden
--bin-dir DIR             Override executable install directory
--taffish-home DIR        Override TAFFISH runtime home
--repo OWNER/REPO         GitHub repository [taffish/taffish]
--version VERSION         Release version [0.1.2]
--os OS                   Override target OS (darwin|macos|linux)
--arch ARCH               Override target arch (amd64|x86_64|arm64|aarch64)
--taf-url URL             Override taf binary URL
--taffish-url URL         Override taffish binary URL
--share-url URL           Override completion/vim archive URL
--url URL                 Download full bundle tarball from explicit URL
--archive FILE            Install from local tar.gz archive
--no-update               Do not run taf update after install
--no-doctor               Do not run taf doctor --init after install
-h, --help                Show installer help
```

Manual platform override example:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/latest/download/install-taffish.sh \
  | sh -s -- --user --os linux --arch amd64
```

## Local or Offline Install

From a downloaded release bundle:

```sh
sh install/install-taffish.sh --archive ./taffish-0.1.2-target.tar.gz --user
```

From an explicit bundle URL:

```sh
sh install/install-taffish.sh --url https://example.org/taffish.tar.gz --user
```

Bundle layout:

```text
target/
  taf-<os>-<arch>-<version>
  taffish-<os>-<arch>-<version>
completion/
  bash/
  zsh/
  fish/
vim-highlight/
  syntax/
  ftdetect/
```

## Container Backends

TAFFISH app scripts can run tool commands through Docker, Podman, or Apptainer.
The `.taf` tag chooses or constrains the backend, for example:

```taf
<docker:ghcr.io/taffish/my-tool:0.1.0-r1>
  my-tool --help
```

```taf
<apptainer:ghcr.io/taffish/my-tool:0.1.0-r1>
  my-tool --help
```

```taf
<container:ghcr.io/taffish/my-tool:0.1.0-r1>
  my-tool --help
```

`<container:...>` uses TAFFISH's backend order. The default preference is:

```text
apptainer -> podman -> docker
```

You only need to install the backend you plan to use. For local development,
`taf run --backend docker` / `taf run --backend podman` can force a backend
without editing the `.taf` script.

### Docker

Docker is a good default on developer laptops and many workstations.

macOS:

```sh
brew install --cask docker
```

Debian/Ubuntu, simplified package from distro repository:

```sh
sudo apt-get update
sudo apt-get install -y docker.io
sudo usermod -aG docker "$USER"
```

Log out and log back in after changing the `docker` group.

Test:

```sh
docker run --rm hello-world
```

### Podman

Podman is useful when you prefer daemonless containers.

macOS:

```sh
brew install podman
podman machine init
podman machine start
```

Debian/Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y podman
```

Test:

```sh
podman run --rm hello-world
```

### Apptainer

Apptainer is the preferred backend for many HPC and shared Linux servers.
It avoids requiring Docker daemon access for normal users.

Debian/Ubuntu packages vary by distribution version. If available:

```sh
sudo apt-get update
sudo apt-get install -y apptainer squashfs-tools squashfuse fuse2fs gocryptfs
```

Minimum practical dependencies for Docker/OCI images:

```text
apptainer      required to run Apptainer backend
mksquashfs     provided by squashfs-tools; needed to convert Docker/OCI image
               to SIF
squashfuse     recommended; allows mounting SIF instead of converting to
               temp sandbox each run
fuse2fs        optional; removes Apptainer EXT3 filesystem warning
gocryptfs      optional; removes Apptainer encrypted filesystem warning
```

If `mksquashfs` is missing, first-time image conversion can fail with:

```text
while searching for mksquashfs: executable file not found in $PATH
```

Install:

```sh
sudo apt-get install -y squashfs-tools
```

If `squashfuse` is missing, later runs may work but Apptainer can print:

```text
INFO: squashfuse not found, will not be able to mount SIF or other squashfs files
INFO: Converting SIF file to temporary sandbox...
INFO: Cleaning up image...
```

Install:

```sh
sudo apt-get install -y squashfuse
```

TAFFISH generated scripts use `apptainer --quiet` by default in `v0.1.2` and later builds to keep normal app output clean. Runtime errors are still reported.

## GitHub and Publishing Dependencies

Normal installation and normal app execution do not require GitHub login.

These commands may need Git/GitHub tools:

```text
taf publish
taf new --docker   (creates GitHub Actions workflow files)
taf update         (downloads index unless you use a local URL)
taf install        (clones app repositories referenced by the local index)
```

Recommended developer setup:

```sh
git --version
gh auth login
```

TAFFISH does not prompt for GitHub credentials internally. Configure SSH keys,
Git credential helpers, or GitHub CLI authentication outside TAFFISH.

## Shell Completion

The installer copies completion files into:

```text
$TAFFISH_HOME/share/completions
```

For user install this is usually:

```text
~/.local/share/taffish/share/completions
```

Bash:

```sh
source ~/.local/share/taffish/share/completions/bash/taf
source ~/.local/share/taffish/share/completions/bash/taffish
```

Zsh:

```sh
fpath=(~/.local/share/taffish/share/completions/zsh $fpath)
autoload -Uz compinit
compinit
```

Fish:

```sh
mkdir -p ~/.config/fish/completions
cp ~/.local/share/taffish/share/completions/fish/taf.fish ~/.config/fish/completions/
cp ~/.local/share/taffish/share/completions/fish/taffish.fish ~/.config/fish/completions/
```

## Vim Syntax Highlighting

The installer copies Vim files into:

```text
$TAFFISH_HOME/share/vim
```

For user install:

```sh
mkdir -p ~/.vim/syntax ~/.vim/ftdetect
cp ~/.local/share/taffish/share/vim/syntax/taf.vim ~/.vim/syntax/
cp ~/.local/share/taffish/share/vim/ftdetect/taf.vim ~/.vim/ftdetect/
```

For Neovim:

```sh
mkdir -p ~/.config/nvim/syntax ~/.config/nvim/ftdetect
cp ~/.local/share/taffish/share/vim/syntax/taf.vim ~/.config/nvim/syntax/
cp ~/.local/share/taffish/share/vim/ftdetect/taf.vim ~/.config/nvim/ftdetect/
```

## Basic Usage

Update local index:

```sh
taf update
```

Search apps:

```sh
taf search blast
```

Show app information:

```sh
taf info taf-my-tool
```

Install an app or command:

```sh
taf install taf-my-tool
```

Run a versioned command:

```sh
taf-my-tool-v0.1.0-r1 --help
```

Create and run a local project:

```sh
taf new my-flow
cd my-flow
taf check
taf run
```

Build a versioned command wrapper:

```sh
taf build
./target/taf-my-flow-v0.1.0-r1
```

## Troubleshooting

### `taf: command not found`

Your install bin directory is not in `PATH`.

For user install:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### `taf update` fails with GitHub connection reset

This is usually a network/proxy problem when accessing GitHub raw content.
Retry later, set a proxy, or use a custom index URL:

```sh
taf update --url <INDEX-URL>
```

### macOS says `libzstd.1.dylib` is missing

Install Homebrew `zstd`:

```sh
brew install zstd
```

### Apptainer says `mksquashfs` is missing

Install `squashfs-tools`:

```sh
sudo apt-get install -y squashfs-tools
```

### Apptainer prints `Converting SIF file to temporary sandbox...` every run

Install `squashfuse`:

```sh
sudo apt-get install -y squashfuse
```

### Docker permission denied

Add yourself to the `docker` group and start a new login session:

```sh
sudo usermod -aG docker "$USER"
```

## Release Interface

The installer expects release assets like:

```text
https://github.com/taffish/taffish/releases/download/v<version>/install-taffish.sh
https://github.com/taffish/taffish/releases/download/v<version>/taf-<os>-<arch>-<version>
https://github.com/taffish/taffish/releases/download/v<version>/taffish-<os>-<arch>-<version>
https://github.com/taffish/taffish/archive/refs/tags/v<version>.tar.gz
```

The tag archive supplies `completion/` and `vim-highlight/` files. The binary
assets supply `taf` and `taffish`.

## Project Status

This repository is a binary distribution channel for the first public TAFFISH
local CLI release series. Source code is not published here yet.
