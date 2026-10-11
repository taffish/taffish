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
  --eval '(multiple-value-bind (passed failed) (han.test:run-all-tests) (declare (ignore passed)) (when (> failed 0) (sb-ext:exit :code 1)))' \
  --quit
```

If a change affects CLI behavior, generated shell, project/Hub/system workflows,
process handling, or delivered binaries, also build the three commands and run
the external suite:

```sh
./test/run-tests.sh
```

See [TAFFISH External Tests](test/README.md) for binary selection, filtering,
temporary-state isolation, and the current suite boundaries.

Build local binaries:

```sh
sbcl --load load-taffish.lisp --compile
```

See [Build From Source](docs/dev/en/build-from-source.md) for more details, including the LispWorks maintainer build path.

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
Changes to host/process/path/stream behavior must be checked on both the
macOS/SBCL and Linux/LispWorks release paths before release.

Changes to the installer template, generator, download/verification behavior,
transaction handling, paths, or permissions must also pass:

```sh
./test/run-tests.sh --filter installer/
```

Run that subset on both macOS and Linux. The root-only system permission branch
is selected explicitly with `sudo ./test/run-tests.sh --filter
installer/system-permissions`; it uses an isolated temporary tree rather than
the real system installation paths. Generated provider scripts must not be
edited independently.

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
