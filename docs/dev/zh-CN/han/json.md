# han.json JSON 工具

`han.json` 是一个最小可移植 JSON parser/writer。TAFFISH 用它读取 hub index、install metadata，并输出 list/which 等 JSON 结果。

## 数据模型

| JSON | Lisp 表示 |
| --- | --- |
| object | EQUAL hash-table |
| array | vector |
| string | string |
| number | integer 或 float |
| true | `t` |
| false | `nil` |
| null | `:null` |

注意：JSON false 和 Lisp nil 同一个值，所以读取 object 字段时要使用 `get-json` 的第二返回值判断 key 是否存在。

## 核心 API

| API | 作用 |
| --- | --- |
| `json-object` | 从 cons pairs 创建 object。 |
| `json-array` | 创建 vector array。 |
| `json-object-p` | 判断 object。 |
| `json-array-p` | 判断 array。 |
| `json-null-p` | 判断 `:null`。 |
| `json-keys` | 返回排序 key。 |
| `get-json` | 读取字段，第二值表示存在性。 |
| `set-json` | 设置字段。 |
| `parse-json` | 字符串解析。 |
| `read-json-file` | 读文件解析。 |
| `encode-json` | 编码为字符串。 |
| `write-json-file` | 写文件。 |

## parser 能力

parser 支持：

1. object。
2. array。
3. string。
4. number。
5. true/false/null。
6. Unicode escape，包括 surrogate pair。
7. trailing content 检查。
8. trailing comma 报错。

解析错误使用 `json-error`。

## writer 能力

writer 会：

1. 按排序 key 输出 object。
2. 支持 indent，默认 2。
3. 对控制字符和非 ASCII 字符使用 JSON escape。
4. float 输出中把 `d/D` 指数替换为 `e`。

## 在 TAFFISH 中的使用

| 模块 | 用途 |
| --- | --- |
| `taf-core/hub/info.lisp` | 读取 index。 |
| `taf-core/hub/search.lisp` | 输出 JSON search 结果。 |
| `taf-core/hub/install.lisp` | 写 install metadata。 |
| `taf-core/hub/list.lisp` | 输出 list JSON。 |
| `taf-core/hub/which.lisp` | 输出 which JSON。 |

## 修改指南

修改 `han.json` 时要检查：

1. `:null` 语义是否保持。
2. `get-json` 第二返回值是否保持。
3. JSON object key 排序是否影响输出稳定性。
4. hub index 大文件解析性能是否足够。
5. writer 输出是否仍被外部工具接受。
