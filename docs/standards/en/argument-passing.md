# Argument Substitution, Forwarding, And Display

[中文版](../zh-CN/argument-passing.md)

This page describes the current implementation. TAF compiles text into POSIX
shell; its substitution forms do not all behave like an argv list. Choose a
form according to the next consumer: shell source, a list of arguments, or a
human-readable display. This is not a new quoting mode or an automatic safety
guarantee.

## The Four Paths

| Form | What is inserted into generated shell | Responsibility |
| --- | --- | --- |
| Ordinary `::input::` | The value as text, without automatic shell quoting. | The author chooses an appropriate shell context and accepted input. |
| `::(@:)step::` with supplied block arguments | Each argument token is encoded separately, then joined with spaces. | Insert it as an unquoted argument-list fragment for the next shell parse. |
| `::*ARGV*::` | Context argv joined with spaces, without per-argument encoding. | Treat it as shell text, not transparent argv forwarding. |
| `<taf-app:...>` command mode | Context argv joined with spaces and used instead of the block body. | Treat it as a shell command, even when the body has no `*ARGV*` token. |

The block rule applies to a parsed token list. A missing block's string default
is text, not a supplied list. Block-token encoding already exists in v0.10.1;
it is not introduced by v0.11.0.

## Before TAFFISH Receives Arguments

The calling shell removes syntactic quotes and performs its own expansion:

```sh
taffish ./args.taf @step: "$HOME" '$HOME'
```

TAFFISH receives the home-directory value followed by the literal text `$HOME`.
The original choice of quote characters is not retained. A single quote inside
double quotes does not stop expansion: `"'$HOME'"` contains the expanded home
directory surrounded by literal single-quote characters.

## Ordinary Parameters: Text Substitution

Save this example as `scalar.taf`:

```taf
ARGS
<!(--/-i)input>
RUN
<shell>
printf '<%s>\n' "::input::"
```

Compile and run it:

```sh
taffish ./scalar.taf --input 'sample A.fa' > scalar.sh
sh -n scalar.sh
sh scalar.sh
```

The generated command is `printf '<%s>\n' "sample A.fa"`, producing one value:
`<sample A.fa>`. Without the author-written double quotes, this example produces
two values, `<sample>` and `<A.fa>`.

These quotes are sufficient for this space-containing example, not arbitrary
input. If the supplied text is `$HOME`, inserting it into `"::input::"` leaves
`"$HOME"` in the generated shell, which expands when that shell runs. Embedded
quotes and command substitutions can also change interpretation. Do not use raw
substitution as an escaping mechanism for untrusted data.

## Block Arguments: Forward A List

Save this example as `args.taf`:

```taf
ARGS
<(@:)step>
RUN
<shell>
printf '<%s>\n' ::(@:)step::
```

```sh
taffish ./args.taf @step: --out 'hello world' '$HOME' "a'b" > args.sh
sh -n args.sh
sh args.sh
```

The generated command is:

```sh
printf '<%s>\n' --out 'hello world' '$HOME' 'a'\''b'
```

The result is:

```text
<--out>
<hello world>
<$HOME>
<a'b>
```

`--out` needs no quoting. The other spellings encode single shell arguments;
`'a'\''b'` represents the value `a'b`, not extra quotes added to the value.
An argument containing literal `"$threads"` remains those literal characters
through this path. Already-quoted-looking arguments do not bypass encoding.

### Display Is Different

For the two supplied arguments `--out` and `hello world`:

```taf
printf '<%s>\n' ::(@:)step::
printf '%s\n' "Add: ::(@:)step::"
```

The first line passes two arguments to `printf`. The second generates:

```sh
printf '%s\n' "Add: --out 'hello world'"
```

and displays `Add: --out 'hello world'`. The inner single quotes are ordinary
characters inside the outer double quotes. This display is not an argv list.

Wrapping the entire block in double quotes is not a general-purpose display or
forwarding encoder. For example, a supplied literal `$HOME` becomes `'$HOME'`
in the block fragment; surrounding that fragment with double quotes allows
`$HOME` to expand. To display the actual values and distinguish no arguments
from one empty argument, use shell positional parameters:

```taf
set -- ::(@:)step::
printf 'argc=%s\n' "$#"
for arg do
    printf '<%s>\n' "$arg"
done
```

This replaces the generated script's shell positional parameters; use it where
that is intended. The loop prints each value without reparsing it. `printf`
alone with a `%s` format can print an empty value even when given no arguments.
Do not add `eval` to decode a display string.

## `*ARGV*`: Existing Shell-Text Semantics

With context argv `("sample A.fa" "out dir")`:

```taf
printf '<%s>\n' ::*ARGV*::
printf '%s\n' "::*ARGV*::"
```

generates:

```sh
printf '<%s>\n' sample A.fa out dir
printf '%s\n' "sample A.fa out dir"
```

The first command receives four values. The second displays one joined string.
The existing `"::*ARGV*::"` spelling remains valid for that purpose, but it does
not preserve original argument boundaries or escape arbitrary input. Shell
expansions remain active inside its double quotes.

For an author-controlled forwarding entry using unquoted `::*ARGV*::`, literal
shell quoting must survive the caller shell. For `forward.taf`:

```taf
<shell>
printf '<%s>\n' ::*ARGV*::
```

compile with:

```sh
taffish ./forward.taf "'sample A.fa'" "'out dir'"
```

The resulting fragment is `'sample A.fa' 'out dir'`, which the next shell parses
as two values. This is intentional shell source, not a general data interface.
Do not apply this extra quoting to a block argument: the block would preserve
the quote characters as data instead.

## taf-app Command Mode

For `entry.taf`:

```taf
<taf-app:shell>
printf '%s\n' DEFAULT
```

When the first context argument is nonblank and does not start with `-`, command
mode replaces the body. For example:

```sh
taffish ./entry.taf printf "'<%s>\n'" "'sample A.fa'"
```

generates `printf '<%s>\n' 'sample A.fa'`. Running that shell prints
`<sample A.fa>`; it does not print `DEFAULT`. Merely passing `"sample A.fa"`
without literal inner quotes loses that boundary during the space join.
When the first argument starts with `-`, the block body remains in use.

## Parent And Child Flows

Each layer owns its input and output contract. If a parent supplies a token block
and the child consumes and forwards it as a token block, spaces, empty arguments,
literal quotes and delimiter-looking data can cross multiple layers without
callers adding a quote layer per Flow:

```taf
ARGS
<(@:)step>
RUN
<taffish>
[[taf: taf-child @step: ::(@:)step::]]
```

This assumes `taf-child` declares and uses the `step` block in turn. If the child
instead joins its input through `*ARGV*` or command mode, that layer switches to
shell-text semantics. The parent block cannot undo that later loss of boundaries.

Inline `[[taf: ...]]` calls are compiled in the generated block's prelude, before
the block body runs. Existing shell-text command entries can deliberately defer
expansion until a compiled child executes:

```taf
<taffish>
threads=7
export threads
[[taf: taf-child-command echo '"$threads"' ]]
```

Here `taf-child-command` must use shell-text command mode. The compiler receives
literal `"$threads"`; its generated command expands the exported variable later.
Replacing `'"$threads"'` with `"$threads"` expands during child compilation,
before the assignment in this body. Passing the same text through a token block
has different semantics: it is literal data, not a delayed expression.

## Inline Boundaries Belong To Source

For source-compiled lines in `<taffish>`, only source text determines `[[taf:`
and its closing `]]`. Substituted values, including string defaults, cannot
create a call, close one early, or change the scanner's quote state. Thus:

```taf
[[taf: taf-child @step: ::(@:)step::]]
[[taf: taf-child @step: 'literal]].fa' ]]
```

In the first line, supplied values such as `sample]].fa`, `[[taf: taf-fake]]`,
`both ' and "`, or an empty string remain arguments. In the second, the closing
marker inside source quotes is data. An unquoted `sample]].fa` written directly
in source still closes the call at the first `]]`; quote that source argument.

This is a boundary rule, not new argument quoting. After the boundaries are
known, resolved command text is still checked for the `taf-` prefix. SPACE and
TAB both separate the command name and its first option. `--compile` is inserted
immediately after the command name unless it is already the first option;
the remaining shell text is preserved. Ordinary parameters remain raw text; they can still make
the generated shell invalid or change shell execution if placed incorrectly.
The failure diagnostic is separately shell-quoted and does not evaluate the
command text a second time.

Calls remain single-line; multiple calls, pipes and surrounding shell text are
allowed. There is no nested-call or full shell-parser support. Outside a call,
write `\[[taf: ...]]` for a literal marker; ordinary shell quotes alone do not
disable a source opener. Existing `\[` and `\]` decoding in ordinary text stays
in effect, including substituted ordinary text.

Full-line source comments, whose first non-SPACE/TAB character is `#`, are
preserved without inline scanning or bracket-escape decoding. Closed, empty,
and unclosed inline-looking markers in those comments neither create child
compilation steps nor cause inline syntax errors. The source line's kind
determines this behavior: substituted values containing `#` cannot turn a code
line into a source comment. A trailing shell comment after ordinary code is
outside this full-line rule; inline markers there can still be scanned.

Compatibility boundary: assembling a complete inline call through `::arg::`
no longer creates a call in a source-compiled line. Put the markers in source
and substitute only the command content. Legacy `emit-block` callers supplying
only `:line/:number`, including dynamically supplied `<taf-app:taffish>` command
mode, have no source metadata and retain text-based boundary scanning; full-line
comments are recognized from that supplied text.
`taf check/build` use the same source boundaries for dependency discovery;
they do not evaluate parameter values or infer dynamic command names.

## Empty Arguments And Remaining Limits

An empty CLI value is accepted and differs from a missing option value:
`--input ""` supplies a value; a trailing `--input` without a value is an error.
`@step: ""` emits `''`, preserving one empty argument in an unquoted block list.
With no supplied block arguments, no argument is emitted.

Raw text paths do not gain automatic quoting: an empty scalar or empty
`*ARGV*` text inserts no characters. `"::input::"` or `"::*ARGV*::"` can therefore
produce one empty shell argument, whereas their unquoted forms produce none.
Command mode likewise keeps its space-join behavior. Passing the two-character
shell fragment `"''"` through raw text can create an empty shell argument;
through a block, it is two literal single-quote characters.

Inspect generated shell and check `sh -n` before execution. A successful syntax
check alone does not prove data safety or correct expansion timing. These examples
describe plain POSIX shell; container heredocs and other emitters introduce their
own contexts and must be checked separately.

## Regression Coverage

`taffish-core/test.lisp` records the substitution rules.
`test/taffish/argument-contract.py` exercises delivered binaries, actual shell
execution, argument counts/contents, nested compilation, and delayed expansion:

```sh
./test/run-tests.sh --filter taffish/argument-contract
```

The `empty-arguments`, `inline-boundaries`, `inline-error-message`, and
`nested-blocks` cases check actual argument counts and values, generated shell
syntax, delayed expansion and non-evaluating diagnostics. The additional
`--filter taf-project/inline-source-boundaries` case checks dependency discovery,
live compilation and built wrappers with the same inputs.

The `inline-separators`, `inline-comments`, `inline-projects`, and `inline-mcp`
cases cover SPACE/TAB combinations, comment markers, child argv, and the
compile/build boundary. Harmless local child probes detect accidental runtime
entry; MCP tests execute returned shell separately from the compile request.
These checks require binaries built from the corrected source, not the frozen
pre-fix release payloads. See [the test guide](../../../test/README.md).
