# TAFFISH

[English](README.md) | [中文](README-CN.md)

TAFFISH is a shell-native executable package framework for command-level
reproducible execution in bioinformatics.

It turns bioinformatics command-line tool invocations into versioned,
container-resolved, installable, and composable shell commands that can be used
directly in ordinary shells or embedded in existing workflow systems.

This repository provides the local command-line implementation, installers,
source-tree documentation, shell completion files, Vim syntax files, and
manually built binary release payloads for supported platforms.

The local command-line tools are:

- `taffish`: compile `.taf` programs to shell.
- `taf`: manage TAFFISH app projects and local TAFFISH Hub packages.
- `taffish-mcp`: expose safe TAFFISH tools/resources/prompts to AI clients through MCP over stdio.

The current release payload includes a SHA256 checksum manifest, a GPG-signed
checksum manifest, and the public release key. For taf-apps, the Hub trust
model is based on source commits, container digests/platform metadata, and
smoke metadata recorded in the index.

## Table of Contents

- [TAFFISH Ecosystem](#taffish-ecosystem)
- [Supported Platforms](#supported-platforms)
- [Quick Install](#quick-install)
  - [Standard Install](#standard-install)
  - [For Users in China](#for-users-in-china)
  - [Verify Installation](#verify-installation)
- [System Requirements](#system-requirements)
  - [macOS Dependencies](#macos-dependencies)
  - [Linux Dependencies](#linux-dependencies)
- [Install Paths](#install-paths)
- [Runtime Config and Mirrors](#runtime-config-and-mirrors)
- [Installer Options](#installer-options)
- [Local or Offline Install](#local-or-offline-install)
- [Build From Source](#build-from-source)
- [Container Backends](#container-backends)
  - [Docker](#docker)
  - [Podman](#podman)
  - [Apptainer](#apptainer)
- [TAF App Smoke Metadata](#taf-app-smoke-metadata)
- [GitHub and Publishing Dependencies](#github-and-publishing-dependencies)
- [Shell Completion](#shell-completion)
- [Vim Syntax Highlighting](#vim-syntax-highlighting)
- [Basic Usage](#basic-usage)
- [MCP / AI Integration](#mcp--ai-integration)
- [Troubleshooting](#troubleshooting)
- [Release Interface](#release-interface)
- [Release Verification](#release-verification)
- [Project Status](#project-status)
- [License](#license)

## TAFFISH Ecosystem

TAFFISH is organized as several GitHub repositories and one static web Hub:

| Resource | Purpose |
| --- | --- |
| [taffish/taffish](https://github.com/taffish/taffish) | This repository. Source code, installers, source-tree documentation under `docs/`, completion files, Vim files, and binary release payloads for `taf`, `taffish`, and `taffish-mcp`. |
| [TAFFISH Hub](https://taffish.github.io) | Web registry for browsing available TAFFISH apps, tools, flows, versions, dependencies, and install commands. |
| [taffish/taffish-docs](https://github.com/taffish/taffish-docs) | Public documentation repository for user guides, app-author guides, tutorials, and curated ecosystem documentation. |
| [taffish/taffish-index](https://github.com/taffish/taffish-index) | Static package index consumed by `taf update`, `taf search`, `taf info`, and `taf install`. |
| [taffish/taffish.github.io](https://github.com/taffish/taffish.github.io) | Source repository for the web Hub. |
| [taffish/.github](https://github.com/taffish/.github) | Organization profile and high-level project overview. |
| [taffish-org on Gitee](https://gitee.com/taffish-org) | China mirror organization for installation and index access when GitHub raw URLs are unstable. |

The current Hub design is intentionally GitHub-based: each TAFFISH app lives in
its own repository, release tags identify immutable app versions, app
repositories build their own container images, and `taffish-index` publishes the
static JSON index used by local `taf` commands.

Documentation is split intentionally. The `docs/` directory in this repository
stays close to the source code and records implementation notes, specifications,
architecture decisions, and release engineering details. The separate
`taffish/taffish-docs` repository is intended for broader public documentation:
quick starts, tutorials, app-author guides, and user-facing ecosystem material.

## Supported Platforms

Current binary assets:

| Platform | Asset suffix | Build backend | Notes |
| --- | --- | --- | --- |
| macOS Apple Silicon | `darwin-arm64` | SBCL | Requires Homebrew `zstd` runtime library. |
| Linux x86_64 | `linux-amd64` | LispWorks | Very small runtime dependency surface; requires glibc-based Linux. |

Not currently provided:

- macOS Intel (`darwin-amd64`)
- Linux ARM64 (`linux-arm64`)
- Windows
- Alpine/musl Linux binary assets

This list only describes official prebuilt binary assets. TAFFISH can still be
built locally from source on platforms with a working SBCL environment and the
required POSIX tools; see [Build From Source](#build-from-source).

You can force platform selection with `--os` and `--arch`, but the selected
binary must exist under `target/` for the selected version.

## Quick Install

### Standard Install

If you are in China or GitHub raw URLs are slow or blocked, use the
[China/Gitee install](#for-users-in-china) instead.

User install, recommended for normal users. It installs `taf`, `taffish`, and
`taffish-mcp` for the current user only, without administrator permission:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --user
```

System install, recommended for shared servers. It requires administrator
permission and installs the commands for all users on the machine:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sudo sh -s -- --system
```

Pinned version install. The installer may come from `main`, but downloaded
files are pinned to the selected git tag:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --version 0.9.0 --user
```

### For Users in China

GitHub raw URLs may be slow or blocked in China. The Gitee installer downloads
files from the Gitee mirror and initializes the China mirror config when no
config exists.

Note for macOS users: Gitee may require login for anonymous `raw` downloads of
large binary files. If the Gitee installer fails with
`large file require login for access`, this is a Gitee raw-file restriction, not
a TAFFISH installer error. In that case, use the GitHub installer with a working
network/proxy, or log in to Gitee and download the macOS binary manually. The
Gitee installer is mainly useful for Linux amd64 servers, whose binaries are
much smaller and are usually unaffected.

User install:

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --user
```

System install for all users on a shared machine, requiring administrator
permission:

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sudo sh -s -- --system
```

Pinned version install:

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --version 0.9.0 --user
```

To force the installer to replace an existing config with the Gitee/China
profile, add `--force-config`:

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --user --force-config
```

### Verify Installation

After installation, verify:

```sh
taf --version
taffish --version
taffish-mcp --version
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

On Debian/Ubuntu, the base system is normally enough for `taf`, `taffish`, and `taffish-mcp`:

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
TAFFISH_CONFIG           Use an explicit config.toml file
TAFFISH_INDEX_URL        Override default index URL for taf update
```

Example custom user install:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh \
  | sh -s -- --user --bin-dir "$HOME/bin" --taffish-home "$HOME/.taffish"
```

Example custom prefix install:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh \
  | sh -s -- --prefix "$HOME/opt/taffish"
```

## Runtime Config and Mirrors

Current TAFFISH is `0.9.0`. Runtime config support was introduced in `0.2.0`
to provide stable mirror/custom source settings. The default config paths are:

```text
user   = ~/.local/share/taffish/config.toml
system = /opt/taffish/config.toml
```

Inspect the effective config:

```sh
taf config
taf config path
```

Initialize the default GitHub profile:

```sh
taf config init --github
```

Initialize the China mirror profile template:

```sh
taf config init --china --force
taf update
```

The generated China template is intentionally simple:

```toml
schema_version = "taffish.config/v1"
profile = "china"
language = "en"

[index]
url = "https://gitee.com/taffish-org/taffish-index/raw/main/index/index.json"

[[source.rewrite]]
from = "https://github.com/taffish/"
to = "https://gitee.com/taffish-org/"
enabled = true
```

Meaning:

- `[index].url` controls where `taf update` downloads the static index from.
- `[[source.rewrite]]` rewrites canonical source URLs when `taf install`
  clones app repositories.
- `taf publish` remains GitHub-only; mirrors are read/install paths, not a
  publishing target.
- `taf update --url <INDEX-URL>` and `TAFFISH_INDEX_URL` still work as
  one-off overrides.

If your mirror organization or internal Git service uses different paths, edit
`config.toml` directly. The mirror must provide compatible repositories, tags,
and the same TAFFISH index schema.

## Installer Options

```text
--user                    Install for current user [default]
--system                  Install system-wide
--prefix DIR              Set software prefix; implies bin=DIR/bin,
                          home=DIR/share/taffish unless overridden
--bin-dir DIR             Override executable install directory
--taffish-home DIR        Override TAFFISH runtime home
--repo OWNER/REPO         GitHub repository [taffish/taffish]
--version VERSION         Release version [0.9.0]
--provider PROVIDER       Raw provider: github or gitee [github]
--raw-base-url URL        Override raw base URL pointing at a fixed tag
--os OS                   Override target OS (darwin|macos|linux)
--arch ARCH               Override target arch (amd64|x86_64|arm64|aarch64)
--taf-url URL             Override taf binary URL
--taffish-url URL         Override taffish binary URL
--taffish-mcp-url URL     Override taffish-mcp binary URL
--share-url URL           Override completion/vim source with tar.gz archive
--url URL                 Download full bundle tarball from explicit URL
--archive FILE            Install from local tar.gz archive
--config-profile PROFILE  Initialize config profile: github, china, or none
--force-config            Replace existing config during config init
--no-update               Do not run taf update after install
--no-doctor               Do not run taf doctor --init after install
-h, --help                Show installer help
```

Manual platform override example:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh \
  | sh -s -- --user --os linux --arch amd64
```

## Local or Offline Install

From a downloaded release bundle:

```sh
sh install/install-taffish.sh --archive ./taffish-0.9.0-target.tar.gz --user
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
  taffish-mcp-<os>-<arch>-<version>
completion/
  bash/
  zsh/
  fish/
vim-highlight/
  syntax/
  ftdetect/
```

## Build From Source

Most users should install the prebuilt binaries above. Maintainers and
contributors can build from source when they need to test the implementation,
modify TAFFISH, or produce local binaries.

See the dedicated source build guide:

- [Build From Source](docs/dev/en/build-from-source.md)

The current official binary payloads are built manually by the maintainer:
macOS Apple Silicon binaries are built with SBCL, and Linux x86_64 binaries are
built with LispWorks. `SHA256SUMS`, `SHA256SUMS.asc`, and the public release key
are kept under `target/` for manual verification.

Source builds produce unsuffixed local binaries:

```text
target/taf
target/taffish
target/taffish-mcp
```

The versioned `target/*-<os>-<arch>-<version>` files are maintainer release
payloads used by the raw installers.

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

For installed `taf-*` commands or direct `taffish` compilation, set
`TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker` to force generic
`<container:...>` tags at runtime:

```sh
TAFFISH_CONTAINER_BACKEND=podman taf-my-tool-v0.1.0-r1 [ARGS...]
TAFFISH_CONTAINER_BACKEND=podman taf-my-tool-v0.1.0-r1 --compile -- [ARGS...]
```

This does not override explicit `<docker:...>`, `<podman:...>`, or
`<apptainer:...>` tags. `taf run --backend ...` has priority over the
environment variable.

TAFFISH `0.9.0` adds two ways to pass backend-specific runtime arguments.
Use `.taf` tag arguments for app-level requirements:

```taf
<container:ghcr.io/taffish/my-gpu-tool:1.0.0-r1$@[docker: --gpus all][podman: --device nvidia.com/gpu=all][apptainer: --nv]>
  my-gpu-tool --help
```

Structured runtime args use `$@[target: args]` blocks. Supported targets are
`all`, `container` (alias of `all`), `docker`, `podman`, `apptainer`, and
backend combinations such as `docker/podman`:

```taf
<container:ghcr.io/taffish/my-tool:1.0.0-r1$@[all: --network host][docker/podman: --security-opt=label=disable]>
  my-tool --help
```

Use local environment variables for machine/runtime policy without editing the
`.taf` script:

```sh
TAFFISH_DOCKER_RUN_ARGS="--gpus all" taf-my-tool-v0.1.0-r1
TAFFISH_PODMAN_RUN_ARGS="--device nvidia.com/gpu=all" taf-my-tool-v0.1.0-r1
TAFFISH_APPTAINER_RUN_ARGS="--nv" taf-my-tool-v0.1.0-r1
```

Effective runtime-argument order is: TAFFISH defaults, project/context
configuration, tag arguments, then local environment variables. This lets app
authors declare app requirements while local users still append site-specific
policy at the end.

Legacy all-backend arguments remain supported:

```taf
<container:ghcr.io/taffish/my-tool:0.1.0-r1$--network host>
```

### Docker

Docker is a good default on developer laptops and many workstations.
Official installation docs: [Install Docker](https://docs.docker.com/en/latest/installation/)
and [Install Docker Desktop on Mac](https://docs.docker.com/desktop/setup/install/mac-install/).

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
Official installation docs: [Podman Installation](https://podman.io/docs/installation).

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
Official installation docs: [Installing Apptainer](https://apptainer.org/docs/admin/main/installation.html).

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

## TAF App Smoke Metadata

TAFFISH `0.8.0` adds declarative smoke metadata for containerized taf-apps.
This is the first local piece of the TAFFISH Hub supply-chain/trust model:
projects can state the minimal commands that an index automation should verify
before accepting a container image into the public index.

`taf new --tool --docker` now creates a `[smoke]` section in `taffish.toml`:

```toml
[smoke]
backend = "docker"
timeout = 60
exist = ["TODO"]
test = ["TODO --help"]
```

Meaning:

- `backend`: preferred smoke backend, one of `docker`, `podman`, or `apptainer`.
- `timeout`: per smoke command timeout in seconds.
- `exist`: executable names that should be discoverable in the container `PATH`.
- `test`: shell commands that should exit with status `0`.

`taf check` validates the structure and requires `[smoke]` for projects that
declare `[container].image` or `[container].dockerfile`. It also rejects the
default `TODO` placeholders, so replace them with real app-specific checks
before `taf check`, `taf publish`, or indexing. `taf check` does not run smoke
tests locally. Real smoke execution belongs to TAFFISH Hub/index automation,
where the final pushed image and its digest/platform metadata can be checked
consistently. Local/private installs preserve the smoke metadata so enterprise
or offline indexes can apply the same policy later.

## GitHub and Publishing Dependencies

Normal installation and normal app execution do not require GitHub login.

These commands may need Git/GitHub tools:

```text
taf publish
taf new --docker   (creates GitHub Actions workflow files)
taf update         (downloads index unless you use a local URL)
taf install        (clones app repositories referenced by the local index)
taf install --from (copies and installs a private/local TAFFISH project)
```

Recommended developer setup:

```sh
git --version
gh auth login
```

TAFFISH does not prompt for GitHub credentials internally. Configure SSH keys,
Git credential helpers, or GitHub CLI authentication outside TAFFISH.

When the local index provides `source.commit`, `taf install` verifies that the
installed source resolves to that exact Git commit and that the checked source
worktree is clean before building the command wrapper. This keeps source
rewrite/mirror installs auditable without rewriting app source files.

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

Install a private/local app project without publishing it to the public Hub:

```sh
taf install --from /path/to/my-private-tool
taf list
taf which taf-my-private-tool
```

`taf install --from` reads the local project's `taffish.toml`, checks the
project, copies the working tree into the selected TAFFISH home, builds the
versioned command wrapper, and records the install origin as
`[local-project] <PROJECT-ROOT>`. `PROJECT-DIR` may be the project root or any
child directory; TAFFISH searches upward for `taffish.toml`. It does not require
`taf update` and does not auto-install dependencies.

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

Publish with release notes:

```sh
taf publish --release --dry-run
taf publish --release --yes
```

`taf new` creates an ignored `release.md` draft. With `taf publish --release`,
the first line of `release.md` becomes the publish message, and the whole file
becomes the GitHub Release notes. Replace the default
`# TODO: release summary` first line before publishing.

## MCP / AI Integration

TAFFISH `0.4.0` introduced `taffish-mcp`, a conservative MCP stdio server for
AI clients. TAFFISH `0.5.0` added read-only TAF source/file compiler tools, and
TAFFISH `0.6.0` added AI-readable taf-app inspection, current project
inspection, and safe app invocation compile. TAFFISH `0.7.0` aligns MCP
compile tools with the runtime container backend override. TAFFISH `0.8.0`
surfaces smoke/trust metadata for containerized taf-app inspection without
running smoke tests or containers:

- `taffish_get_version` / `taffish_get_help`
- `taffish_validate_source` / `taffish_validate_file`
- `taffish_compile_source` / `taffish_compile_file`
- `taffish_summarize_source` / `taffish_summarize_file`
- `taffish_resolve_app`
- `taffish_inspect_app`
- `taffish_summarize_app_usage`
- `taffish_compile_app_invocation`
- `taffish_check_project`
- `taffish_inspect_project`
- `taffish_summarize_project_usage`
- `taffish_compile_project`

The MCP interface also exposes safe project, Hub, config, history, resource,
and prompt operations. It does not expose `taf run`, `taf publish`, or
image-building actions. Source, project, and app invocation compile tools
validate arguments and return generated shell code, but never run the app or
the project.

For MCP compile tools, pass `containerBackend` when backend choice matters. If
that argument is omitted, `TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker`
is used when set; explicit `containerBackend` always has priority.

Example MCP client configuration:

```json
{
  "mcpServers": {
    "taffish": {
      "command": "taffish-mcp",
      "args": []
    }
  }
}
```

This lets an AI client inspect current TAFFISH projects and installed taf-apps,
validate or compile `.taf` source without executing it, search the local index,
read project resources such as `taffish.toml`, `src/main.taf`, `docs/help.md`,
and `release.md`, and prepare safe project actions without shelling out through
unstructured terminal text first.

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

For a persistent mirror config:

```sh
taf config init --china --force
taf update
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

The raw installer is usually downloaded from `main`, but it installs files from
a fixed git tag selected by `--version`:

```text
https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh
https://raw.githubusercontent.com/taffish/taffish/v<version>/target/taf-<os>-<arch>-<version>
https://raw.githubusercontent.com/taffish/taffish/v<version>/target/taffish-<os>-<arch>-<version>
https://raw.githubusercontent.com/taffish/taffish/v<version>/target/taffish-mcp-<os>-<arch>-<version>
https://raw.githubusercontent.com/taffish/taffish/v<version>/completion/...
https://raw.githubusercontent.com/taffish/taffish/v<version>/vim-highlight/...
```

The Gitee installer uses the same versioned layout under:

```text
https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh
https://gitee.com/taffish-org/taffish/raw/v<version>/target/...
```

## Release Verification

The current binary release payload is kept under `target/` so GitHub and Gitee
raw installers can use the same tag-fixed file layout. The 0.9.0 release
includes these verification files:

```text
target/SHA256SUMS
target/SHA256SUMS.asc
target/TAFFISH-RELEASE-KEY.asc
```

The copyable GitHub release note draft is kept at
[docs/releases/v0.9.0.md](docs/releases/v0.9.0.md).

The raw installers primarily download and install versioned files; they do not
currently verify `SHA256SUMS` or the GPG signature automatically. For
high-security installation, download the tag contents or release bundle first,
verify the checksum manifest and signature manually, then install from the
verified local files.

Verify checksums:

```sh
cd target
shasum -a 256 -c SHA256SUMS
```

Verify the checksum signature:

```sh
gpg --import TAFFISH-RELEASE-KEY.asc
gpg --verify SHA256SUMS.asc SHA256SUMS
```

Before trusting `TAFFISH-RELEASE-KEY.asc`, compare the imported release key
fingerprint with this public fingerprint:

```text
F863 33E6 0BD6 74F1 59A5  651A B919 3F30 C424 7BB2
```

Current `0.9.0` checksum manifest:

```text
cb9374bae0727270d4ff5775a04284b0e89609e468de496c552b6ac9fa0b05b5  taf-darwin-arm64-0.9.0
676f2ff10b377489bcfab76a74afaed004d81af167fd1ac9a1faa6aff62c8dd0  taf-linux-amd64-0.9.0
fbe969c25f5dd73ee09e9f117105e28b4facb9c1fc697b42fd599e540e4244b5  taffish-darwin-arm64-0.9.0
a847f315bb46f399a7a00a018570fb7e316412313ba28346eb00f9ab4e1a455b  taffish-linux-amd64-0.9.0
570332129dbf45daa6d70785091fd87df315eb83c0b19a6452175713127935ea  taffish-mcp-darwin-arm64-0.9.0
4fb3c1fdceeba6aaf8a6645b3042d4d7b5de31e0f01809fa2fddf7babc3226c5  taffish-mcp-linux-amd64-0.9.0
```

This confirms that the checksum manifest was signed by the TAFFISH release key.
It does not yet claim GitHub Actions provenance, artifact attestation, or
reproducible builds. Those are planned supply-chain improvements for later
release infrastructure.

## Project Status

This repository is the open-source source repository for the TAFFISH local CLI
release series. It currently keeps manually built binary payloads in `target/`
to support tag-fixed GitHub/Gitee raw installation.

## License

TAFFISH is licensed under the [Apache License 2.0](LICENSE). Security reports
and contribution guidance are documented in [SECURITY.md](SECURITY.md) and
[CONTRIBUTING.md](CONTRIBUTING.md).
