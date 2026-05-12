# taf-core Project System

The project system lives in `taf-core/project/` and owns the local workflow from taf-app creation to checking, compilation, build, run, and publish.

## Role

The project system puts a single `.taf` file into a maintainable application project. It describes project metadata through `taffish.toml` and then calls `taffish-core` for compilation.

## Core Files

| File | Role |
| --- | --- |
| `common.lisp` | Shared project constants, paths, and helpers. |
| `new.lisp` | Create taf-app project skeletons. |
| `check.lisp` | Read and validate `taffish.toml` and entry files. |
| `compile.lisp` | Compile project TAF. |
| `build.lisp` | Build distributable artifacts. |
| `run.lisp` | Run in project context. |
| `publish.lisp` | Publication-related logic. |

## Role Of taffish.toml

`taffish.toml` is the core metadata file of a taf-app project. `project/check.lisp` reads it and checks:

1. Package name.
2. Kind, such as tool or flow.
3. Whether release is a positive integer.
4. Whether main points to a `.taf` entry.
5. Whether dependency fields are valid.

The current implementation contains a small TOML parser focused on the subset needed by TAFFISH projects. Do not treat it as a full TOML implementation.

## Relationship With taffish-core

The project system should not implement TAF compilation itself. It should:

1. Read project metadata.
2. Locate the entry `.taf`.
3. Prepare required context.
4. Call `taffish-core` to compile.
5. Place results in the project or target directory.

If the project system starts parsing TAF syntax directly, the responsibility boundary has been crossed.

## Modification Guide

When changing the project system, also check:

1. Whether the new project skeleton still passes `project-check`.
2. Whether `taffish.toml` field changes affect existing taf-apps.
3. Whether build or publish artifacts can still be described by the Hub index.
4. Whether README, completion, and CLI help need updates.

