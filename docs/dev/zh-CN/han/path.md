# han.path 路径工具

`han.path` 封装 Common Lisp pathname 和基础文件系统操作。它的目标是让上层少直接面对各实现 pathname 细节。

## 作用

Common Lisp pathname 很强，但在跨实现、跨平台、字符串输入和目录路径判断上容易出错。`han.path` 提供一组更直接的 helper。

## 核心 API

| API | 作用 |
| --- | --- |
| `->pathname` | string/pathname 转 pathname，并规范 directory list。 |
| `->namestring` | 转 namestring。 |
| `directory-pathname-p` | 判断是否像目录 pathname。 |
| `directory-pathname` | 把 file-like input 转目录 pathname。 |
| `parent-directory-pathname` | 返回文件所在目录；目录输入保持目录。 |
| `join-path` | 从左到右合并路径片段。 |
| `absolute-pathname-p` | 判断是否绝对路径。 |
| `absolute-pathname` | 相对 base 解析绝对路径。 |
| `relative-path` | host/device 相同时计算相对路径。 |
| `file-exists-p` | 文件存在则返回 pathname。 |
| `directory-exists-p` | 目录存在则返回 directory pathname。 |
| `directory-files` | 直接子文件。 |
| `subdirectories` | 直接子目录。 |
| `copy-file` | 复制文件。 |
| `delete-directory-tree` | 递归删除目录。 |
| `temporary-directory` | 临时目录。 |

## directory-pathname

`directory-pathname` 会把：

```text
/tmp/foo
```

视为目录路径：

```text
/tmp/foo/
```

这在 TAFFISH 中很常见，因为 home、apps、index、target 等路径多数是目录。

## join-path

`join-path` 使用 `merge-pathnames` 从左到右合并片段。例如：

```lisp
(han.path:join-path "/tmp/" "taffish" "index" "current.json")
```

适合构造 TAFFISH home 内部路径。

## relative-path

`relative-path` 只在 target 和 base 的 host/device 相同时真正相对化。否则直接返回 target。这个行为避免在不同设备之间构造无效相对路径。

## 文件系统操作

文件和目录操作最终委托给 `han.host`。这意味着实现差异被 host 层处理，`han.path` 专注路径语义。

## 修改指南

修改路径逻辑时要检查：

1. `taf-core/system/home.lisp` 的目录约定。
2. `taf-core/project/build.lisp` 的 snapshot 和 target 路径。
3. `hub/install/uninstall/list/which` 的 install root 和 launcher 路径。
4. `delete-directory-tree` 的安全校验不要绕开。
