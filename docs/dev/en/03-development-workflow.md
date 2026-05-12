# Development Workflow And Maintenance Rules

This page records the basic workflow for maintaining TAFFISH source code. It is not a user installation tutorial and not a test report.

## Locate The Layer First

Before changing code, decide which layer the request belongs to:

| Requirement type | Preferred location |
| --- | --- |
| TAF syntax, argument binding, compile output | `taffish-core` |
| `taffish` command-line arguments and output format | `taffish-cli` |
| Project creation, checking, build, run, publish | `taf-core/project/` |
| Hub index, search, install, uninstall, lookup | `taf-core/hub/` |
| TAFFISH home, config, history, diagnostics | `taf-core/system/` |
| `taf` subcommand dispatch and CLI text | `taf-cli` |
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

## Testing Notes

This manual records test entry points, but reading docs does not require running tests. Common development checks include:

```sh
sbcl --load load-taffish.dev.lisp
```

and the existing project test entry points. Specific test commands should later be fixed in a separate testing document.

## Documentation Sync

When adding files or changing module responsibilities, update:

1. [ASDF System And Module Map](01-asdf-system-map.md)
2. The corresponding module README
3. Related standard documents

If the change is only an internal implementation improvement, it may be enough to add a note in the corresponding module's "Implementation Notes" or "Modification Guide".

## Documentation Publication Status

`docs/` is part of the public source repository. Treat it as a maintained contract surface: avoid private notes, stale temporary judgments, and unpublished research or collaboration details. When behavior changes, update the relevant developer, standards, or architecture document in the same change set.

