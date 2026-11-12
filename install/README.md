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

## Versioned downloads

The **0.12.0** installers select one package for the host OS and architecture.
Both providers use `target/packages-<version>/` under the requested `v<version>`
tag for 0.12.0 and later. Selecting `--version 0.11.0` uses the individual
programs and share files from that tag. [0.12.0 release notes](../docs/releases/v0.12.0.md)

| Platform | File in the tag | Extraction |
| --- | --- | --- |
| Apple Silicon macOS 15 or later | `taffish-<version>-darwin-arm64.tar.xz` | System `/usr/bin/tar` with built-in XZ support |
| x86-64 Linux | `taffish-<version>-linux-amd64.tar.gz` | `tar` and `gzip` |

Default Gitee/macOS downloads use the adjacent `.tar.xz.parts` manifest and `.part-aa`, `.part-ab`, etc., each at most 8 MiB. The installer joins them in order, then verifies and extracts the original complete archive. The installation command stays the same; missing or invalid parts stop installation without falling back to GitHub. GitHub, Linux and explicit `--url` downloads continue to use complete archives. This accommodates [Gitee authentication for raw files larger than 10 MB](https://help.gitee.com/repository/file-operate/raw#认证).

### Local installation with 0.12.0 and later

Local installation consumes a complete archive, not a parts manifest. If you downloaded the Gitee parts manually, concatenate them in the order listed in `.parts` into the standard archive filename, keep the original archive checksum manifest, signature and public key beside it, then install locally.

<details>
<summary>Reassemble the two macOS parts for 0.12.0</summary>

In a directory containing both parts, their `.parts` manifest and the offline installation files:

```sh
shasum -a 256 -c taffish-0.12.0-darwin-arm64.tar.xz.parts &&
cat taffish-0.12.0-darwin-arm64.tar.xz.part-aa \
    taffish-0.12.0-darwin-arm64.tar.xz.part-ab > taffish-0.12.0-darwin-arm64.tar.xz &&
sh install-taffish.sh --local --verify gpg
```

The `.parts` checksums detect damaged parts; authenticity still depends on the original signed archive manifest and pinned release key. This example is for 0.12.0's two parts; later versions may have a different count. Normal online installation performs reassembly automatically.

</details>

From a checkout containing the platform package and its verification files, run:

```sh
sh install/install-taffish.sh --local
```

User scope is the default. For a system install, use `sudo sh install/install-taffish.sh --local --system`.
`--local` looks for the standard filename beside the installer first, then in
`../target/packages-<version>/` relative to the installer. It skips the post-install
`taf update` and rejects remote download options.

For a portable offline copy, put the installer from the same version beside the
platform package. Keep `ARCHIVE-SHA256SUMS`, `ARCHIVE-SHA256SUMS.asc` and
`TAFFISH-RELEASE-KEY.asc` in the package directory. Run `sh install-taffish.sh --local --verify gpg`.
If you moved or renamed the archive, select it explicitly:

```sh
sh install-taffish.sh --local --archive /path/to/my-package --verify gpg
```

This path takes priority over discovery. Verification uses the official manifest entry
for the requested version and platform even when the local filename differs. Use
`--version` to select a version other than the installer's default. For traditional or
custom bundles, the existing `--archive FILE` mode remains available.

For online use, `--url` accepts the full URL of a standard platform package and
fetches its verification files from the same directory. The installer verifies the archive against
`ARCHIVE-SHA256SUMS` before extracting it and checks all three programs
against the package's `target/SHA256SUMS` before installation. `--verify gpg`
requires both manifests to have a valid signature from the pinned release key.
`--checksum-*` and `--signature-*` override the inner program verification
materials. For the outer manifest, its signature and the public key, see the
[0.12.0 package directory](../target/packages-0.12.0/). Maintainers can follow the
[source build guide](../docs/dev/en/build-from-source.md).

Bundle layout for the programs and share files:

```text
target/
  taf-<os>-<arch>-<version>
  taffish-<os>-<arch>-<version>
  taffish-mcp-<os>-<arch>-<version>
  SHA256SUMS
  SHA256SUMS.asc
  TAFFISH-RELEASE-KEY.asc
completion/
  bash/
  zsh/
  fish/
vim-highlight/
  syntax/
  ftdetect/
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
- a package selected with `--local` or identified by its standard platform name requires both checksum manifests
  in `auto` mode, including on a mirror or with `--archive`. Other custom
  bundles and explicit binary URLs can report an unverified installation when
  their program manifest is unavailable;
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

### Release verification

To install one official archive offline, obtain the installer through a trusted channel, keep the verification files beside the archive and run `sh install-taffish.sh --local --verify gpg`. The installer pins the release key and verifies both the archive and program manifests.

To independently check both downloaded archives, start in their directory and display the public key fingerprint.

```sh
gpg --show-keys --fingerprint TAFFISH-RELEASE-KEY.asc
```

Compare the primary fingerprint with a trusted copy of the TAFFISH release fingerprint, `F863 33E6 0BD6 74F1 59A5  651A B919 3F30 C424 7BB2`. Once they match, verify the signature and then both archive hashes. On Linux you can use `sha256sum -c ARCHIVE-SHA256SUMS` for the last step.

```sh
keydir=$(mktemp -d)
gpg --batch --dearmor --output "$keydir/release.gpg" TAFFISH-RELEASE-KEY.asc
gpgv --keyring "$keydir/release.gpg" ARCHIVE-SHA256SUMS.asc ARCHIVE-SHA256SUMS
shasum -a 256 -c ARCHIVE-SHA256SUMS
```

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
[language configuration guide](../docs/standards/en/localization.md#external-locale-packs).

## Requirements

The installer expects a standard macOS/Linux POSIX userland, including `sh`,
`tar`, `mktemp`, file utilities, `awk`, `sed`, `grep`, `tr`, `stat`, and `id`.
Official payload verification requires either `sha256sum` or `shasum`; online
sources require either `curl` or `wget`. In default `auto` mode, `gpg` and
`gpgv` are optional and enable signed-manifest verification. Both are required
for strict `--verify gpg`.

The prebuilt commands include Han Lisp 0.3.0. The Apple Silicon build uses
SBCL 2.4.9 with core compression disabled and links only to macOS system libraries;
it does not require Homebrew or `zstd`. The Linux build
uses LispWorks. Neither platform requires users to install a Lisp implementation.

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

To pin both the installer and the package, use the script from the 0.12.0 tag.

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/v0.12.0/install/install-taffish.sh | sh -s -- --version 0.12.0 --user
```

The corresponding pinned Gitee command uses the same tag.

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/v0.12.0/install/install-taffish.gitee.sh | sh -s -- --version 0.12.0 --user
```

For an offline 0.11.0 install, use the original source tarball and installer from the same tag. On macOS, if Gitee requests a login for the large individual 0.11.0 binaries, use its tag archive. [0.11.0 offline instructions](https://github.com/taffish/taffish/blob/v0.11.0/README.md#local-or-offline-install)

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/v0.11.0/install/install-taffish.gitee.sh \
  | sh -s -- --user --version 0.11.0 --verify gpg \
    --url https://gitee.com/taffish-org/taffish/repository/archive/v0.11.0.tar.gz
```

Install from an explicit URL:

```sh
sh install/install-taffish.sh --user --url https://example.org/taffish.tar.gz
```

The GitHub and Gitee installers default to `taffish/taffish` and
`taffish-org/taffish`, respectively. When switching providers manually, set
both `--provider` and `--repo`. A mirror can supply its fixed-tag root through
`--raw-base-url`. `--os` and `--arch` override platform detection. In default download
mode, `--share-url` supplies a separate completion/Vim archive. Explicit
`--archive` and `--url` install the share files from the selected bundle.
Any of `--taf-url`, `--taffish-url`, or `--taffish-mcp-url` selects
individual-file mode. Supply the other binary URLs too, or point
`--raw-base-url` to a mirror that provides the remaining individual files.

## Runtime licenses

The official archives include TAFFISH's Apache 2.0 license, Han's MIT license and
the runtime text for their platform. Installation places them in
`<TAFFISH_HOME>/share/licenses/` as `TAFFISH-LICENSE.txt`, `HAN-LICENSE.txt`,
and either `SBCL-NOTICES.txt` or `LISPWORKS-RUNTIME.txt`.

The macOS SBCL file contains the applicable copyright and permission notices.
The Linux file contains the terms for the proprietary LispWorks runtime within
the three programs. LispWorks Professional permits this application delivery;
end users can run TAFFISH without purchasing or installing LispWorks.
TAFFISH source and separately licensed open-source components use their own licenses.
[SBCL notices](../licenses/SBCL-NOTICES.txt) · [Linux runtime terms](../licenses/LISPWORKS-RUNTIME.txt)

To read the text from a local package before installing it, run:

```sh
sh install/install-taffish.sh --local --show-runtime-license
```

This verifies the selected package and its program checksums, displays its
runtime text and exits before executing the programs or writing an installation.
Add `--verify gpg` for strict signature verification. For an online download,
omit `--local`; source, version and verification options apply as usual.

On Linux, an ordinary interactive installation displays the terms on the
controlling terminal and asks you to type `yes`. Declining or reaching EOF stops
the installation. When installing from a script or in CI, read the terms first
and pass the explicit acceptance option:

```sh
sh install/install-taffish.sh --local --accept-runtime-license
```

The option also works with `--user`, `--system` and online installation.
Each Linux installation or upgrade asks for acceptance of its selected text.
Without a controlling terminal, the explicit option is required. The receipt
records `runtime_license_file`, `runtime_license_sha256` and
`runtime_license_acceptance` (`flag` or `terminal`).
For a shared installation, arrange for its users to read and accept the runtime
terms, or accept on their behalf when authorized. macOS requires no runtime
acceptance. Older and custom bundles follow their included licensing materials.

## Useful Options

```text
--user
--system
--prefix DIR
--version VERSION
--local
--archive FILE
--url URL
--bin-dir DIR
--taffish-home DIR
--provider github|gitee
--raw-base-url URL
--verify auto|sha256|gpg|none
--show-runtime-license
--accept-runtime-license
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

A versioned platform package also records `archive_asset`, `archive_sha256`,
and `archive_verification`. The overall `verification` field reports the
lower of the archive and program verification levels.

An existing receipt must be a regular file. The installer refuses a symlink at
the receipt path, including a dangling symlink, during both installation and reinstallation.

Online installations attempt `taf update` by default. Local mode skips this step. If it fails because
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

From a checkout with the signed platform packages, prepare the native files in a fresh directory and run the installer subset:

```sh
scratch=$(mktemp -d)
bash test/ci-release-payloads.sh "$scratch/release"
./test/run-tests.sh --target-dir "$scratch/release/target" --filter installer/
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
./test/run-tests.sh --target-dir "$scratch/release/target" --filter installer/gpg-verification
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
  --target-dir "$scratch/release/target" \
  --filter installer/system-permissions
```

Run the non-root installer suite on both macOS and Linux release platforms.
Before release, also run the full delivered-binary suite without a filter.

## Upgrade and removal

Re-run the installer with the same scope and installation paths to upgrade the
three core commands. `taf upgrade` upgrades taf-apps only.

When upgrading the macOS 0.11.0 SBCL build, keep Homebrew's `zstd` in place
until the installer has identified the old commands and completed the upgrade.
Check that `taf --version`, `taffish --version`, and `taffish-mcp --version`
all report 0.12.0. The new SBCL commands start without Homebrew `zstd`.

There is currently no dedicated core uninstaller. Uninstall unwanted apps
with the matching scope first, preserve any customized `config.toml`, then
remove the three core command files and the corresponding TAFFISH home only
after confirming that no app, index, log, or cached image data is needed.
