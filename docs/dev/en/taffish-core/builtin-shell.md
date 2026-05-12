# shell emitter

`emitter/builtins/shell.lisp` implements the basic `<shell>` tag. It outputs content lines from a TAF block directly as shell.

## Role

The `shell` emitter is TAFFISH's minimal execution model. It does not wrap containers, compile inline taf-apps, or delegate command mode.

## Match Rule

It matches only when the tag is case-insensitively equal to `shell`:

```taf
RUN
<shell>
echo hello
```

## Emission Rule

The emit function directly returns the `:line` field of each resolved line.

In other words, after parameter tokens under `<shell>` are replaced by the compiler, the code enters the generated shell as-is.

## System Position

```text
compiler
  -> emit-block "shell"
  -> shell emitter
  -> default prelude + raw shell lines
```

## Modification Guide

The `shell` emitter should remain simple. Do not add container, taf-app, or Hub logic here.

If enhancing the shell emitter, first decide whether the change belongs to a generic shell output contract, such as error comments, debug information, or source maps, rather than special logic for one bioinformatics tool.

