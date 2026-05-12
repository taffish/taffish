# han API

`han` is TAFFISH's base library. It provides argument handling, JSON, paths, OS helpers, host adaptation, character sources, and testing tools. It should not depend on TAFFISH business concepts.

## han.args

Stability: stable.

### Input Parsing

```lisp
(han.args:parse-args-input raw-input-args add-cmd)
```

Return: `args-input`.

Structure:

1. `raw-cmd`
2. `raw-argv`
3. `tokens`
4. `segments`
5. `diagnostics`

### Spec Parsing

```lisp
(han.args:parse-arg-spec spec-string)
(han.args:parse-args-spec spec-list command)
```

Return: `arg-spec` or `args-spec`.

Common specs:

```text
(--/-n)name=World
!(--/-i)input
(--/-v)verbose?
(@:)run
$1
```

### Binding And Query

```lisp
(han.args:bind-args args-spec args-input &optional builtin-table)
(han.args:get-arg name-or-spec args-result)
```

`get-arg` first checks builtin bindings, then ordinary bindings, and resolves default query/concat.

Important structures:

| Structure | Meaning |
| --- | --- |
| `arg-token` | argv token. |
| `arg-segment` | slot segment. |
| `arg-diagnostic` | warning/error. |
| `arg-spec` | Single argument spec. |
| `args-spec` | Argument spec collection. |
| `arg-binding` | Single argument binding. |
| `args-result` | Binding result. |

## han.json

Stability: stable.

Data model:

| JSON | Lisp |
| --- | --- |
| object | EQUAL hash-table |
| array | vector |
| true | `t` |
| false | `nil` |
| null | `:null` |

Core API:

```lisp
(han.json:parse-json string)
(han.json:read-json-file path)
(han.json:get-json object "key")
(han.json:set-json object "key" value)
(han.json:encode-json value :indent 2)
(han.json:write-json-file path value :indent 2)
```

Note: the second return value of `get-json` indicates whether the key exists, allowing callers to distinguish JSON false from a missing key.

## han.path

Stability: stable.

Core API:

```lisp
(han.path:->pathname x)
(han.path:->namestring x)
(han.path:directory-pathname x)
(han.path:parent-directory-pathname x)
(han.path:join-path base "a" "b")
(han.path:absolute-pathname x base)
(han.path:relative-path target base)
(han.path:file-exists-p path)
(han.path:directory-exists-p path)
(han.path:directory-files dir)
(han.path:subdirectories dir)
(han.path:copy-file source target)
(han.path:delete-directory-tree dir)
(han.path:temporary-directory)
```

Safety note: `delete-directory-tree` delegates to the host layer, and the host layer protects against root-directory deletion.

## han.os

Stability: stable.

Core API:

```lisp
(han.os:load-lines path-or-stream)
(han.os:load-string path-or-stream)
(han.os:getenv-default name default)
(han.os:require-env name)
(han.os:current-user)
(han.os:current-directory)
(han.os:home-directory)
(han.os:find-executable "git")
(han.os:escape-sh-token value)
(han.os:run-program command :output :string)
(han.os:run-shell-command command :wait t :lines t)
```

Note: `find-executable` currently only checks file existence, not executable permissions.

## han.host

Stability: semi-stable.

`host` is the low-level adaptation API. Normal TAFFISH code should prefer `han.os`.

Core API:

```lisp
(han.host:argv)
(han.host:getenv "HOME")
(han.host:cwd)
(han.host:quit 0)
(han.host:file-exists-p path)
(han.host:directory-exists-p path)
(han.host:run-program-sync command)
(han.host:run-program program :arguments args)
(han.host:process-wait process)
(han.host:process-exit-code process)
(han.host:process-close process)
```

Supported implementations:

```text
SBCL, LispWorks
```

Unsupported implementations signal `unsupported-host-function`.

## han.source

Stability: stable.

Core API:

```lisp
(han.source:make-char-source string)
(han.source:source-location source)
(han.source:make-source-mark source)
(han.source:source-reset source mark)
(han.source:source-eof-p source)
(han.source:source-peek-char source)
(han.source:source-next-char source)
(han.source:source-consume-string-if source string)
(han.source:source-read-while source predicate)
```

Purpose: preserve index, line, and column when writing lexers/parsers.

## han.test

Stability: semi-stable.

Core API:

```lisp
(han.test:deftest name () ...)
(han.test:run-test 'name)
(han.test:run-all-tests)
(han.test:check-true form)
(han.test:check-false form)
(han.test:check-equal expected form)
(han.test:check-error (condition-type) ...)
```

Positioning: a small self-hosted test framework, not a full testing platform.

## Maintenance Principles

1. `han` APIs should not know TAF, Hub, taf-app, GitHub, or Gitee.
2. `han.args` is the foundation of the TAFFISH argument system; changes must be checked against `taffish-core`.
3. `han.host` changes must consider both SBCL and LispWorks.
4. `han.json` `:null` and the two return values of `get-json` must not change casually.
5. The return shape of `han.os:run-shell-command` must not change casually.

