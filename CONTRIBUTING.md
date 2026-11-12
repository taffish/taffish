# Contributing To TAFFISH

Thank you for considering a contribution. TAFFISH is still in the `0.x` stage, so design feedback and small, well-tested patches are especially useful.

## Development Setup

Load the development system:

```sh
sbcl --load load-taffish.dev.lisp
```

Run the test suite:

```sh
sbcl --load load-taffish.dev.lisp \
  --eval '(multiple-value-bind (passed failed) (han.test:run-all-tests) (han.host:quit (if (and (plusp passed) (zerop failed)) 0 1)))' \
  --quit
```

If a change affects CLI behavior, generated shell, project/Hub/system workflows,
process handling, or delivered binaries, also build the three commands and run
the external suite against that build:

```sh
build_dir=$(mktemp -d)
sh test/ci-build.sh "$build_dir"
test/run-tests.sh --taf "$build_dir/taf" --taffish "$build_dir/taffish" --taffish-mcp "$build_dir/taffish-mcp"
```

See [TAFFISH External Tests](test/README.md) for binary selection, filtering,
temporary-state isolation, and the current suite boundaries.

Build local binaries:

```sh
sbcl --load load-taffish.lisp --compile
```

The 0.12.0 release configuration uses SBCL built without core compression on Apple Silicon and LispWorks on Linux x86-64. CCL and ECL remain available for development and compatibility testing.
The source tree includes Han Lisp 0.3.0. See [Build From Source](docs/dev/en/build-from-source.md) for the CCL, ECL, SBCL, and LispWorks commands.

## Patch Expectations

Before proposing a change, please try to run:

```sh
git diff --check
install/generate-installers.sh --check
sh -n install/install-taffish.template.sh
sh -n install/install-taffish.sh
sh -n install/install-taffish.gitee.sh
bash -n install/install-taffish.sh
bash -n install/install-taffish.gitee.sh
bash -n completion/bash/taf
bash -n completion/bash/taffish
zsh -n completion/zsh/_taf
zsh -n completion/zsh/_taffish
fish -n completion/fish/taf.fish
fish -n completion/fish/taffish.fish
```

If you changed Lisp code, run the Common Lisp suite. If you changed shell
completion, validate the relevant shell syntax when that shell is available.
Check changes to host, process, path, or stream behavior with the macOS/SBCL
and Linux/LispWorks release builds, and retain CCL/ECL compatibility coverage for affected paths.

Changes to the installer template, generator, download/verification behavior,
transaction handling, paths, or permissions must also pass:

```sh
qa=$(mktemp -d)
bash test/ci-release-payloads.sh "$qa/release"
test/run-tests.sh --target-dir "$qa/release/target" --filter installer/
```

Run that subset on both macOS and Linux. The root-only system permission branch
can be exercised with `sudo test/run-tests.sh --target-dir "$qa/release/target" --filter installer/system-permissions`.
It uses an isolated temporary tree. Regenerate both provider scripts from the template.

## Code Boundaries

TAFFISH is intentionally layered:

- `vendor/han`: small portability and utility foundation;
- `taffish-i18n`: human-language selection, catalogs, and safe fallback;
- `taffish-core`: TAF language compiler core;
- `taffish-cli`: compiler CLI entrypoint;
- `taf-core`: project, Hub, system, config, history, and install logic;
- `taf-cli`: user-facing `taf` CLI entrypoint;
- `taffish-mcp`: conservative MCP interface for AI clients.

Please keep implementation-specific Common Lisp APIs behind `han.host` where possible. Production code should not directly depend on SBCL-only or LispWorks-only APIs outside the portability layer and loader code.

## Documentation

If a change modifies user-visible behavior, update the README or the relevant docs under `docs/`. If a change modifies internal module responsibility or public package exports, update the corresponding developer documentation.

## Release Artifacts

Do not commit ad hoc local build outputs unless they are part of the intentional versioned release payload under `target/`. Release binaries, checksums, and signatures are prepared by the maintainer for now.
