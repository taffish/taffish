# TAFFISH installer

This directory contains the POSIX `sh` installers for TAFFISH binary releases.

## Files

- `install-taffish.sh`: GitHub/default raw installer.
- `install-taffish.gitee.sh`: Gitee/China raw installer.

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

## Install From Raw Installer

Default GitHub install:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --user
```

China/Gitee install:

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --user
```

Pinned version:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --version 0.2.0 --user
```

Install from a local tarball:

```sh
sh install/install-taffish.sh --user --archive ./taffish-0.2.0-target.tar.gz
```

Install from an explicit URL:

```sh
sh install/install-taffish.sh --user --url https://example.org/taffish.tar.gz
```

Default mode (without `--archive`/`--url`) downloads:

- `taf-<os>-<arch>-<version>` and `taffish-<os>-<arch>-<version>` from `target/` under `v<version>`
- completion and vim files from the same tag

Use `--provider github|gitee` or `--raw-base-url` to select another raw source.
Use `--share-url` to override the completion/vim source with a tar.gz archive.
Use `--taf-url` / `--taffish-url` to override binary asset URLs.
Use `--os` / `--arch` to override platform detection.

## Useful Options

```text
--user
--system
--prefix DIR
--bin-dir DIR
--taffish-home DIR
--provider github|gitee
--raw-base-url URL
--config-profile github|china|none
--force-config
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
