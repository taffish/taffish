# TAFFISH

[English](README.md) · [简体中文](README-CN.md) · [Website](https://taffish.com/) · [Browse the Hub](https://taffish.github.io/)

**Bring reproducibility back to the shell.** TAFFISH packages bioinformatics tools and lightweight workflows as versioned commands you can use in an existing shell script, HPC job or workflow.

For example, with the FastQC app installed, this line runs quality control on a FASTQ file in the current directory.

```sh
taf-fastqc-v0.12.1-r1 fastqc reads.fq.gz
```

TAFFISH works at the level of a single command. Here, `0.12.1` identifies the FastQC version and `r1` the TAFFISH package revision. Add `--compile` immediately after the command name to inspect the generated shell, including the container image and the arguments passed to FastQC. Your analysis script still determines how this step fits into the rest of the workflow. [Why TAFFISH works at the command level](https://taffish.com/stories/positioning/)

<a name="table-of-contents"></a>

[How it works](#how-taffish-works) · [Install](#quick-install) · [Install offline](#local-or-offline-install) · [Try FastQC](#first-run) · [Updates](#updates-and-upgrades) · [Guides](#guides)

<a name="taffish-ecosystem"></a>

## How TAFFISH works

1. **Define a tool or flow.** An app author describes the command, its arguments and any container image in a `.taf` file. The `taffish` compiler translates it into POSIX shell. The app's `taffish.toml` records its version, package revision and dependencies. A flow can call several versioned apps from the same script.
2. **Find and install a release.** Browse the Hub or search its index with `taf`. The `taf install` command installs the selected app's source and shell wrapper. The versioned command selects that exact release. The shorter alias, such as `taf-fastqc`, selects the newest version installed in the same scope. [View FastQC 0.12.1-r1 in the Hub](https://taffish.github.io/?pkg=fastqc&ver=0.12.1-r1)
3. **Run it from your shell.** For a containerized app, the wrapper invokes Docker, Podman or Apptainer. The backend fetches the image on first use if it is missing and reuses its cache on subsequent runs. The same command works inside a larger script or workflow.

For AI clients, `taffish-mcp` exposes app inspection, argument handling and compilation through MCP over stdio. You can use the CLI on its own. [System architecture](docs/architecture/README.en.md) · [MCP interface](docs/standards/en/mcp-interface-spec.md)

## Quick Install

Choose [GitHub](#github), [Gitee](#gitee) or [local/offline installation](#local-or-offline-install). The official 0.12.0 packages contain `taf`, `taffish` and `taffish-mcp`, built with Han Lisp 0.3.0. You can install and check these commands without installing Lisp or a container backend. [0.12.0 release notes](docs/releases/v0.12.0.md)

| <a name="supported-platforms"></a><a name="system-requirements"></a>Platform | Package | Additional requirements | Build implementation |
| --- | --- | --- | --- |
| <a name="macos-dependencies"></a>Apple Silicon macOS 15 or later | `taffish-0.12.0-darwin-arm64.tar.xz` | None | [SBCL](https://www.sbcl.org/) 2.4.9 |
| <a name="linux-dependencies"></a>glibc-based Linux x86-64 | `taffish-0.12.0-linux-amd64.tar.gz` | `tar`, `gzip` | [LispWorks](https://www.lispworks.com/) |

The installation commands below include `--accept-runtime-license`. On Linux, this explicitly accepts the [LispWorks runtime terms](licenses/LISPWORKS-RUNTIME.txt) without an interactive `yes` prompt; read and accept the terms before running a command. Omit the option if you prefer to confirm during installation. macOS does not require this confirmation and ignores the option.

<a name="macos-says-libzstd1dylib-is-missing"></a><a name="project-status"></a>

**Upgrading from 0.11.0 on macOS?** Keep Homebrew's `zstd` until the upgrade finishes. The installer runs the old SBCL commands to identify them before replacing them.

<a name="standard-install"></a>

Choose either a personal or a system-wide installation. System-wide installation requires administrator access; `sudo` may prompt for your password.

### GitHub

**Personal installation:**

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --user --accept-runtime-license
```

**System-wide installation:**

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sudo sh -s -- --system --accept-runtime-license
```

<a name="for-users-in-china"></a>

### Gitee

Use the China mirror to download the package and initialize a new installation with the China index.

On macOS, this installer downloads and reassembles archive parts automatically; GitHub and Linux downloads use complete archives.

**Personal installation:**

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --user --accept-runtime-license
```

**System-wide installation:**

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sudo sh -s -- --system --accept-runtime-license
```

<a name="choose-user-or-system-scope"></a><a name="install-paths"></a><a name="installer-options"></a>

To pin the installer and package to the same version, fetch the installer from that release tag. [Pinned installations](install/README.md#install-from-raw-installer) · [Shared servers and install paths](install/README.md#default-paths-and-scopes)

### Local or Offline Install

If you have a 0.12.0 checkout containing the signed platform packages, choose one of these commands and run it from the checkout root.

**Personal installation:**

```sh
sh install/install-taffish.sh --local --user --accept-runtime-license
```

**System-wide installation:**

```sh
sudo sh install/install-taffish.sh --local --system --accept-runtime-license
```

<a name="release-interface"></a>

For an offline machine, place these **five files from the same version** in one directory. Take the [installer](install/install-taffish.sh), your complete platform archive, `ARCHIVE-SHA256SUMS`, `ARCHIVE-SHA256SUMS.asc` and `TAFFISH-RELEASE-KEY.asc`. The archive and its three verification files are in the [package directory](target/packages-0.12.0/). If you have only macOS download parts, [reassemble the complete archive first](install/README.md#local-installation-with-0120-and-later). Choose one of these commands and run it from the copied directory.

**Personal installation:**

```sh
sh install-taffish.sh --local --user --accept-runtime-license
```

**System-wide installation:**

```sh
sudo sh install-taffish.sh --local --system --accept-runtime-license
```

Local mode checks beside the installer first, then in `../target/packages-0.12.0/` relative to the installer. It skips the network index update. For a moved or renamed archive, add `--archive /path/to/package` and keep its verification files beside it. An offline run of a containerized app also needs the app, its dependencies and its image available locally. [Offline installation options](install/README.md#local-installation-with-0120-and-later)

### Verify Installation

For a default user installation, set `PATH` in your current shell and add the same export to your shell profile for future sessions. Then check the three core commands. Each reports `0.12.0` for this release, including on an offline machine.

```sh
export PATH="$HOME/.local/bin:$HOME/.local/share/taffish/bin:$PATH"
taf --version
taffish --version
taffish-mcp --version
```

<a name="release-verification"></a>

The official installer checks the SHA-256 of the archive and of each executable. To require valid release signatures on both manifests, add `--verify gpg` to the install command and provide `gpg` and `gpgv`. [Verify the package and signing key](install/README.md#release-verification)

<a name="basic-usage"></a>

## First Run

With the core installed and a container backend ready, try FastQC without supplying any data. You need network access to the index and app repository, and Git to install the app. The last command runs FastQC and can download its image the first time.

```sh
taf update --user
taf install --user fastqc 0.12.1-r1
taf-fastqc-v0.12.1-r1 -- --version
```

FastQC prints `FastQC v0.12.1`. The first `--` passes the following option through to FastQC. To see the TAFFISH package version and revision instead, run `taf-fastqc-v0.12.1-r1 --version`. You can now use the command at the top of this page on your own data. [Quick start](https://github.com/taffish/taffish-docs/blob/main/en/quick-start.en.md)

<a name="upgrade-or-remove-taffish"></a>

## Updates and upgrades

| What do you want to update? | How |
| --- | --- |
| TAFFISH itself (`taf`, `taffish`, `taffish-mcp`) | Rerun the new release's installer with the original install scope (`--user` or `--system`) and paths. For an offline upgrade, use `--local` with the new release's signed platform package. [Core upgrade instructions](install/README.md#upgrade-and-removal) |
| Local Hub index | Run `taf update` to refresh the catalog of available apps and versions. Installed app versions stay in place. |
| Installed Hub apps | After refreshing the index, run `taf upgrade` to preview available upgrades. Run `taf upgrade --yes` to apply the plan. |

Both Hub commands default to user scope. For system-installed apps, use `--system` when refreshing the index, previewing upgrades and applying them.

## Guides

| I want to… | Start here |
| --- | --- |
| Find a tool or workflow | [Browse apps and flows](https://taffish.github.io/) · [Use the Hub from the CLI](https://github.com/taffish/taffish-docs/blob/main/en/taffish-hub.en.md) |
| <a name="taf-app-smoke-metadata"></a><a name="github-and-publishing-dependencies"></a>Package a tool or assemble a flow | [App author guide](https://github.com/taffish/taffish-docs/blob/main/en/app-developer-guide.en.md) · [Flow author guide](https://github.com/taffish/taffish-docs/blob/main/en/taf-flow-developer-guide.en.md) · [TAF scripting tutorial](https://github.com/taffish/taffish-docs/blob/main/en/taf-script-tutorial.en.md) · [App metadata and smoke checks](docs/standards/en/taffish-project-spec.md#smoke) |
| <a name="runtime-config-and-mirrors"></a><a name="container-backends"></a><a name="docker"></a><a name="podman"></a><a name="apptainer"></a><a name="apptainer-shared-sif-cache-for-system-installs"></a>Choose a container backend or deploy on a cluster | [Docker, Podman and Apptainer](https://github.com/taffish/taffish-docs/blob/main/en/quick-start.en.md#container-backends) · [System scope, mirrors and shared SIF caches](https://github.com/taffish/taffish-docs/blob/main/en/system-administration.en.md) |
| <a name="environment-diagnostics"></a><a name="troubleshooting"></a><a name="taf-or-an-installed-app-command-is-not-found"></a><a name="taf-update-fails-with-github-connection-reset"></a><a name="apptainer-says-mksquashfs-is-missing"></a><a name="apptainer-says-no-writable-apptainer-image-directory-found"></a><a name="apptainer-prints-converting-sif-file-to-temporary-sandbox-every-run"></a><a name="docker-permission-denied"></a>Troubleshoot a command or an installation | Run `taf doctor --user` for a local diagnostic. [Troubleshooting](https://github.com/taffish/taffish-docs/blob/main/en/troubleshooting.en.md) · [Upgrade or remove TAFFISH](install/README.md#upgrade-and-removal) |
| <a name="human-cli-language"></a><a name="shell-completion"></a><a name="vim-syntax-highlighting"></a>Configure my shell or CLI language | `taf config language en` or `taf config language zh`. [Language settings and packs](docs/standards/en/localization.md) · [Shell completion](completion/README.md) · [Vim syntax](vim-highlight/README.md) |
| <a name="mcp--ai-integration"></a>Connect an AI client | [MCP client setup](https://github.com/taffish/taffish-docs/blob/main/en/mcp-clients.en.md) · [MCP tools and permissions](docs/standards/en/mcp-interface-spec.md) |
| <a name="build-from-source"></a>Build or contribute to TAFFISH | [Build from source](docs/dev/en/build-from-source.md) · [Developer documentation](docs/README.en.md) · [Contributing](CONTRIBUTING.md) |

<a name="license"></a>

TAFFISH source is licensed under [Apache License 2.0](LICENSE). The official binaries include platform runtimes with [their own notices and terms](install/README.md#runtime-licenses). [Report a security issue](SECURITY.md)
