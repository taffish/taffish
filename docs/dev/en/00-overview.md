# Overall Architecture

TAFFISH is a portable application system for bioinformatics tools and workflows. Its core is not "wrapping a few commands"; it defines the TAF description language, compiles that language into stable POSIX shell scripts, and then uses the `taf` command to form a complete workflow around projects, Hub, installation, execution, and diagnostics.

## Command And Protocol Entrypoints

The current repository has two main command entry points and one AI protocol entry point:

| Entrypoint | System | Audience | Core responsibility |
| --- | --- | --- | --- |
| `taffish` | `taffish-cli` | TAF compiler users and low-level debuggers | Read `.taf`, run lexing, parsing, binding, emitting, and output shell. |
| `taf` | `taf-cli` | General users, taf-app authors, Hub users | Create projects, check projects, build, run, publish, install, search, and diagnose. |
| `taffish-mcp` | `taffish.mcp` | MCP-compatible AI clients | Expose conservative structured tools/resources/prompts for inspection, validation, safe compilation, and project/app understanding. |

You can think of `taffish` as the language compiler, `taf` as the application management tool built around that language and ecosystem, and `taffish-mcp` as the structured AI-facing interface over safe parts of both.

## Core Path

The path from TAF source text to shell is:

```text
.taf source
  -> lex-taf
  -> parse-taf
  -> normalize-input-args / normalize-input-context
  -> bind-taf
  -> compile-taf-result
  -> emitter
  -> shell script
```

This path is owned by `taffish-core`. Each step should remain as one-way, explicit, and debuggable as possible:

| Stage | Main file | Input | Output | Key responsibility |
| --- | --- | --- | --- | --- |
| Model | `model.lisp` | none | Conditions, tokens, lines, programs, results | Define data structures shared across stages. |
| Lexer | `lexer.lisp` | Text stream or string | List of `taf-line` | Split TAF text into positioned logical lines. |
| Parser | `parser.lisp` | List of `taf-line` | `taf-program` | Recognize ARGS, RUN, subtags, and argument specs. |
| Input | `input.lisp` | External args and context | Normalized input structures | Unify CLI, container, paths, CPU, and environment information. |
| Binder | `binder.lisp` | Program, args, context | `taf-result` | Bind arguments and built-ins into a compiler-ready result. |
| Emitter | `emitter/*` and `emitter/builtins/*` | Compiled blocks | Shell fragments | Convert TAF blocks to shell according to tags. |
| Compiler | `compiler.lisp` | Program or result | Shell string | Organize prelude, blocks, and finalization. |

## Upper Workflows

`taf-core` builds on `taffish-core` and turns the language compiler into a usable project system:

```text
taf new
  -> generate taf-app project skeleton

taf check
  -> read taffish.toml
  -> check project metadata, entry point, dependencies, and release state

taf compile / build / run
  -> call taffish-core
  -> generate target scripts or distributable artifacts

taf hub/info/search/install/list/which
  -> read local Hub index
  -> locate packages, commands, artifacts, versions, and sources

taf system/config/history/doctor
  -> manage system directories, config, history, and diagnostics

taffish-mcp
  -> expose safe MCP tools/resources/prompts
  -> inspect installed apps and current projects
  -> validate or compile source/project/app invocations without running workflows
```

## Directory Overview

| Path | Purpose |
| --- | --- |
| `taffish.asd` | Main TAFFISH ASDF system definition; determines load order and module boundaries. |
| `load-taffish.dev.lisp` | Development load entry point. |
| `vendor/han/` | Built-in base library for cross-platform and common parsing capabilities. |
| `taffish-core/` | TAF language core. |
| `taffish-cli/` | `taffish` command entry point. |
| `taf-core/` | Project, Hub, and system capabilities for `taf`. |
| `taf-cli/` | `taf` command entry point. |
| `taffish-mcp/` | MCP stdio server for AI clients. |
| `install/` | Installation scripts for binary distribution. |
| `completion/` | Shell completion. |
| `vim-highlight/` | TAF syntax highlighting. |

## Core Design Judgments

TAFFISH's core value comes from the combination of three things:

1. The TAF language describes tools, workflows, parameters, and container execution as compilable objects.
2. The compiled result is shell, so system boundaries are clear, runtime dependencies are light, and portability is strong.
3. `taf` and the Hub mechanism lift a single TAF program into a discoverable, installable, reproducible application ecosystem.

Maintenance work should protect these three properties. Any change that makes `.taf` hard to check statically, makes output shell opaque, or makes Hub apps hard to maintain long-term needs careful evaluation.

The current stable compilation path is `parse-taf -> bind-taf -> compile-taf-result`. `compile-taf-program` is an internal reserved function in 0.9.0. It is not exported, not implemented, and should not be treated as a public entry point.
