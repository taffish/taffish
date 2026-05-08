# TAFFISH installer

This directory contains the POSIX `sh` installer for TAFFISH binary releases.

## Files

- `install-taffish.sh`: single-file installer for release binaries (curl entry).

Bundle mode layout (`--archive` / `--url`):

```text
target/
  taf-<os>-<arch>-<version>       (or legacy target/taf)
  taffish-<os>-<arch>-<version>   (or legacy target/taffish)
completion/
  bash/
  zsh/
  fish/
vim-highlight/
  syntax/
  ftdetect/
LICENSE
README.md
```

The installer auto-selects the host-matching binaries from `target/` and
installs them as `$BIN_DIR/taf` and `$BIN_DIR/taffish`.

## Default paths

User install:

```text
bin  = ~/.local/bin
home = ~/.local/share/taffish
```

System install:

```text
bin  = /usr/local/bin
home = /opt/taffish
```

The installer respects these environment variables:

```text
TAFFISH_USER_HOME
TAFFISH_SYSTEM_HOME
TAFFISH_SYSTEM_BIN_DIR
```

## Install From Binary Release

Recommended:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/latest/download/install-taffish.sh | sh -s -- --user
```

Pinned release:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/download/v0.1.1/install-taffish.sh | sh -s -- --version 0.1.1 --user
```

Install from a local tarball:

```sh
sh install/install-taffish.sh --user --archive ./taffish-0.1.1-target.tar.gz
```

Install from an explicit URL:

```sh
sh install/install-taffish.sh --user --url https://example.org/taffish.tar.gz
```

Default mode (without `--archive`/`--url`) downloads:

- `taf-<os>-<arch>-<version>` and `taffish-<os>-<arch>-<version>` from release assets
- completion and vim files from:
  `https://github.com/<repo>/archive/refs/tags/v<version>.tar.gz`

Use `--share-url` to override the tag archive URL.
Use `--taf-url` / `--taffish-url` to override binary asset URLs.
Use `--os` / `--arch` to override platform detection.

## Useful Options

```text
--user
--system
--prefix DIR
--bin-dir DIR
--taffish-home DIR
--os OS
--arch ARCH
--no-update
--no-doctor
```

`taf update` is attempted by default after installation. If it fails because
of network problems, the installer prints a warning but does not roll back the
installation.

The installer does not edit shell rc files or vim configuration files. It
prints the installed completion and vim paths so users can enable them
explicitly.
