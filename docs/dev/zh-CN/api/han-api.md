# han API

`han` 是 TAFFISH 的基础库。它提供参数、JSON、路径、OS、宿主适配、字符源和测试工具。它不应该依赖 TAFFISH 业务概念。

## han.args

稳定性：稳定。

### 输入解析

```lisp
(han.args:parse-args-input raw-input-args add-cmd)
```

返回：`args-input`。

结构：

1. `raw-cmd`
2. `raw-argv`
3. `tokens`
4. `segments`
5. `diagnostics`

### 规格解析

```lisp
(han.args:parse-arg-spec spec-string)
(han.args:parse-args-spec spec-list command)
```

返回：`arg-spec` 或 `args-spec`。

常见 spec：

```text
(--/-n)name=World
!(--/-i)input
(--/-v)verbose?
(@:)run
$1
```

### 绑定与查询

```lisp
(han.args:bind-args args-spec args-input &optional builtin-table)
(han.args:get-arg name-or-spec args-result)
```

`get-arg` 会先查 builtin bindings，再查普通 bindings，并解析 default query/concat。

重要结构：

| 结构 | 说明 |
| --- | --- |
| `arg-token` | argv token。 |
| `arg-segment` | slot segment。 |
| `arg-diagnostic` | warning/error。 |
| `arg-spec` | 单参数规格。 |
| `args-spec` | 参数规格集合。 |
| `arg-binding` | 单参数绑定。 |
| `args-result` | 绑定结果。 |

## han.json

稳定性：稳定。

数据模型：

| JSON | Lisp |
| --- | --- |
| object | EQUAL hash-table |
| array | vector |
| true | `t` |
| false | `nil` |
| null | `:null` |

核心 API：

```lisp
(han.json:parse-json string)
(han.json:read-json-file path)
(han.json:get-json object "key")
(han.json:set-json object "key" value)
(han.json:encode-json value :indent 2)
(han.json:write-json-file path value :indent 2)
```

注意：`get-json` 的第二返回值表示 key 是否存在，用于区分 JSON false 和 missing key。

## han.path

稳定性：稳定。

核心 API：

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

安全说明：`delete-directory-tree` 最终委托 host 层，host 层有根目录删除保护。

## han.os

稳定性：稳定。

核心 API：

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

注意：`find-executable` 当前只检查文件存在，不检查执行权限。

## han.host

稳定性：半稳定。

host 是低层适配 API。普通 TAFFISH 代码优先用 `han.os`。

核心 API：

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

支持实现：

```text
SBCL, LispWorks
```

不支持实现会抛 `unsupported-host-function`。

## han.source

稳定性：稳定。

核心 API：

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

用途：写 lexer/parser 时保留 index、line、column。

## han.test

稳定性：半稳定。

核心 API：

```lisp
(han.test:deftest name () ...)
(han.test:run-test 'name)
(han.test:run-all-tests)
(han.test:check-true form)
(han.test:check-false form)
(han.test:check-equal expected form)
(han.test:check-error (condition-type) ...)
```

定位：自举用小测试框架，不是完整测试平台。

## 维护原则

1. `han` API 不应知道 TAF、hub、taf-app、GitHub/Gitee。
2. `han.args` 是 TAFFISH 参数系统基础，改动要同步检查 `taffish-core`。
3. `han.host` 改动要同时考虑 SBCL 和 LispWorks。
4. `han.json` 的 `:null` 和 `get-json` 双返回值不能随意改变。
5. `han.os:run-shell-command` 返回值形状不能轻易改变。
