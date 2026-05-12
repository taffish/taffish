# Emitter API

The emitter API converts TAF blocks into shell fragments. Built-in emitters include `shell`, `container`, `taffish`, and `taf-app`.

## Core Object

### `taffish.core:taf-emitter`

Stability: semi-stable.

Fields:

| Field | Signature | Meaning |
| --- | --- | --- |
| `name` | string | Emitter name. |
| `match-function` | `(tag line-number) -> parsed-info or nil` | Decide whether this emitter matches a tag. |
| `emit-function` | `(parsed-info lines taf-result) -> string-list` | Generate shell lines. |
| `prelude-function` | `(parsed-info lines taf-result) -> string-list` | Optional preceding shell lines. |
| `finalize-function` | `(parsed-info shell-lines-list taf-result) -> string` | Optional final merge. |

## Registration API

### `taffish.core:register-emitter`

Stability: semi-stable.

```lisp
(taffish.core:register-emitter emitter)
```

Role: register a `taf-emitter` into `*taf-emitters*`.

Errors:

1. Input is not a `taf-emitter`.
2. Emitter name is duplicated.

### `taffish.core:defemitter`

Stability: semi-stable.

```lisp
(taffish.core:defemitter name
  :match-function ...
  :emit-function ...
  :prelude-function ...
  :finalize-function ...)
```

Role: create and register an emitter.

Note: registration order affects match order. There is currently no priority mechanism.

## Emission API

### `taffish.core:emit-block`

Stability: stable.

```lisp
(taffish.core:emit-block tag lines taf-result &optional emitters)
```

Arguments:

| Argument | Meaning |
| --- | --- |
| `tag` | Parsed tag string. |
| `lines` | List of resolved-line plists. |
| `taf-result` | Current binding result. |
| `emitters` | Emitter list; defaults to `*taf-emitters*`. |

Resolved-line structure:

```lisp
(:line <line-string> :number <line-number>)
```

Return: shell string.

Errors:

1. No emitter matches.
2. Match, emit, prelude, or finalize is missing.
3. Prelude or emit does not return a string list.
4. Finalize does not return a string.

## Default Lifecycle

### `taffish.core:default-prelude`

Stability: semi-stable.

Generates debug comments including tag, source lines, loaddir, and workdir.

### `taffish.core:default-finalize`

Stability: stable.

Joins the shell line list with newlines.

## Minimal Emitter Example

```lisp
(taffish.core:defemitter demo
  :match-function
  (lambda (tag line-number)
    (when (string-equal tag "demo")
      (list :kind :demo
            :tag tag
            :line-number line-number)))
  :emit-function
  (lambda (parsed-info lines taf-result)
    (declare (ignore parsed-info taf-result))
    (mapcar (lambda (line)
              (getf line :line))
            lines)))
```

## Emitter Design Rules

1. Match functions only parse tags and should not read the filesystem.
2. Emit functions return string lists and do not concatenate the final large string directly.
3. Write a custom finalize only when a custom final structure is needed.
4. Do not modify the compiler main flow to support one tag.
5. Shell generation must account for quoting and paths.

## Special Note

The `taf-app` emitter's finalize has special assumptions about the shape of `shell-lines-list`. It is a delegated emitter rather than a normal line-list emitter. Future emitter API extensions need to account for this nested emission scenario.

