# taffish-core

`taffish-core` is the language core of TAFFISH. It compiles `.taf` source code into shell scripts and is the most central layer of the whole system, and the layer that should remain most stable.

## Role

`taffish-core` answers this question: how can a declarative or semi-declarative TAF file be converted into portable, inspectable, executable shell?

It is not responsible for:

1. Downloading packages from the Hub.
2. Managing user installation directories.
3. Maintaining GitHub or Gitee mirrors.
4. Deciding how apps are published.

Those responsibilities belong to `taf-core` or higher ecosystem layers.

## System Position

```text
.taf
  -> taffish-core
  -> shell script
  -> taf-core/project/run or another execution entry
```

`taffish-core` can be called directly by `taffish-cli`, or by project build/run workflows in `taf-core`.

## File Responsibilities

| File | Role |
| --- | --- |
| `package.lisp` | Define and export core APIs. |
| `model.lisp` | Define conditions, tokens, lines, context, program, result, and related structures. |
| `lexer.lisp` | Split TAF source into positioned logical lines. |
| `parser.lisp` | Parse logical lines into `taf-program`, recognizing ARGS, RUN, and subtags. |
| `input.lisp` | Normalize external arguments and runtime context. |
| `binder.lisp` | Bind arguments, context, and program into `taf-result`. |
| `emitter/model.lisp` | Define emitter object and default lifecycle. |
| `emitter/registry.lisp` | Provide emitter registration, matching, and emission. |
| `emitter/builtins/*.lisp` | Implement built-in tags such as shell, container, taffish, and taf-app. |
| `compiler.lisp` | Organize full compilation flow and generate shell. |
| `main.lisp` | Wrap the main external compile entry. |

## Core Data Structures

Key structures exported by `taffish-core/package.lisp` include:

| Name | Meaning |
| --- | --- |
| `taffish-error` | Core TAFFISH error condition. |
| `taf-token` | Token with original text and position information. |
| `taf-line` | TAF logical line. |
| `taf-context` | Compile and runtime context. |
| `taf-program` | Program object emitted by the parser. |
| `taf-result` | Bound result emitted by the binder and consumed by the compiler. |

These structures connect the compilation path. During maintenance, later stages should not go back and reinterpret content already owned by earlier stages.

## Public API

Main APIs:

| API | Role |
| --- | --- |
| `lex-taf` | Run lexical analysis. |
| `parse-taf` | Run parsing. |
| `normalize-input-args` | Normalize external input arguments. |
| `normalize-input-context` | Normalize runtime context. |
| `bind-taf` | Bind arguments and context. |
| `compile-taf-result` | Generate shell from a bound result. |
| `compile-taf-program` | Internal reserved function; not exported and not implemented yet. Future work must define a default binding strategy before exposing it. |
| `compile-taf` | Compile by dispatching from input type. |
| `taffish-to-shell` | Conversion entry for external callers. |

Emitter APIs:

| API | Role |
| --- | --- |
| `*taf-emitters*` | Current registered emitter list. |
| `taf-emitter` | Emitter structure/class. |
| `register-emitter` | Register an emitter. |
| `defemitter` | Convenience macro that defines and registers an emitter. |
| `emit-block` | Select emitter by tag and generate shell fragment. |
| `default-prelude` | Default compile prelude fragment. |
| `default-finalize` | Default compile finalization fragment. |

## Compilation Invariants

When maintaining `taffish-core`, protect these invariants:

1. The lexer only handles lexical analysis and position annotation, not semantic binding.
2. The parser only handles TAF structure and argument specs, not actual user input values.
3. The input layer only normalizes external input and context, not TAF syntax.
4. The binder binds program and input, and does not redo lexing or parsing.
5. The compiler organizes shell output, and does not read CLI arguments directly.
6. Emitters handle blocks by tag and should not control the parser backwards.

## Related Topics

- [Compilation Pipeline](compiler-pipeline.md)
- [Emitter System](emitter-system.md)
- [model.lisp](model.md)
- [lexer.lisp](lexer.md)
- [parser.lisp](parser.md)
- [input.lisp](input.md)
- [binder.lisp](binder.md)
- [compiler.lisp And main.lisp](compiler.md)
- [emitter registry](emitter-registry.md)
- [shell emitter](builtin-shell.md)
- [taf-app emitter](builtin-taf-app.md)
- [taffish emitter](builtin-taffish.md)
- [container emitter](builtin-container.md)
