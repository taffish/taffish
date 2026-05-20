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

Supported maintainer build paths at the current development release:

| Platform | Official binary build path | Notes |
| --- | --- | --- |
| macOS Apple Silicon | SBCL | The released macOS binary depends on Homebrew `zstd`. |
| Linux x86_64 | LispWorks | The released Linux binary is manually built with LispWorks. |

SBCL builds are suitable for development and local testing. LispWorks builds are used for the current Linux release payload because they produce a small runtime dependency surface. LispWorks is proprietary software; the public source repository does not include LispWorks itself.

## Load For Development

Load the development system:

```sh
sbcl --load load-taffish.dev.lisp
```

Run the full test suite in the loaded Lisp image:

```lisp
(han.test:run-all-tests)
```

A non-interactive SBCL test run:

```sh
sbcl --load load-taffish.dev.lisp \
  --eval '(han.test:run-all-tests)' \
  --quit
```

## Build Binaries With SBCL

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
`taf-darwin-arm64-0.10.0` before publishing a release tag.

## Binary Smoke Test

After building or preparing release payloads, run the binary smoke test for the
current platform:

```sh
test/binary-smoke.sh --version 0.10.0
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
test/run-tests.sh --version 0.10.0
```

This wraps the binary smoke test and adds real `taffish` conformance cases plus
`taf new/check/compile/build` project workflow checks.

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

If your LispWorks executable has a different command name or path, invoke that executable directly. The repository does not vendor or redistribute LispWorks.

## Manual Release Payload

Maintainer releases keep manually built binary payloads in `target/` so the GitHub and Gitee raw installers can download files from immutable git tags.

The maintainer release payload includes:

```text
target/SHA256SUMS
target/SHA256SUMS.asc
target/TAFFISH-RELEASE-KEY.asc
```

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

This verifies the signed checksum manifest. It is not a reproducible-build claim and it is not GitHub Actions artifact attestation. Those can be added later when release binaries are produced by an automated pipeline.

## Current Public API Boundary

`compile-taf-program` is not a finished public API. The stable user-facing compiler path is the `taffish` command and the source/file compile tools exposed by `taffish-mcp`. Treat lower-level experimental entrypoints as implementation details unless their module docs explicitly mark them stable.
