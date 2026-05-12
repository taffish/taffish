# taffish-cli

`taffish-cli` is the implementation layer for the `taffish` command. It exposes the compilation capability of `taffish-core` to command-line users.

## Role

`taffish-cli` handles command-line arguments, reads input, calls `taffish-core`, and outputs results to users or callers.

It should not contain TAF language semantics. Language semantics belong to `taffish-core`.

## System Position

```text
user / script
  -> taffish command
  -> taffish-cli
  -> taffish-core
```

## File Responsibilities

| File | Role |
| --- | --- |
| `package.lisp` | Define CLI package. |
| `run.lisp` | Implement main command run logic. |
| `main.lisp` | Provide entry function. |

## Modification Guide

When changing `taffish-cli`, pay attention to:

1. Whether CLI argument changes require completion updates.
2. Whether output format is depended on by scripts or upper tools.
3. Whether errors preserve location information from `taffish-core`.
4. Do not add project, Hub, or install logic here.

If a requirement is a full workflow for ordinary taf-app users, it usually belongs in `taf-cli` and `taf-core`, not `taffish-cli`.

