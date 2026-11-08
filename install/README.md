# TAFFISH installer

[中文](README-CN.md)

This directory contains the POSIX `sh` installers for TAFFISH binary releases.

## Files

- `install-taffish.template.sh`: canonical POSIX `sh` implementation.
- `generate-installers.sh`: renders and checks the provider-specific scripts.
- `install-taffish.sh`: GitHub/default raw installer.
- `install-taffish.gitee.sh`: Gitee/China raw installer.

Do not edit the generated installers independently. Change the template and run:

```sh
install/generate-installers.sh
install/generate-installers.sh --check
```

Bundle mode layout (`--archive` / `--url`):

```text
target/
  taf-<os>-<arch>-<version>       (or legacy target/taf)
  taffish-<os>-<arch>-<version>   (or legacy target/taffish)
  taffish-mcp-<os>-<arch>-<version>
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
installs them as `$BIN_DIR/taf`, `$BIN_DIR/taffish`, and
`$BIN_DIR/taffish-mcp`.

Verification defaults to `--verify auto`:

- official GitHub/Gitee raw installs require a matching `SHA256SUMS` entry for
  every selected binary before any command is replaced;
- when the signed manifest, release key, `gpg`, and `gpgv` are available, the
  installer also verifies the signature against the built-in TAFFISH release
  key fingerprint;
- custom sources remain compatible in `auto` mode, but an unavailable manifest
  is reported as unverified rather than silently described as trusted;
- `--verify sha256` and `--verify gpg` make those levels strict, while
  `--verify none` is an explicit opt-out.

The installer script fetched by a `curl | sh` bootstrap is not independently
authenticated by the payload checksum. For a high-security bootstrap, first
download the fixed tag or installer, verify it through an independently trusted
channel, inspect it, and then run it locally. Payload verification still occurs
before binary installation.

`taffish-mcp` is included in the binary set so MCP-compatible AI clients can
inspect TAF source, installed taf-apps, and current TAFFISH projects through
structured tools/resources without running workflows.

## Language after installation

English (`en`) and Chinese (`zh`) are built into the installed commands; neither
requires a separate language pack. With no saved preference, `auto` follows a
recognized host locale and falls back to English. The standalone shell
installer's own messages remain in English. GitHub/Gitee selection and the
`github`/`china` source profiles do not select a language.

After adding the installed commands to `PATH`:

```sh
taf config language          # Show current and available languages
taf config language zh       # Save Chinese for this user
taf config language en       # Save English for this user
taf config language auto     # Restore locale-based selection
TAFFISH_LANGUAGE=en taf -h   # Override one command without changing config
```

The preference also applies to `taffish --help` and `taffish-mcp --help`, not to
generated shell or the MCP protocol. For a system default, an administrator can
run `sudo taf config language zh --system`; user preferences and environment
overrides still take precedence. Normal reinstallations keep existing config.
`--force-config` explicitly replaces it and is not needed to change language.
External language packs are optional; see the
[language configuration guide](../README.md#human-cli-language).

## Requirements

The installer expects a standard macOS/Linux POSIX userland, including `sh`,
`tar`, `mktemp`, file utilities, `awk`, `sed`, `grep`, `tr`, `stat`, and `id`.
Official payload verification requires either `sha256sum` or `shasum`; online
sources require either `curl` or `wget`. In default `auto` mode, `gpg` and
`gpgv` are optional and enable signed-manifest verification. Both are required
for strict `--verify gpg`.

## Default paths and scopes

| Scope | Core command bin | Installed app command bin | TAFFISH home |
| --- | --- | --- | --- |
| user | `~/.local/bin` | `~/.local/share/taffish/bin` | `~/.local/share/taffish` |
| system | `/usr/local/bin` | `/usr/local/bin` | `/opt/taffish` |

The installer scope is not a persistent CLI mode. Scope-aware `taf` commands
still default to user scope on each later invocation. Administrators must use
`--system` when reading or maintaining system state, for example:

```sh
sudo taf update --system
taf search --system fastqc
sudo taf install --system fastqc
taf list --system
```

User installs require both user command directories in `PATH`:

```sh
export PATH="$HOME/.local/bin:$HOME/.local/share/taffish/bin:$PATH"
```

On shared servers that use Apptainer, a system install makes the commands
available to all users, but first-run SIF image caching still needs a writable
directory. A newly created system SIF directory uses administrator-managed
`0755`; an existing directory keeps its current mode. Ordinary installation
does not make the cache writable by every user. Administrators can pre-cache
common images with `sudo`, keep per-user caches, or explicitly request a sticky
shared cache during installation:

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh \
  | sudo sh -s -- --system --shared-sif-cache
```

`--shared-sif-cache` changes only `<TAFFISH_HOME>/images/sif` to exact mode
`1777` and verifies the resulting mode. Use it only when a shared writable
cache is acceptable on a trusted host. It does not recursively change the rest
of `/opt/taffish`. The equivalent long form is
`--sif-cache-policy shared`.

The installer respects these environment variables:

```text
TAFFISH_USER_HOME
TAFFISH_SYSTEM_HOME
TAFFISH_SYSTEM_BIN_DIR
```

When a custom user home is selected, add its `bin` subdirectory to `PATH`.
When custom system paths are selected, persist the same
`TAFFISH_SYSTEM_HOME`/`TAFFISH_SYSTEM_BIN_DIR` values for administrators and
users.

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
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --version 0.11.0 --user
```

For an offline install, use the install script and original tarball from the same
release tag. The [offline instructions](../README.md#local-or-offline-install)
show how to verify the signed payload and skip the online index update.

Install from an explicit URL:

```sh
sh install/install-taffish.sh --user --url https://example.org/taffish.tar.gz
```

Default mode (without `--archive`/`--url`) downloads:

- `taf-<os>-<arch>-<version>`, `taffish-<os>-<arch>-<version>`, and `taffish-mcp-<os>-<arch>-<version>` from `target/` under `v<version>`
- completion and vim files from the same tag

Use `--provider github|gitee` or `--raw-base-url` to select another raw source.
Use `--share-url` to override the completion/vim source with a tar.gz archive.
Use `--taf-url` / `--taffish-url` / `--taffish-mcp-url` to override binary asset URLs.
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
--verify auto|sha256|gpg|none
--checksum-file FILE / --checksum-url URL
--signature-file FILE / --signature-url URL
--release-key-file FILE / --release-key-url URL
--retry COUNT
--connect-timeout SEC
--config-profile github|china|none
--force-config
--force
--sif-cache-policy auto|private|admin|shared
--shared-sif-cache
--dry-run
--os OS
--arch ARCH
--no-update
--no-doctor
```

Use `--dry-run` to resolve scope, paths, provider, version, verification mode,
and SIF policy without network access or filesystem writes.

The installer validates archive paths and entry types before extraction,
refuses to overwrite an unrelated core command unless `--force` is explicit,
uses a per-home install lock, smoke-tests all candidate binaries, and commits
the core binary set transactionally. A failed replacement restores the previous
binary set and receipt. Reinstalling identical binaries does not replace the
core binary files again; receipt and post-install readiness work may still run.

After a successful core commit, the installer writes
`<TAFFISH_HOME>/install-receipt.toml` with the installed version, scope, source
kind, actual verification level, SIF policy, selected asset names, and SHA256
values. It intentionally does not record download URLs, credentials, tokens, or
passwords.

An existing receipt must be a regular file. The installer refuses a symlink at
the receipt path, including a dangling symlink, during both installation and reinstallation.

`taf update` is attempted by default after installation. If it fails because
of network problems, the installer prints a warning but does not roll back the
installation.

For system installs, post-install initialization uses system scope explicitly:
`taf doctor --init --system`, optional `taf config init --system`, and
`taf update --system`.

The installer does not edit shell rc files or vim configuration files. It
prints the installed completion and vim paths so users can enable them
explicitly. See [the completion guide](../completion/README.md) and
[the Vim guide](../vim-highlight/README.md).

## Testing The Installer

Run the installer conformance suite from a complete repository checkout with
the versioned binaries for the current platform under `target/`:

```sh
./test/run-tests.sh --version 0.11.0 --filter installer/
```

The ten cases cover test-fixture contracts, template drift and dry-run behavior,
checksum and GPG verification, checksum failure modes, unsafe archive rejection,
raw/custom URL sources, collision and lock handling, transactional rollback,
post-install warning boundaries, idempotent binary replacement, and SIF cache
policy. They use isolated temporary directories and local fixtures; they do not
install into the real user/system TAFFISH home or contact GitHub/Gitee.

The separate GPG case uses the complete official manifest and signature
unchanged, together with the selected platform's binaries. It checks successful
strict/automatic GPG verification and rejection of tampered materials, an
untrusted key, and missing signature/key materials in strict mode. Failure must
not change a fresh destination or an existing installation.

It requires `gpg`, `gpgv`, and matching signed release materials. Missing tools
or materials, or an explicitly selected unsigned local build, report `[SKIP]`
and a separate count; invalid release data fails rather than skips. Require the
GPG case to pass before release (an all-skipped run fails):

```sh
./test/run-tests.sh --version 0.11.0 --filter installer/gpg-verification
```

Independently verify the final manifest and signature as well. See the
[External Test Guide](../test/README.md) for prerequisites and coverage limits.

For unsuffixed local builds, select the binaries explicitly:

```sh
./test/run-tests.sh \
  --taf ./target/taf \
  --taffish ./target/taffish \
  --taffish-mcp ./target/taffish-mcp \
  --filter installer/
```

A normal user run checks user installation and rejection of unauthorized
`--system` mutation. The administrator-only `0755`/sticky-`1777` branches need
one additional root run, which still targets only the suite's temporary tree:

```sh
sudo ./test/run-tests.sh \
  --version 0.11.0 \
  --filter installer/system-permissions
```

Run the non-root installer suite on both macOS and Linux release platforms.
Before release, also run the full delivered-binary suite without a filter.

## Upgrade and removal

Re-run the installer with the same scope and a selected `--version` to upgrade
the three core binaries. `taf upgrade` upgrades taf-apps only.

There is currently no dedicated core uninstaller. Uninstall unwanted apps
with the matching scope first, preserve any customized `config.toml`, then
remove the three core command files and the corresponding TAFFISH home only
after confirming that no app, index, log, or cached image data is needed.
