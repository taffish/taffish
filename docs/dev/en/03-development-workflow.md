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

If a change affects CLI behavior, generated shell, project/Hub/system workflows,
process handling, or delivered binaries, build the three commands and run:

```sh
./test/run-tests.sh
```

The external runner infers the current version from `taffish.asd`, isolates
host state, and exercises binary smoke, compiler, project, Hub, system, i18n,
MCP, publish-recovery, installer, and CLI error-boundary suites. See the
[External Test Guide](../../../test/README.md) for filters, explicit binary
paths, root-only installer policy cases, and prerequisites.

Host/process/path/stream changes require both macOS/SBCL and Linux/LispWorks
verification. LispWorks delivery remains a maintainer release gate because the
proprietary runtime is not available in public CI.

For entry-point or error-reporting changes, the targeted delivered-binary check is:

```sh
./test/run-tests.sh --filter cli-boundary/
```

It checks startup failures, compiler diagnostics, unusable output streams,
interrupts, and MCP recovery. Probes keep a controlling terminal open and enforce
a timeout. Closed descriptor numbers can be reused during runtime startup, so
write-failure tests must use a reliable fixture such as a read-only descriptor
or a broken pipe, not assume that closing stdout/stderr guarantees failure.

## Release Evidence

Tests against a temporary build do not validate a later release binary. After
rebuilding the versioned payload, run the full external suite on each target
platform, then verify the final checksum manifest and its signature. Keep
version-specific counts and checksums in the release notes, not in general usage
documentation. A documentation-only correction does not require rebuilding an
unchanged binary or replacing its valid signature.

When binaries are built on separate machines, collect the tested artifacts in
one authoritative release directory and verify its complete signed manifest.
Build-machine copies need not serve as distribution bundles; compare artifact
hashes to the authoritative directory rather than treating an old checksum copy
on a build machine as a defect in the release bundle.

Local test success, CI success, and publication are separate gates. Check the
release commit in CI before creating the tag and Release, then verify the actual
published GitHub/Gitee installation paths. Do not describe a mock transport test
as a real remote publication or an untested backend as verified.

## Documentation Sync

When adding files or changing module responsibilities, update:

1. [ASDF System And Module Map](01-asdf-system-map.md)
2. The corresponding module README
3. Related standard documents

If the change is only an internal implementation improvement, it may be enough to add a note in the corresponding module's "Implementation Notes" or "Modification Guide".

## Documentation Publication Status

`docs/` is part of the public source repository. Treat it as a maintained contract surface: avoid private notes, stale temporary judgments, and unpublished research or collaboration details. When behavior changes, update the relevant developer, standards, or architecture document in the same change set.
