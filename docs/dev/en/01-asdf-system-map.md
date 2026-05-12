# ASDF System And Module Map

TAFFISH uses ASDF to describe Common Lisp systems. The current main system is `taffish`, version `0.8.0`, and it depends on the built-in base library `han`. The ASDF file is not just build configuration; it is also an important architecture map.

## Main System Load Order

`taffish.asd` uses `:serial t`. This means files load in order, and later files may depend on definitions from earlier files. The order itself is a dependency chain and should not be adjusted casually.

The current order can be divided into five groups plus the AI-facing MCP layer:

```text
taffish-core
  package
  model
  lexer
  parser
  input
  binder
  emitter/model
  emitter/registry
  emitter/builtins/taf-app
  emitter/builtins/taffish
  emitter/builtins/shell
  emitter/builtins/container
  compiler
  main

taffish-cli
  package
  run
  main

taf-core
  package
  project/common
  project/new
  project/check
  project/compile
  project/build
  project/run
  project/publish
  hub/update
  hub/info
  hub/search
  hub/install
  hub/uninstall
  hub/list
  hub/which
  system/home
  system/config
  system/history
  system/doctor

taf-cli
  package
  run
  main

taffish-mcp
  package
  protocol
  tools
  resources
  prompts
  server
  main
```

## Meaning Behind Load Order

`taffish-core` loads first because it defines the complete TAF language compilation capability from source to shell. `taffish-cli` only wraps a command-line entry point around it.

`taf-core` loads after that because it needs to connect the compilation capability of `taffish-core` to the project, Hub, and runtime systems. `taf-cli` is the dispatch entry point for user commands. `taffish-mcp` loads after the CLI/core modules because it exposes a conservative AI-facing protocol layer over existing APIs rather than defining new business logic.

## han System

`vendor/han/han.asd` defines the built-in base library. It is currently split into:

```text
test
host
source
os
path
json
args
```

`han` is not TAFFISH business logic. It is the stable foundation TAFFISH needs. Argument specification parsing lives in `han.args`, JSON parsing in `han.json`, and path handling in `han.path`, so `taffish-core` and `taf-core` do not need to reimplement these basics.

## Relationship Between Packages And Systems

TAFFISH package boundaries mostly align with system boundaries:

| Package | Main directory | Meaning |
| --- | --- | --- |
| `taffish-core` | `taffish-core/` | Core TAF compiler API. |
| `taffish-cli` | `taffish-cli/` | `taffish` command implementation. |
| `taf-core` | `taf-core/` | Core business API behind the `taf` command. |
| `taf-cli` | `taf-cli/` | `taf` command implementation. |
| `taffish.mcp` | `taffish-mcp/` | MCP stdio server for AI clients. |
| `han.*` | `vendor/han/` | Base library subpackages. |

When adding a file, first decide which package responsibility it belongs to, then decide where the file should live. The directory is the concrete form of package and system boundaries.

## Checkpoints Before Editing ASDF

Before editing `taffish.asd` or `vendor/han/han.asd`, check:

1. Whether the new file really needs to be loaded by the system.
2. Whether every structure, function, or macro it depends on has already loaded before it.
3. Whether it introduces a reverse dependency, such as `taffish-core` calling `taf-core`.
4. Whether the corresponding package needs an updated `:export`.
5. Whether this document and the relevant module docs need updates.

The most common risk is putting upper-level command behavior into the lower-level language core. Concepts such as Hub, install, and project metadata belong to `taf-core`; they should not leak into `taffish-core`.
