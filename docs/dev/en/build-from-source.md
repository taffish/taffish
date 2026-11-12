# Build From Source

This page explains how to build TAFFISH from the source repository. Most users should install the prebuilt binaries from the root README; source builds are mainly for contributors, maintainers, packagers, and users who need to inspect or modify the implementation.

## Components

The repository builds three command-line entrypoints:

| Command | Role |
| --- | --- |
| `taffish` | Compile `.taf` source into shell code. |
| `taf` | Manage TAFFISH projects, local Hub packages, config, history, and diagnostics. |
| `taffish-mcp` | Expose conservative MCP tools/resources/prompts for AI clients. |

The main ASDF system is `taffish`. The development/test system is `taffish.dev`.

## Requirements

Minimum source-build requirements:

```text
Common Lisp implementation
POSIX shell tools
Git
```

Maintainer builds by release

| Platform | 0.11.0 | 0.12.0 preparation |
| --- | --- | --- |
| macOS Apple Silicon | SBCL, with Homebrew `zstd` at runtime | SBCL without core compression, distributed as `.tar.xz` |
| Linux x86_64 | LispWorks | LispWorks, distributed as `.tar.gz` |

The official 0.12.0 Apple Silicon package requires macOS 15 or later. The system `tar` can unpack its archive. The current SBCL build without core compression links only macOS system libraries and does not need Homebrew `zstd`. The Linux installer requires `tar` and `gzip`. Installing the prebuilt commands requires no Lisp installation. Maintainers need LispWorks to reproduce the Linux release build. CCL and ECL development builds remain available. Before each release, verify the final signed packages, clean installation and upgrade from the previous release on both platforms.

## Load For Development

The checkout includes [Han Lisp 0.3.0](han/README.md), the portability library used across the supported Lisp implementations. The build loads this copy automatically.

Load the development system:

```sh
sbcl --load load-taffish.dev.lisp
```

Run the full test suite in the loaded Lisp image:

```lisp
(han.test:run-all-tests)
```

Run the TAFFISH unit suite with the implementation under test. Both examples return a failure status for an empty suite or a failed test. To test Han independently, start a fresh process with the same command and load `vendor/han/load-han.dev.lisp` instead.

```sh
ccl --no-init --batch --quiet --load load-taffish.dev.lisp \
  --eval '(multiple-value-bind (passed failed) (han.test:run-all-tests) (han.host:quit (if (and (plusp passed) (zerop failed)) 0 1)))'

sbcl --no-userinit --no-sysinit --disable-debugger --load load-taffish.dev.lisp \
  --eval '(multiple-value-bind (passed failed) (han.test:run-all-tests) (han.host:quit (if (and (plusp passed) (zerop failed)) 0 1)))'
```

## Developer builds with ECL or Clozure CL

macOS CCL development builds have an unresolved intermittent native crash. Use the official SBCL package when you need the release build.

From the repository root, run the command for your implementation. The `--` after the loader filename passes the following option to TAFFISH.

```sh
# Clozure CL
ccl --load ./load-taffish.lisp -- --compile

# ECL
ecl -shell ./load-taffish.lisp -- --compile
```

Both commands build `target/taf`, `target/taffish` and `target/taffish-mcp` beside the loader. To build one executable, replace `--compile` with `--compile-taf`, `--compile-taffish` or `--compile-taffish-mcp`. Building again, including with a different implementation, replaces the selected executables at those paths. If your CCL installation has no `ccl` launcher on PATH, invoke its executable by path (for example, `darm64cl` on Apple Silicon).

ECL builds require Unicode ECL, a C compiler, headers and a linker. CCL builds require a 64-bit installation. The project uses ECL 26.5.5 and CCL 1.14 on macOS arm64 and Linux x86-64. To keep builds from different implementations side by side, the existing shell command accepts a separate output directory for each build.

```sh
work=$(mktemp -d)
sh scripts/build-from-source.sh ecl "$work/ecl"
"$work/ecl/bin/taf" --version

# With Clozure CL installed:
sh scripts/build-from-source.sh ccl "$work/ccl"
"$work/ccl/bin/taffish-mcp" --version
```

The script finds `ecl` or `ccl` on PATH. Set `ECL` or `CCL` to the executable path to choose another installation. Both builds write `bin/taf`, `bin/taffish` and `bin/taffish-mcp` under the requested directory. Choose a new or empty directory outside the checkout, with an existing parent. Each build uses a private compilation cache.

ECL development executables use the runtime libraries supplied by the local ECL installation. On the tested macOS setup, keep `libecl` and GMP available at their installed locations when running a built command. CCL saves its kernel and application image together. End users can install the official binaries for their platform as usual.

To build and run the focused regressions in one step, choose another empty directory. These also exercise overlapping `taf run` processes sharing a TMPDIR, including cleanup after a nonzero exit:

```sh
sh test/source-build.sh ecl "$work/ecl-check"
# Substitute ccl as the first argument to test Clozure CL.
```

For the full external suite, pass the three resulting executables explicitly:

```sh
bin="$work/ecl-check/bin"
sh test/run-tests.sh --taf "$bin/taf" --taffish "$bin/taffish" --taffish-mcp "$bin/taffish-mcp"
```

## Build Binaries With SBCL

To reproduce the official macOS build without a zstd dependency, use SBCL built with `--without-sb-core-compression`. TAFFISH's `--compile` option does not remove dependencies from the SBCL runtime; an ordinary Homebrew build may still require zstd. Check the resulting executables with `otool -L`.

Build the three executable entrypoints into `target/`:

```sh
sbcl --load load-taffish.lisp --compile
```

Expected local build outputs:

```text
target/taf
target/taffish
target/taffish-mcp
```

Check the generated commands:

```sh
./target/taf --version
./target/taffish --version
./target/taffish-mcp --version
```

These unsuffixed files are local build outputs. Maintainer release payloads are
renamed/copied to versioned file names such as
`taf-darwin-arm64-0.12.0` before signing and packaging.

## Binary Smoke Test

To exercise the signed platform package from this checkout, first prepare the installed files:

```sh
scratch=$(mktemp -d)
bash test/ci-release-payloads.sh "$scratch/release"
test/binary-smoke.sh --target-dir "$scratch/release/target"
```

For unsuffixed local build outputs, pass explicit paths:

```sh
test/binary-smoke.sh \
  --taf ./target/taf \
  --taffish ./target/taffish \
  --taffish-mcp ./target/taffish-mcp
```

The smoke test checks `--version`, compiles and runs a minimal shell TAF,
creates/checks/compiles a minimal `taf` project, and verifies basic MCP
JSON-RPC startup/tool discovery. It also verifies container runtime-argument
compilation paths without pulling images or running containers.

For the fuller external test suite, run:

```sh
test/run-tests.sh --target-dir "$scratch/release/target"
```

This wraps the binary smoke test and adds real `taffish` conformance cases plus
project, Hub, system, i18n, MCP, publish-recovery, and installer conformance.

Run only the standalone installer cases with:

```sh
test/run-tests.sh --target-dir "$scratch/release/target" --filter installer/
```

Run the subset on both macOS and Linux. A normal user run verifies user scope
and rejection of unauthorized system mutation. The root-only administrator and
sticky shared-cache branches use temporary paths and can be selected with:

```sh
sudo test/run-tests.sh \
  --target-dir "$scratch/release/target" \
  --filter installer/system-permissions
```

Installer maintainers must also run `install/generate-installers.sh --check`
and the syntax/static checks documented in
[the installer manual](../../../install/README.md).

## Build Binaries With LispWorks

LispWorks builds use the same loader entrypoint:

```sh
lispworks -build load-taffish.lisp --compile
```

The loader creates the three unsuffixed entrypoints under `target/`:

```text
target/taf
target/taffish
target/taffish-mcp
```

If your LispWorks executable has a different command name or path, invoke that executable directly. Building with LispWorks requires your own licensed development environment. The official Linux executables include its runtime under the [TAFFISH Linux runtime terms](../../../licenses/LISPWORKS-RUNTIME.txt).

## Packaging a platform release

The published 0.11.0 tag carries six individual executables and their signed `SHA256SUMS`. The 0.12.0 packaging configuration uses SBCL built without core compression on macOS arm64 and LispWorks on Linux amd64. Run each program's `--version` on its native platform and verify its runtime dependencies before signing. Keep the version in the source and the default in the installer template in sync, then regenerate both installers.

Place the release public key `TAFFISH-RELEASE-KEY.asc` and the six executables in `target/`. Name each executable `<program>-<platform>-<version>`, for example `taf-darwin-arm64-0.12.0`. From the repository root, run the unified signing and packaging entrypoint:

```sh
cd target
./make-sha-asc.sh
```

The script detects the version from the six filenames, writes and signs `SHA256SUMS`, verifies the release key and executable digests, then creates both platform archives in `packages-0.12.0/`. An existing valid signature for the same manifest is reused, and packaging still proceeds. When several versions are present, select one with `./make-sha-asc.sh VERSION`. No separate `package-release.sh` step is needed.

The macOS archive also produces 8 MiB transport parts (`.part-aa`, `.part-ab`, etc.) and an ordered `.parts` checksum list for Gitee. Linux remains one `.tar.gz`. The complete macOS archive is retained for GitHub and local installation; splitting does not change its bytes or existing signatures. To add parts to an already signed archive without rebuilding or signing, run from `target/`:

```sh
./make-sha-asc.sh --split-only packages-0.12.0/taffish-0.12.0-darwin-arm64.tar.xz
```

Existing parts or manifests are never overwritten. The `.parts` list is transport metadata, not a replacement for the signed full-archive checksum. Packaging uses the standard `split` utility; installation joins parts with `cat`.

The output contains the macOS `.tar.xz`, Linux `.tar.gz`, outer manifest `ARCHIVE-SHA256SUMS`, release public key and a second `make-sha-asc.sh` for signing the archives. Each archive includes its three executables, the shared six-program manifest and signature, public key, completions, Vim files and license notices. The macOS archive includes `licenses/SBCL-NOTICES.txt`; the Linux archive includes `licenses/LISPWORKS-RUNTIME.txt`. Both archives must be rebuilt when the shared inner manifest or signature changes, even if only the macOS executables were replaced.

Signing uses an installed UTF-8 locale for GPG and Pinentry; checksum processing uses the C locale. Packaging uses `sh`, `tar`, `shasum`, `gpg` and `gpgv`. The macOS system tar compresses both formats directly. Hosts using GNU tar also need `xz` and `gzip`.

An existing output directory is never overwritten. Preserve previous packages in a separate evidence directory before preparing the same version again, or pass a new output path. Signing failures preserve the previous inner manifest and signature and stop before packaging. If compression fails after signing, the valid inner signature remains available and no partial package directory is published.

For recovery or automation, the same script supports separate stages:

```sh
# Sign the program manifest only.
./make-sha-asc.sh --sign-only

# Reuse the signed manifest and retry packaging only.
./make-sha-asc.sh --package-only

# Use separate inputs and a new output directory.
./make-sha-asc.sh "$version" "$payload_dir" "$output_dir"
```

The optional version precedes any custom directory arguments. An explicit output directory must be outside the source and input directories, under an existing parent. `--sign-only` accepts a version and input directory, but no output directory. The older `scripts/package-release.py` interface delegates to `--package-only`; it does not sign the programs. When only accompanying notices change, reuse the verified programs and inner signature with `--package-only`, then sign the new outer manifest.

Enter the output directory and run its generated signing script. It checks both archives against `ARCHIVE-SHA256SUMS`, then uses the release key to create `ARCHIVE-SHA256SUMS.asc`. It stops if that signature already exists and preserves the file. An old outer signature applies only to its original manifest.

```sh
cd packages-0.12.0
./make-sha-asc.sh
```

Publish the two archives, macOS `.parts` manifest and every listed `.part-*` file, `ARCHIVE-SHA256SUMS`, `ARCHIVE-SHA256SUMS.asc` and `TAFFISH-RELEASE-KEY.asc` directly from `target/packages-<version>/` under the same tag on GitHub and Gitee. The signing helper stays local.

Once the release payload is staged in the checkout, run `bash test/ci-release-payloads.sh "$new_test_dir"` from the repository root on each platform, followed by `test/run-tests.sh --target-dir "$new_test_dir/target"`. Use a fresh test directory with an existing parent. Verify an upgrade from the published 0.11.0 on the same prefix, then check anonymous downloads from both tagged sources after publication. [Installer instructions](../../../install/README.md)

## Current Public API Boundary

`compile-taf-program` is not a finished public API. The stable user-facing compiler path is the `taffish` command and the source/file compile tools exposed by `taffish-mcp`. Treat lower-level experimental entrypoints as implementation details unless their module docs explicitly mark them stable.
