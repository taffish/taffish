# TAFFISH

[English](README.md) | [中文](README-CN.md)

TAFFISH is a shell-native reproducible execution and delivery layer for
bioinformatics command-line tools and lightweight workflows.

> Bring reproducibility back to the shell.

Its executable package model turns command-line tool invocations into
versioned, container-resolved, installable, and composable shell commands that
can be used directly in ordinary shells or embedded in existing workflow
systems.

TAFFISH is not a general-purpose workflow engine. Installed `taf-*` commands
can be called by users, shell scripts, HPC job scripts, workflow systems,
Python/R programs, or AI agents.

This repository provides the local command-line implementation, installers,
source-tree documentation, shell completion files, Vim syntax files, and
manually built binary release payloads for supported platforms.

The local command-line tools are:

- `taffish`: compile `.taf` programs to shell.
- `taf`: manage TAFFISH app projects and local TAFFISH Hub packages.
- `taffish-mcp`: expose safe TAFFISH tools/resources/prompts to AI clients through MCP over stdio.

For a guided introduction, start with the
[TAFFISH Quick Start](https://github.com/taffish/taffish-docs/blob/main/en/quick-start.en.md).
This README remains the source, installation, platform, and release reference
for the local implementation.

## Table of Contents

- [TAFFISH Ecosystem](#taffish-ecosystem)
- [How TAFFISH Works](#how-taffish-works)
- [Supported Platforms](#supported-platforms)
- [Quick Install](#quick-install)
  - [Standard Install](#standard-install)
  - [For Users in China](#for-users-in-china)
  - [Choose User Or System Scope](#choose-user-or-system-scope)
  - [Verify Installation](#verify-installation)
  - [First Run](#first-run)
- [System Requirements](#system-requirements)
  - [macOS Dependencies](#macos-dependencies)
  - [Linux Dependencies](#linux-dependencies)
- [Install Paths](#install-paths)
- [Runtime Config and Mirrors](#runtime-config-and-mirrors)
  - [Human CLI Language](#human-cli-language)
- [Installer Options](#installer-options)
- [Upgrade Or Remove TAFFISH](#upgrade-or-remove-taffish)
- [Local or Offline Install](#local-or-offline-install)
- [Build From Source](#build-from-source)
- [Container Backends](#container-backends)
  - [Docker](#docker)
  - [Podman](#podman)
  - [Apptainer](#apptainer)
- [TAF App Smoke Metadata](#taf-app-smoke-metadata)
- [GitHub and Publishing Dependencies](#github-and-publishing-dependencies)
- [Environment Diagnostics](#environment-diagnostics)
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
| [taffish/taffish-index](https://github.com/taffish/taffish-index) | Static package index consumed by `taf update`, `taf search`, `taf info`, `taf install`, `taf outdated`, and `taf upgrade`. |
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

## How TAFFISH Works

TAFFISH has three layers that can be used independently:

1. A `.taf` program describes a shell command, its parameter contract, and,
   when needed, the container image and runtime arguments. `taffish` validates
   this source and compiles it to POSIX shell; it does not execute the generated
   shell by itself.
2. A taf-app packages a `.taf` program with `taffish.toml`, documentation, and
   a fixed `version` plus `release`. Apps may wrap one command-line tool or
   compose several apps into a lightweight flow.
3. `taf` manages app projects and consumes the static Hub index. `taf install`
   installs app source and a small shell wrapper into user or system scope. A
   versioned command such as `taf-fastqc-v0.12.1-r1` identifies an exact app
   release; the unversioned `taf-fastqc` alias selects the newest version
   installed in that scope.

Installing a containerized app does not immediately download its container
image. On the first invocation, the generated wrapper selects Docker, Podman,
or Apptainer and lets that backend obtain the image. Later invocations reuse
the backend's local image/cache. This keeps package installation lightweight
while preserving a versioned command interface.

`taffish-mcp` exposes conservative inspection and compilation operations to AI
clients. It does not expose project execution, image building, or publishing.

## Supported Platforms

Current binary assets:

| Platform | Asset suffix | Build backend | Notes |
| --- | --- | --- | --- |
| macOS Apple Silicon | `darwin-arm64` | SBCL | macOS 15.0 or later; requires Homebrew `zstd` runtime library. |
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

If a shared server uses Apptainer, system-installed apps are visible to all
users but first-run SIF image caching still needs a writable image directory.
The ordinary `--system` install keeps the SIF directory administrator-managed;
it does not make it writable by every user. Add `--shared-sif-cache` only when
the site intentionally accepts a sticky shared cache on a trusted host.
See [Apptainer shared SIF cache](#apptainer-shared-sif-cache-for-system-installs)
before deploying TAFFISH for multiple users.

Pinned version install. The installer may come from `main`, but downloaded
files are pinned to the selected git tag:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --version 0.11.0 --user
```

Official installs default to `--verify auto`. Each selected binary must match the
tag's `SHA256SUMS`. The installer also verifies the manifest signature if it can
obtain the signature and release public key and find both `gpg` and `gpgv`.
Use `--verify gpg` to require a valid signature. Once downloaded, the installer
can preview paths and verification settings with `--dry-run` without network access or writes.

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

If the server uses Apptainer, also review
[Apptainer shared SIF cache](#apptainer-shared-sif-cache-for-system-installs).

Pinned version install:

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --version 0.11.0 --user
```

The Gitee installer applies the same payload-verification and transactional
installation rules as the GitHub installer; only provider defaults differ.

To force the installer to replace an existing config with the Gitee/China
profile, add `--force-config`:

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --user --force-config
```

### Choose User Or System Scope

Installation scope and `taf` operation scope are related, but they are not a
persistent global mode. Scope-aware `taf` commands default to `--user` on every
invocation, even when the `taf` binary itself was installed system-wide.

| Scope | Intended use | State and app locations |
| --- | --- | --- |
| `--user` / `-u` | One user, no administrator access | `~/.local/share/taffish` |
| `--system` / `-s` | Shared server or managed workstation | `/opt/taffish` and `/usr/local/bin` |

The scope-aware commands are `update`, `search`, `info`, `install`, `outdated`,
`upgrade`, `prune`, `uninstall`, `list`, `which`, `doctor`, and `config`.
Project-local commands such as `new`, `check`, `run`, `build`, and `publish` do
not become system operations by adding `--system`.

System-scope writes normally require administrator permission. Read-only
operations such as `search`, `info`, `list`, `which`, `outdated`, and `doctor`
can normally use `--system` without `sudo` when the system home is readable.

### Verify Installation

User installs have two command directories: `~/.local/bin` contains the three
TAFFISH core commands, while `~/.local/share/taffish/bin` contains commands
installed later by `taf install`. Run this line in your current shell and add
it to your shell profile for future sessions:

```sh
export PATH="$HOME/.local/bin:$HOME/.local/share/taffish/bin:$PATH"
```

Check that all three commands report the installed version, then check the user scope:

```sh
taf --version
taffish --version
taffish-mcp --version
taf doctor --user
```

After a system install, verify the system scope explicitly:

```sh
taf --version
taf doctor --system
```

The default system command directory is `/usr/local/bin`, which is normally
already in each user's `PATH`.

### First Run

Normal user workflow:

```sh
taf update --user
taf search --user fastqc
taf install --user fastqc
taf list --user
taf-fastqc -- --help
```

The first four commands update the local package index, find an app, install
its source/wrapper, and list the resulting installation. In the final command,
the first `--` ends wrapper-option parsing, so `--help` is forwarded to the
wrapped application. A containerized app may download its image on this first
invocation; install at least one supported backend and use
`taf doctor --user --verbose` if backend selection fails.

Shared-server administrator workflow:

```sh
sudo taf update --system
taf search --system fastqc
sudo taf install --system fastqc
taf list --system
taf which --system taf-fastqc
```

For system app maintenance, use the same scope consistently, for example
`sudo taf upgrade --system --yes`, `sudo taf prune --system --yes`, and
`sudo taf uninstall --system APP`. See the
[System Administration Guide](https://github.com/taffish/taffish-docs/blob/main/en/system-administration.en.md)
for permissions, shared completion, Vim integration, mixed user/system
deployments, and Apptainer cache policies.

## System Requirements

The installer needs standard POSIX userland tools:

```text
sh, uname, tar, mktemp, cp, mv, rm, chmod, mkdir, find, dirname,
awk, sed, grep, tr, stat, id
```

Official payload verification additionally requires one SHA256 implementation:

```text
sha256sum or shasum
```

For online installation it also needs one downloader:

```text
curl or wget
```

`gpg` and `gpgv` are optional in `auto` mode. To require a signed manifest, use
`--verify gpg` and make both tools, the signature, and the release public key available.

`taf update` downloads the TAFFISH index from GitHub by default. In networks
where GitHub raw content is blocked or unstable, installation can still finish,
but `taf update` may print a warning. You can retry later:

```sh
taf update --user
```

or use a mirror/custom index:

```sh
taf update --url INDEX_URL
```

### macOS Dependencies

The current `darwin-arm64` binaries declare macOS 15.0 as their minimum OS
version in Mach-O metadata. Older macOS versions are outside this prebuilt
binary baseline; this is a build requirement, not a claim of testing on every
supported OS version.

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

Default layout:

| Scope | Core command bin | Installed app command bin | TAFFISH home |
| --- | --- | --- | --- |
| user | `~/.local/bin` | `~/.local/share/taffish/bin` | `~/.local/share/taffish` |
| system | `/usr/local/bin` | `/usr/local/bin` | `/opt/taffish` |

TAFFISH home stores local apps, indexes, cached images, command launchers,
completion files, Vim files, logs, and other runtime data.

For system installs, app wrappers and metadata live under the system home, but
container image caches are runtime state. Docker and Podman use their own image
stores. Apptainer uses SIF files under `images/sif`; see the Apptainer section
if multiple users should share system-level SIF files.

If `TAFFISH_USER_HOME` is customized, its `bin` subdirectory must also be in
the user's `PATH`. If a system deployment customizes `TAFFISH_SYSTEM_HOME` or
`TAFFISH_SYSTEM_BIN_DIR`, define those variables consistently for both
administrators and users.

Relevant environment variables:

```text
TAFFISH_USER_HOME        Override user TAFFISH home
TAFFISH_SYSTEM_HOME      Override system TAFFISH home
TAFFISH_SYSTEM_BIN_DIR   Override system command bin dir
TAFFISH_CONFIG           Use an explicit config.toml file
TAFFISH_INDEX_URL        Override default index URL for taf update
TAFFISH_LANGUAGE         Override the human CLI language
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

TAFFISH runtime configuration controls package-index locations, source URL
rewrites, and the preferred human CLI language. The default config paths are:

```text
user   = ~/.local/share/taffish/config.toml
system = /opt/taffish/config.toml
```

Inspect user and system configuration separately:

```sh
taf config --user
taf config path --user
taf config --system
taf config path --system
```

Initialize the default GitHub profile:

```sh
taf config init --user --github
```

Initialize the China mirror profile template:

```sh
taf config init --user --china --force
taf update --user
```

For a managed system profile:

```sh
sudo taf config init --system --github
sudo taf update --system
```

For a managed system using the China mirror profile:

```sh
sudo taf config init --system --china --force
sudo taf update --system
```

User scope loads the system config first and then applies an optional user
config override. System scope reads the system config but not the user config.
`TAFFISH_CONFIG` remains an explicit final override.

### Human CLI language

Use `taf --help` for the command overview and `taf help <command>` (or
`taf <command> -h`) for its options. `taffish --help` explains compilation input,
container settings, and examples; it does not run the generated shell.
Both top-level help pages end with the website, Hub, and support contact.

TAFFISH embeds English (`en`) and Chinese (`zh`) catalogs for CLI help and
`taf` human-readable status, diagnostic, and error output.
Neither language requires an extra download. The standalone installer uses
English messages; choosing GitHub or Gitee changes sources, not the CLI language.
For a new installation with no saved language preference, the human CLI uses
`auto`: a recognized host locale selects its language, while an unavailable,
unset, `C`, or `POSIX` locale falls back to English. Inspect the configured
selection, displayed language, and every available language with:

```sh
taf config language
taf config language --show
```

The two commands above are equivalent and do not modify configuration. Make a
persistent user-scope choice with:

```sh
taf config language en
taf config language zh
taf config language auto
```

Use `--system` with administrator privileges to set the managed system
default, for example `sudo taf config language zh --system`. The setter changes
only the top-level `language` field and preserves the other config content.

Select Chinese for one command without changing the saved preference:

```sh
TAFFISH_LANGUAGE=zh taf --help
TAFFISH_LANGUAGE=zh taffish --help
TAFFISH_LANGUAGE=zh taffish-mcp --help
```

With no saved language field, the configured selection is `auto`. Resolution
order is `TAFFISH_LANGUAGE`, explicit `TAFFISH_CONFIG`, user config, system
config, and the implicit `auto` default. When the selected value is `auto`,
TAFFISH consults `LC_ALL`, `LC_MESSAGES`, and `LANG`; lookup always ends at the
built-in English fallback. Save `en` or `zh` when deterministic human output
is required regardless of host locale. External locale packs are an optional
advanced feature. Valid packs discovered under user/system
`share/locales/<locale>/` are listed by `taf config language`; an optional
`example.txt` supplies the one-line sample shown beside a language. A pack may
provide only help files, only `messages.json`, or any subset of either. Missing,
malformed, or placeholder-incompatible entries fall back independently through
the exact locale, its base language, and built-in English; one bad entry does
not disable the rest of the pack. The language is resolved once for each CLI
invocation, so one command does not switch languages halfway through its
output.

An external help file replaces that help page as a whole. Its author maintains
the command descriptions and contact links; built-in help updates are not
automatically appended to custom pages.

Localization covers human-readable CLI help plus `taf` project, Hub, package,
config, doctor, and history presentation. This includes parser and business
diagnostics owned by those commands and `taffish-mcp -h`, but not the MCP stdio
protocol. Commands/options, generated shell, JSON schemas and values,
history/index/config data, MCP tools/resources/prompts/results, taf-app output,
and external process output remain stable machine interfaces. Core `taffish`
compiler diagnostics may still use the English baseline. See the
[localization contract](docs/standards/en/localization.md) for locale-pack
layout and security rules.

The generated China template is intentionally simple:

```toml
schema_version = "taffish.config/v1"
profile = "china"
language = "auto"

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
- `taf update --url INDEX_URL` and `TAFFISH_INDEX_URL` still work as
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
--version VERSION         Release version [0.11.0]
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
--verify MODE             Verify payload: auto, sha256, gpg, or none
--checksum-file FILE      Use a local SHA256SUMS manifest
--checksum-url URL        Download SHA256SUMS from an explicit URL
--signature-file FILE     Use a local detached checksum signature
--signature-url URL       Download a detached checksum signature
--release-key-file FILE   Use a local release public key
--release-key-url URL     Download a release public key
--retry COUNT             Retry failed downloads COUNT times [3]
--connect-timeout SEC     Download connection timeout [15]
--config-profile PROFILE  Initialize config profile: github, china, or none
--force-config            Replace existing config during config init
--force                   Replace an unrecognized core command path
--sif-cache-policy POLICY Use auto, private, admin, or shared [auto]
--shared-sif-cache        Alias for --sif-cache-policy shared
--dry-run                 Resolve the plan without network or writes
--no-update               Do not run taf update after install
--no-doctor               Do not run taf doctor --init after install
-h, --help                Show installer help
```

In `auto` verification mode, official GitHub/Gitee payloads must match
`SHA256SUMS` before any core command is replaced. When the signature, release
public key, `gpg`, and `gpgv` are all available, the installer also verifies the
signature against the built-in TAFFISH key fingerprint. If any are unavailable,
official installs can proceed with SHA256 alone. Custom sources without a
manifest are reported as unverified in `auto` mode. Use `--verify sha256` or
`--verify gpg` to require that level of verification.

The installer uses an install lock, candidate `--version` smoke tests, and a
transactional replacement of the three core binaries. It refuses unrelated
files unless `--force` is explicit, rolls back an incomplete binary/receipt
commit, and writes the resulting hashes and verification level to
`<TAFFISH_HOME>/install-receipt.toml`. Reinstalling the same payload does not
replace unchanged core binaries; receipt and post-install readiness work may
still run.

For the complete source selection, verification, transaction, permission, and
maintainer test contract, see the [installer manual](install/README.md).

Manual platform override example:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh \
  | sh -s -- --user --os linux --arch amd64
```

## Upgrade Or Remove TAFFISH

`taf upgrade` upgrades installed taf-apps; it does not upgrade the `taf`,
`taffish`, or `taffish-mcp` binaries. Upgrade the core tools by running the
installer again with the same scope and the desired version:

```sh
# User installation
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --user --version X.Y.Z

# System installation
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sudo sh -s -- --system --version X.Y.Z
```

TAFFISH currently has no dedicated core uninstaller. Before removing the core
commands, uninstall any apps you no longer need with the matching scope and
back up a customized `config.toml`. The core command files are:

```text
user   = ~/.local/bin/{taf,taffish,taffish-mcp}
system = /usr/local/bin/{taf,taffish,taffish-mcp}
```

User state lives under `~/.local/share/taffish`; system state lives under
`/opt/taffish`. Remove a home only after checking that it contains no app,
index, config, log, or cached image data that should be retained.

## Local or Offline Install

On a connected machine, download **Source code (tar.gz)** for the `v0.11.0` tag
once it is published. The archive includes the installer, binaries, and signed checksum manifest:

```sh
curl -fL -o taffish-0.11.0.tar.gz https://github.com/taffish/taffish/archive/refs/tags/v0.11.0.tar.gz
```

Copy `taffish-0.11.0.tar.gz` to an empty directory on the offline machine. From
that directory, extract the installer and point it at the original archive:

```sh
tar -xzf taffish-0.11.0.tar.gz taffish-0.11.0/install/install-taffish.sh
sh taffish-0.11.0/install/install-taffish.sh --user --archive ./taffish-0.11.0.tar.gz --no-update --verify gpg
```

`--no-update` skips the network index update. `--verify gpg` requires local
`gpg` and `gpgv` and verifies the signed manifest from the archive. After
installation, follow [Verify Installation](#verify-installation).

For online installation from an explicit bundle URL, the same installer accepts `--url`:

```sh
sh taffish-0.11.0/install/install-taffish.sh --url https://example.org/taffish.tar.gz --user
```

Bundle layout:

```text
target/
  SHA256SUMS
  SHA256SUMS.asc
  TAFFISH-RELEASE-KEY.asc
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
are kept under `target/` for automatic installer verification and independent
manual verification.

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

TAFFISH supports two ways to pass backend-specific runtime arguments. Use
`.taf` tag arguments for app-level requirements:

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

TAFFISH-generated scripts use `apptainer --quiet` by default to keep normal app
output clean. Runtime errors are still reported.

#### Apptainer Shared SIF Cache For System Installs

When a TAFFISH app is installed with `taf install --system`, the command wrapper
is available to all users, but TAFFISH does not automatically pull Apptainer SIF
images during installation. The first run searches:

```text
${TAFFISH_SYSTEM_HOME:-/opt/taffish}/images/sif
${TAFFISH_USER_HOME:-$HOME/.local/share/taffish}/images/sif
```

If no SIF exists, TAFFISH needs one writable directory to pull the image. A
new system SIF directory is created with administrator-managed `0755`; an
existing directory keeps its current mode unless shared mode is explicitly
requested. On a shared server, choose one of these policies:

1. Per-user cache, safest default:

```sh
taf doctor --init --user
```

Each user gets their own writable `~/.local/share/taffish/images/sif` cache.

2. Administrator pre-cache:

```sh
sudo taf-APP-vVERSION-rRELEASE -- --help
```

This lets root pull the SIF into `/opt/taffish/images/sif` once. Later users
can read the existing SIF without needing write access to the system cache.

3. Shared writable system cache:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh \
  | sudo sh -s -- --system --shared-sif-cache
```

`1777` is the sticky-directory mode used by `/tmp`: local users can create SIF
files there, but cannot delete files owned by other users. Use this only when
you intentionally want a shared writable cache on a trusted server. If your
cluster has stricter policy, prefer administrator pre-caching or per-user
caches instead. The installer changes and verifies only
`/opt/taffish/images/sif`; it does not recursively relax the rest of the system
home. For an existing installation, rerun the same version with
`--system --shared-sif-cache`.

## TAF App Smoke Metadata

Containerized taf-apps can declare smoke metadata in `taffish.toml`.
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

## Environment Diagnostics

`taf doctor` is the read-only-first entry point for diagnosing a TAFFISH
installation:

```sh
taf doctor --user
taf doctor --system
taf doctor --user --shell bash --verbose
taf doctor --user --shell zsh --json
```

It checks TAFFISH homes, config, the local index, command paths, shell
completion, Vim/Neovim files, the Apptainer SIF cache, and bounded readiness
probes for Docker, Podman, and Apptainer. Default output includes actionable
advice for problems; `--verbose` adds detailed evidence and links, while `--json` emits the stable
`taffish.doctor/v1` schema. Use `--shell auto|bash|zsh|fish` for shell-specific
completion guidance.

Doctor does not edit shell/editor configuration, change permissions, start
services, pull images, or run containers. Only explicit `--init` creates
TAFFISH-owned directories. System-scope initialization still requires root.

For index or installed-app problems, use the offline, read-only checks:

```sh
taf doctor index --user
taf doctor hub --user
taf doctor hub abricate --system --verbose
taf doctor hub --user --json
```

`index` checks the cached index format and latest references. `hub` also checks
selected or all local installations without executing apps or probing backends.
It reports the app/version, scope, affected paths, reason and safe next step.
Without targets, `doctor hub` includes historical installed versions. Its text
separates enumerated totals from affected apps/versions and issue counts; a
version can have several issues. Incomplete enumeration is reported explicitly.
To preview repairs over the same installed-version scope, use
`taf install --all-installed --repair --user` (or `--system`), not `--all --repair`,
which selects installed index.latest only.
An older installation missing `.taf-build.json` is **unverified**, not
automatically damaged. Required files missing or checksums disagreeing are
**invalid**; unreadable paths or unsupported formats are **unknown**. Verified
local files are not proof of official authenticity or container readiness.
These checks never repair or write manifests and do not accept `--init` or
`--shell`. Their exit code is 1 for invalid/unknown checks, otherwise 0;
warnings such as missing old manifests remain visible without failing the check.
Missing or unfamiliar unversioned command shortcuts are reported separately;
they do not by themselves mean the versioned app is damaged.
Default Hub output groups repeated issues by type and recovery policy, with
counts and at most three examples per group. `--verbose` and `--json` retain
every inspection and its evidence. Read-only batching makes full Hub scans
faster without skipping checksum checks; a targeted scan avoids unrelated deep
inspection. Human stderr shows stages/counts in place on a TTY and rate-limited
lines in logs; JSON/MCP output has no progress text. Shared conservative Unicode
field layout uses separate lines for long or complex text instead of guessing
alignment or truncating paths.
See [diagnostics and recovery](docs/dev/en/taf-core/system-history-doctor.md).

Other slow commands also report their current stage on stderr: index download,
source retrieval, build/validation, repair, publish confirmation, and removal.
Batch counts identify the current target, not a time percentage. JSON/MCP
remain quiet; native Git/container output is retained. These are event-driven
notices, not a continuously ticking timer. See
[command status](docs/dev/en/taf-core/command-progress.md).

## Shell Completion

The installer copies completion files but intentionally does not edit shell
startup files. Files are installed into:

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

For a system install, the source files are under
`/opt/taffish/share/completions`. An administrator can either load them from
the site's global shell configuration or install them into the shell's system
completion directory. For Bash with `bash-completion`, a common layout is:

```sh
sudo install -m 0644 /opt/taffish/share/completions/bash/taf /etc/bash_completion.d/taf
sudo install -m 0644 /opt/taffish/share/completions/bash/taffish /etc/bash_completion.d/taffish
```

Alternatively, source both Bash files from the global interactive Bash startup
file:

```sh
source /opt/taffish/share/completions/bash/taf
source /opt/taffish/share/completions/bash/taffish
```

That file is commonly `/etc/bash.bashrc` on Debian-family systems and
`/etc/bashrc` on Red Hat-family systems. Zsh site-function and Fish vendor
completion directories are distribution-dependent; see
[completion/README.md](completion/README.md) for the supported activation
patterns.

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

For a system install, either copy the files from `/opt/taffish/share/vim` into
the site's Vim runtime directory or add this directory to the global Vim
`runtimepath`:

```vim
set runtimepath+=/opt/taffish/share/vim
```

System Vim and Neovim configuration paths vary by operating system. See
[vim-highlight/README.md](vim-highlight/README.md) for common layouts.

## Basic Usage

The examples in this section use user scope. Add `--system` when reading or
maintaining the system installation, and use administrator permission for
system-scope writes.

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

Plan or install all indexed apps:

```sh
taf install --all
taf install --all --kind tool --yes
taf install --all --flows --yes
```

`taf install --all` is dry-run by default. Use `--yes` to actually install.
Batch planning checks local installation files before making changes. Slow
checks show stage/count progress on stderr, in place on a TTY and rate-limited
in logs; `--json` and MCP remain free of progress text. Checks are batched, but
large snapshots or slow disks can still take longer. This is local validation,
not a container download, and checksum verification is not skipped.
Use `--kind tool|flow|all`, `--tools`, or `--flows` to limit the batch.
Add `--prune-old` to remove older local versions after a successful batch
install. `taf uninstall`, `taf upgrade --prune-old`, and `taf prune` only
remove TAFFISH app source/wrapper files; they do not remove shared Docker,
Podman, Apptainer, or SIF image caches.

Check and apply local app updates:

```sh
taf outdated
taf outdated --json
taf upgrade
taf upgrade --yes
taf upgrade taf-my-tool --yes --prune-old
```

`taf outdated` and `taf upgrade` compare local install metadata with the
current local index, so run `taf update` first. Local/private installs made
with `taf install --from` are treated as private and are skipped by public
index upgrades.

Remove older same-source versions while retaining the valid installed version
designated by the local index's `latest`:

```sh
taf prune
taf prune --yes
taf prune --kind flow --yes
```

The index chooses the online installation target; TAFFISH does not replace it
with the numerically greatest version. Mixed versions such as `a.7.10` and
`a.7.3` use numeric segment ordering, also without an index. Unversioned aliases
still follow the newest locally installed version. Batch maintenance does not
automatically downgrade a genuinely newer local installation.

`prune` and `--prune-old` require a valid, same-source installed `latest` before
deleting anything for that app. Missing/invalid targets, private or unknown
origins, newer versions and versions that cannot be reliably compared are
protected. Run `taf update` and inspect `taf prune --json` first. This is not
dependency-aware garbage collection: review pinned Flow dependencies before
explicitly removing old versions. Shared container images are not deleted.

Missing old build manifests do not block batch installation: structurally intact
apps remain installed with an unverified warning. Confirmed damage or an
unreadable/unknown selected installation is reported before batch writes; use
`taf doctor hub APP --user --verbose` (or `--system`) to investigate. Do not
blindly reinstall private apps or overwrite local edits. Automatic pruning
protects the whole package if any involved installed version lacks verified
evidence. No historical checksums are invented to make an old install pass.

Explicitly preview repair of existing indexed installations:

```sh
taf install APP --repair --user --dry-run
taf install APP1 APP2 --repair --user --dry-run
taf install APP 1.4.0-r1 --repair --user --dry-run
taf install --all --repair --kind tool --user
taf install --all --repair --kind tool --user --yes
taf install --all-installed --repair --user
taf install --all-installed --repair --user --yes
```

Repair has two batch selectors. `--all --repair` checks only installed
`index.latest` identities; it skips missing latest versions rather than installing
them. `--all-installed --repair` enumerates every locally installed version,
including historical versions. It never upgrades, installs missing versions or
dependencies, or prunes. Both selectors default to preview; add `--yes` to apply.
`--json`, scope and kind filters work with either selector. The selectors cannot
be combined with each other or explicit targets. `--all-installed` requires
`--repair`. For explicit version targets, use `--dry-run` to preview and remove
it to apply. Verified targets are skipped. Both selectors use `--user` by default;
use `--system` to inspect or repair system installations instead.

`--kind all` is the default: include both tools and flows. It can be omitted;
it does not select additional versions or request an upgrade. Use `--tools`
or `--flows` to restrict the app type within the selected version scope.

Unreadable/malformed installation records and versions absent from the index
remain visible as blocked targets, not silently skipped. An unknown app kind
cannot safely be excluded by a kind filter. Private sources are not replaced
from the public index. Repair rejects `--force`, `--from` and `--prune-old`.

The complete read-only preflight must pass before any batch writes. Rebuilding
requires matching source/identity, safe paths and a fixed commit; unknown formats,
private sources and custom launchers are rejected, and manifests are never
fabricated. Repairs use staging, validation, backups and rollback on failure.
Interrupted runs retain a journal and block blind retries. This is not a
whole-batch atomic transaction, crash-durability, automatic crash-recovery or
zero-downtime guarantee. Repair and normal install/uninstall/prune share home/bin
cooperative write locks without changing deletion policy; older clients cannot
be assumed to respect these locks. Review the
[repair policy](docs/dev/en/taf-core/hub-maintenance.md#explicit-repair) before applying.

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

Repeated `taf build` is idempotent for the versioned command wrapper and frozen
source snapshot: unchanged valid artifacts are verified and not rewritten.
Explicit container image builds remain separate operations.

Publish with release notes:

```sh
taf publish --release --dry-run
taf publish --release --yes
```

`taf new` creates an ignored `release.md` draft. With `taf publish --release`,
the first line of `release.md` becomes the publish message, and the whole file
becomes the GitHub Release notes. Replace the default
`# TODO: release summary` first line before publishing.

New GitHub Releases are formal and explicitly marked Latest by default. Add
`--pre` for a Pre-release, or `--no-latest` for a formal maintenance release that
does not replace Latest. These options and `--latest` are mutually exclusive.
Version numbers need not increase, but an existing tag cannot be reused for
different content. Without `--release`, publish remains tag-only and does not
set GitHub Latest or Pre-release status.

Publication is resumable: if a matching publish is interrupted after creating
a repository, pushing a branch/tag, or creating a GitHub Release, restore
connectivity and run the same `taf publish --yes ...` command again. TAFFISH
re-inspects Git/GitHub, skips matching completed phases, and stops rather than
overwriting any conflicting immutable object.
Use the same channel options and release notes on retry. Repeating a completed
publication does not reclaim Latest from a subsequently published release.

## MCP / AI Integration

`taffish-mcp` is a conservative MCP stdio server for AI clients. Its current
surface includes read-only TAF validation, compilation and summarization;
taf-app and project inspection; safe app-invocation compilation; smoke/trust
metadata inspection; and non-executing package-maintenance planners. The
server is not entirely read-only: existing index update, app install/uninstall
(dry-run by default), project creation and wrapper-build tools can write files.
These capabilities are unchanged. `install --repair` adds no MCP repair tool,
parameter or execution entry point. The current tool set includes:

- `taffish_get_version` / `taffish_get_help`
- `taffish_validate_source` / `taffish_validate_file`
- `taffish_compile_source` / `taffish_compile_file`
- `taffish_summarize_source` / `taffish_summarize_file`
- `taffish_resolve_app`
- `taffish_inspect_app`
- `taffish_summarize_app_usage`
- `taffish_compile_app_invocation`
- `taffish_check_outdated`
- `taffish_plan_install_all`
- `taffish_plan_upgrade`
- `taffish_plan_prune`
- `taffish_check_project`
- `taffish_inspect_project`
- `taffish_summarize_project_usage`
- `taffish_compile_project`

See the public [TAFFISH MCP Guide](https://github.com/taffish/taffish-docs/blob/main/en/taffish-mcp.en.md)
and [MCP Client Setup](https://github.com/taffish/taffish-docs/blob/main/en/mcp-clients.en.md)
for the complete interface and client-specific configuration.

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

### `taf` Or An Installed App Command Is Not Found

For a user install, core commands and installed app commands use different
directories. Add both to `PATH`:

```sh
export PATH="$HOME/.local/bin:$HOME/.local/share/taffish/bin:$PATH"
```

For a system install, both core and app commands default to `/usr/local/bin`.
If custom homes or bin directories are configured, add the corresponding
command directories instead.

### `taf update` fails with GitHub connection reset

This is usually a network/proxy problem when accessing GitHub raw content.
Retry later, set a proxy, or use a custom index URL:

```sh
taf update --url INDEX_URL
```

For a persistent mirror config:

```sh
taf config init --user --china --force
taf update --user
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

### Apptainer says `no writable apptainer image directory found`

This usually happens when a TAFFISH app was installed with `taf install
--system`, but no administrator has pre-cached the SIF image and the current
user has no initialized user TAFFISH home.

For a single user, initialize the user home:

```sh
taf doctor --init --user
```

For a shared server, the administrator can either pre-cache common SIF files:

```sh
sudo taf-APP-vVERSION-rRELEASE -- --help
```

or intentionally allow a shared writable system SIF cache:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh \
  | sudo sh -s -- --system --shared-sif-cache
```

Only use the `1777` option when you accept a shared cache writable by local
users. The installer applies it only to the exact SIF directory. See
[Apptainer shared SIF cache](#apptainer-shared-sif-cache-for-system-installs).

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
raw installers can use the same tag-fixed file layout. Each release includes
these verification files:

```text
target/SHA256SUMS
target/SHA256SUMS.asc
target/TAFFISH-RELEASE-KEY.asc
```

Version-specific changes, compatibility notes, validation results, and binary
checksums are in the [v0.11.0 release notes](docs/releases/v0.11.0.md).

The v0.11.0 raw installers verify every selected official binary against
`SHA256SUMS` by default. In `auto` mode they also verify the signature against
the built-in release-key fingerprint when the signature, public key, `gpg`, and
`gpgv` are all available. Use `--verify gpg` to require a valid signature or
`--verify sha256` to require checksums alone.

This payload check does not independently authenticate an installer script
fetched through `curl | sh`. For a high-security bootstrap, first obtain and
inspect the fixed-tag installer or release bundle through an independently
trusted channel, manually verify the manifest and signature below, and then
run the local installer. Custom URL/mirror payloads without a manifest are
reported as unverified in `auto` mode rather than treated as official.

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

The exact checksum manifest for a published version is the `target/SHA256SUMS`
file in that tag. Do not reuse a previous release's manifest after rebuilding
versioned binaries.

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
