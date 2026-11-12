# Development Workflow And Maintenance Rules

This page records the basic workflow for maintaining TAFFISH source code. It is not a user installation tutorial and not a test report.

## Locate The Layer First

Before changing code, decide which layer the request belongs to:

| Requirement type | Preferred location |
| --- | --- |
| Human language resolution, catalogs, and fallback | `taffish-i18n` |
| TAF syntax, argument binding, compile output | `taffish-core` |
| `taffish` command-line arguments and output format | `taffish-cli` |
| Project creation, checking, build, run, publish | `taf-core/project/` |
| Hub index, search, install, uninstall, lookup | `taf-core/hub/` |
| TAFFISH home, config, history, diagnostics | `taf-core/system/` |
| `taf` subcommand dispatch and CLI text | `taf-cli` |
| Conservative structured AI access | `taffish-mcp` |
| Cross-module base capabilities | `vendor/han` |

If a change seems to touch many layers at once, first check whether responsibilities are unclear. One of TAFFISH's most important maintenance principles is: keep the language core clean, and keep upper ecosystem logic in `taf-core`.

## Recommended Reading Paths

When working on `taffish-core`, read in this order:

```text
package.lisp
model.lisp
lexer.lisp
parser.lisp
input.lisp
binder.lisp
emitter/model.lisp
emitter/registry.lisp
emitter/builtins/*.lisp
compiler.lisp
main.lisp
```

When working on `taf-core`, first read:

```text
package.lisp
project/common.lisp
system/home.lisp
system/config.lisp
```

Then enter the relevant subsystem, such as `project/check.lisp` or `hub/info.lisp`.

## Self-Check After Changes

After each change, ask at least:

1. Does this change alter a public API?
2. Does it alter the `.taf` to shell output contract?
3. Does it alter the format or defaults of `taffish.toml`, Hub index, or config?
4. Should README, completion, install scripts, or docs be updated?
5. Does it affect GitHub and Gitee mirror scenarios?
6. Does it accidentally translate or otherwise change JSON, generated shell,
   command tokens, MCP schemas, or other machine interfaces?

## Testing Notes

The Common Lisp unit suite is the first implementation check:

```sh
sbcl --load load-taffish.dev.lisp \
  --eval '(multiple-value-bind (passed failed) (han.test:run-all-tests) (declare (ignore passed)) (when (> failed 0) (sb-ext:exit :code 1)))' \
  --quit
```

For changes to CLI behavior, generated shell, project or Hub workflows, processes, or delivered programs, build the three commands from the repository root and test those executables explicitly.

```sh
./test/run-tests.sh \
  --taf ./target/taf \
  --taffish ./target/taffish \
  --taffish-mcp ./target/taffish-mcp
```

Verify host, process, path and stream changes on macOS/SBCL and Linux/LispWorks. Public CI for 0.12.0 also builds and tests the three CCL commands on Apple Silicon macOS. Maintainers validate the proprietary LispWorks build on Linux separately.

The runner infers the version from `taffish.asd` and isolates host state. For changes to entry points or error reporting, append `--filter cli-boundary/` to the same command to run the focused regressions. [External test guide](../../../test/README.md)

These regressions check startup failures, compiler diagnostics, unusable output streams,
interrupts, and MCP recovery. Probes keep a controlling terminal open and enforce
a timeout. Closed descriptor numbers can be reused during runtime startup, so
write-failure tests must use a reliable fixture such as a read-only descriptor
or a broken pipe, not assume that closing stdout/stderr guarantees failure.

## Release Evidence

For 0.12.0, follow the [build guide](build-from-source.md) to verify the signed archive manifest, install the native package in strict GPG mode and run the full external suite on the three installed programs. Test the same-prefix upgrade from 0.11.0 on both platforms. Record the platform, executable digests, test results and installation receipts in the release acceptance record.

Distribute executable and archive checksums with their respective signed manifests. Keep the public Release body focused on user-visible changes and upgrade notes. Verify CI on the candidate commit before tagging. After publication, test installation from the actual GitHub and Gitee tags.

## Documentation Sync

When adding files or changing module responsibilities, update:

1. [ASDF System And Module Map](01-asdf-system-map.md)
2. The corresponding module README
3. Related standard documents

If the change is only an internal implementation improvement, it may be enough to add a note in the corresponding module's "Implementation Notes" or "Modification Guide".

## Documentation Publication Status

`docs/` is part of the public source repository. Treat it as a maintained contract surface: avoid private notes, stale temporary judgments, and unpublished research or collaboration details. When behavior changes, update the relevant developer, standards, or architecture document in the same change set.
