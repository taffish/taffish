# 开发流程与维护约定

本页记录维护 TAFFISH 源码时的基本流程。它不是用户安装教程，也不是测试报告。

## 开发前先定位层级

改代码前先判断需求属于哪一层：

| 需求类型 | 优先位置 |
| --- | --- |
| 人类语言解析、catalog 与回退 | `taffish-i18n` |
| TAF 语法、参数绑定、编译输出 | `taffish-core` |
| `taffish` 命令行参数和输出格式 | `taffish-cli` |
| 项目创建、检查、构建、运行、发布 | `taf-core/project/` |
| hub index、搜索、安装、卸载、定位 | `taf-core/hub/` |
| TAFFISH home、配置、历史、诊断 | `taf-core/system/` |
| `taf` 子命令分发和 CLI 文本 | `taf-cli` |
| 面向 AI 的保守结构化接口 | `taffish-mcp` |
| 跨模块基础能力 | `vendor/han` |

如果一个改动看起来要同时碰很多层，先确认是不是职责切分不清。TAFFISH 最重要的维护原则之一是：语言核心保持干净，上层生态逻辑放在 `taf-core`。

## 推荐阅读路径

修 `taffish-core` 时，建议按顺序读：

```text
package.lisp
model.lisp
lexer.lisp
parser.lisp
input.lisp
binder.lisp
emitter/model.lisp
emitter/registry.lisp
emitter/builtins/*.lisp
compiler.lisp
main.lisp
```

修 `taf-core` 时，建议先看：

```text
package.lisp
project/common.lisp
system/home.lisp
system/config.lisp
```

再进入具体子系统，例如 `project/check.lisp` 或 `hub/info.lisp`。

## 修改后的自查问题

每次修改后至少自问：

1. 这个改动是否改变了公开 API？
2. 是否改变了 `.taf` 到 shell 的输出契约？
3. 是否改变了 `taffish.toml`、hub index、config 的格式或默认值？
4. 是否需要同步更新 README、completion、install 脚本或文档？
5. 是否会影响 GitHub 与 Gitee 镜像场景？
6. 是否意外翻译或改变了 JSON、生成 shell、命令 token、MCP schema 等机器接口？

## 测试说明

Common Lisp 单元测试是实现变更的第一道检查：

```sh
sbcl --load load-taffish.dev.lisp \
  --eval '(multiple-value-bind (passed failed) (han.test:run-all-tests) (declare (ignore passed)) (when (> failed 0) (sb-ext:exit :code 1)))' \
  --quit
```

如果改动影响 CLI、生成 shell、项目、Hub、进程或交付程序，从仓库根目录构建三个命令后，用它们的实际路径运行完整外测。

```sh
./test/run-tests.sh \
  --taf ./target/taf \
  --taffish ./target/taffish \
  --taffish-mcp ./target/taffish-mcp
```

宿主、进程、路径或流的改动需要在 macOS/SBCL 和 Linux/LispWorks 上验证。0.12.0 的公开 CI 还会在 Apple Silicon macOS 上用 CCL 构建并测试三个命令。维护者在 Linux 上另行验证商业 LispWorks 构建。

运行器从 `taffish.asd` 推断版本并隔离宿主状态。修改入口或错误报告时，可以在同一条命令末尾加 `--filter cli-boundary/` 运行定向回归。[外部测试指南](../../../test/README.md)

这些回归用例检查启动失败、编译器诊断、不可用的输出流、中断和 MCP 恢复。探测保留控制终端并设置
超时。运行时启动时可能重用已关闭的描述符编号，因此写入失败测试应使用只读描述符或
断开的管道等可靠条件，不能假定关闭 stdout/stderr 就一定会失败。

## 发布证据

从 0.12.0 起，按[构建指南](build-from-source.md)校验已签名的包外清单，用严格 GPG 模式安装本机平台包，再对安装所得的三个程序运行完整外测。在两个平台分别验证从 0.11.0 同前缀升级。记录测试平台、程序摘要、测试结果与安装收据，供本版本发布验收使用。

程序和压缩包的校验和随各自的签名清单分发。公开 Release 正文说明用户可见的变化和升级注意事项。打标签前核对候选提交的 CI，发布后再从 GitHub 和 Gitee 的实际标签入口验证安装。

## 文档同步

新增文件或改变模块职责时，请同步更新：

1. [ASDF 系统与模块地图](01-asdf-system-map.md)
2. 对应模块 README
3. 相关标准文档

如果只是内部实现优化，可以只在对应模块的“实现要点”或“修改指南”里补充。

## 文档公开状态

`docs/` 是公开源码仓库的一部分。请把它视为需要维护的契约表面：避免私人笔记、过期的临时判断，以及未公开的研究或合作细节。行为发生变化时，应在同一个变更中同步更新相关开发者文档、规范文档或架构文档。
