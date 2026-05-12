# taffish-core Compilation Pipeline

This page explains how `.taf` source becomes shell through `taffish-core`.

## Role

The goal of the compilation pipeline is to split TAF semantics into clear stages. Each stage solves one kind of problem and passes its result to the next stage.

This gives three benefits:

1. Errors are easier to locate.
2. Each layer's input and output are more stable.
3. Future tags, argument capabilities, or container backends can be added without rewriting the whole compiler.

## lexer

`lexer.lisp` receives TAF text and outputs a list of `taf-line` values.

It recognizes:

1. Empty lines.
2. Comment lines.
3. Tag lines.
4. Ordinary code lines.
5. Line types such as `ARGS`, `RUN`, and subtags.
6. Escapes and position information that TAF must preserve.

The lexer should preserve original information as much as possible so later stages can produce accurate errors.

## parser

`parser.lisp` receives a list of `taf-line` values and outputs `taf-program`.

It handles:

1. Recognizing `ARGS` blocks.
2. Recognizing `RUN` blocks.
3. Normalizing bare code into the default run block.
4. Normalizing leading subtags into run blocks.
5. Converting ARGS definitions into `han.args` argument specs.
6. Checking dead parameters, invalid blocks, and structural errors.

Parser output should be complete enough that the binder does not need to understand raw source structure again.

## input

`input.lisp` receives external input and outputs normalized args and context.

It handles:

1. CLI argument input.
2. User, home, workdir, and load directory.
3. argv, cmd, and cpus.
4. Container backend, mounts, SIF directories, heredoc, and related runtime context.

The point is to organize the outside world into stable structures so the compiler does not directly face a messy environment.

## binder

`binder.lisp` receives `taf-program`, args, and context, and outputs `taf-result`.

It handles:

1. Binding user arguments.
2. Injecting built-ins such as `*USER*`, `*HOMEDIR*`, `*WORKDIR*`, `*LOADDIR*`, `*ARGV*`, `*CMD*`, `*CPUS*`, and `*CONTAINER*`.
3. Handling special argument behavior under `taf-app` command mode.
4. Producing a result the compiler can consume directly.

The binder is the semantic binding layer. It should not split source again and should not generate final shell.

## compiler

`compiler.lisp` receives `taf-result` or `taf-program` and outputs a shell string.

It handles:

1. Resolving tokens and bound values.
2. Converting program blocks into emitter blocks.
3. Calling `emit-block`.
4. Combining shebang, prelude, block output, and finalize.

The compiler is the flow organizer. It should not become the place where all concrete tag implementations live.

## Modification Risks

The easiest mistakes come from stage-boundary drift. For example:

1. Reading real user arguments in the parser.
2. Reinterpreting TAF source format in the binder.
3. Hardcoding a concrete tag behavior in the compiler.
4. Making an emitter depend on temporary parser internals.

If this happens, first consider adding an explicit intermediate structure or helper instead of letting one layer cross boundaries directly.

