# TAFFISH Binary Distribution

This repository distributes prebuilt `taf` and `taffish` binaries.

Current scope:
- Binary-only distribution (source code is not published here)
- Installer script
- Shell completion files
- Vim syntax files

## Quick Install

User install:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/latest/download/install-taffish.sh | sh -s -- --user
```

System install:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/latest/download/install-taffish.sh | sh -s -- --system
```

Pinned release install:

```sh
curl -fsSL https://github.com/taffish/taffish/releases/download/v0.1.1/install-taffish.sh | sh -s -- --version 0.1.1 --user
```

## Local/Offline Install

From a downloaded release tarball:

```sh
sh install/install-taffish.sh --archive ./taffish-0.1.1-target.tar.gz --user
```

## Release Interface

- `install/install-taffish.sh`
- `taf-<os>-<arch>-<version>` (release asset)
- `taffish-<os>-<arch>-<version>` (release asset)
- `https://github.com/taffish/taffish/archive/refs/tags/v<version>.tar.gz`
- `completion/`
- `vim-highlight/`

Default installer behavior:
- download binary assets from `releases/download/v<version>/...`
- download completion/vim files from tag archive

## Installer Options

```text
--user
--system
--prefix DIR
--bin-dir DIR
--taffish-home DIR
--version VERSION
--repo OWNER/REPO
--os OS
--arch ARCH
--taf-url URL
--taffish-url URL
--share-url URL
--url URL
--archive FILE
--no-update
--no-doctor
```

## Notes

- Default `--repo` is `taffish/taffish`.
- Default target platform is auto-detected from current machine.
- Use `--os` and `--arch` to force a target asset name when needed.
- `--archive` or `--url` enables bundle mode (single tarball input).
- Installed commands are:
  - `taf`
  - `taffish`
