# han.host 宿主适配层

`han.host` 是 han 最底层的宿主实现适配层。它隐藏 SBCL、LispWorks 等 Common Lisp 实现之间的差异。

## 作用

TAFFISH 要构建二进制命令行工具，不能让上层到处出现 `#+sbcl`、`#+lispworks` 条件代码。`han.host` 把这些差异集中处理。

## 支持实现

当前声明支持：

```text
SBCL, LispWorks
```

不支持的实现会加载 `unsupported.lisp`，调用相关函数时抛出 `unsupported-host-function`。

## 通用能力

`common.lisp` 提供：

1. `host-process` 统一结构。
2. cwd。
3. 文件存在、目录存在。
4. 目录文件和子目录枚举。
5. copy-file。
6. delete-directory-tree。
7. temporary-directory。
8. POSIX shell token escape。
9. 同步进程运行需要的临时输入输出文件机制。

## process API

| API | 作用 |
| --- | --- |
| `run-program` | 启动外部进程，返回 `host-process`。 |
| `run-program-sync` | 同步运行命令，返回 stdout、stderr、exit-code。 |
| `process-status` | 返回 `:running`、`:exited` 或 `:unknown`。 |
| `process-exit-code` | 获取退出码。 |
| `process-wait` | 等待进程结束。 |
| `process-close` | 关闭相关 stream/resource。 |

## SBCL 实现

SBCL 使用：

1. `sb-ext:*posix-argv*`
2. `sb-ext:posix-getenv`
3. `sb-ext:exit`
4. `sb-ext:run-program`

同步运行会把 stdout/stderr 捕获到临时文件，再读回字符串或 replay 到 stream。

## LispWorks 实现

LispWorks 使用：

1. `sys:*line-arguments-list*`
2. `lw:environment-variable`
3. `lw:quit`
4. `system:run-shell-command`
5. `system:pipe-exit-status`

同样通过统一的 `host-process` 包装返回。

## 安全细节

`delete-directory-tree` 会拒绝删除不安全目录，例如 `/`。真正删除使用系统 `rm -rf`，但前面有 validate 保护。

`escape-sh-token` 使用单引号 quoting，并正确处理内部单引号：

```sh
'abc'\''def'
```

## 修改指南

修改 host 层时要非常谨慎：

1. 不要引入 TAFFISH 业务逻辑。
2. 同步检查 SBCL 和 LispWorks。
3. process 返回值语义必须保持。
4. 删除目录的安全校验不能削弱。
5. shell escaping 的行为会影响整个 TAFFISH 的安全性。
