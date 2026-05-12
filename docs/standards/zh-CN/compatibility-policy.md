# 兼容性策略

本页定义 TAFFISH 规范草案下的兼容性策略。它的目标不是阻止 TAFFISH 进化，而是让每一次进化都有边界、有迁移路径、有可验证的行为。

## 兼容对象

TAFFISH 需要保护的对象包括：

1. 已存在的 `.taf` 源文件。
2. 已存在的 taf-app 项目目录。
3. 已发布到 hub index 的版本记录。
4. 已安装到用户 TAFFISH home 的 app 与 launcher。
5. 已生成的 command wrapper。
6. 已写入的 `config.toml`、`install.json` 和 `history.jsonl`。

## 合规结果

人工检查或未来自动一致性测试应给出三类结果：

| 结果 | 含义 | 处理方式 |
| --- | --- | --- |
| 合格 | 满足当前规范草案的必须项。 | 可以发布、安装或作为测试基线。 |
| 警告 | 依赖当前实现细节、legacy 字段或未稳定行为。 | 可以继续，但需要记录迁移风险。 |
| 失败 | 违反必须项，可能破坏解析、安装、复现或卸载。 | 不应发布；应修复项目、index 或实现。 |

合规检查不等于科学正确性检查。一个 taf-app 可以完全符合 TAFFISH 规范，但生物信息学参数仍然不合理；这类问题属于应用层审查。

## 兼容优先级

兼容性优先级从高到低为：

| 优先级 | 对象 | 原因 |
| --- | --- | --- |
| P0 | 已发布 taf-app 的安装与运行 | 用户已经依赖。 |
| P1 | hub index schema 与查询行为 | 影响安装、搜索、列表和复现。 |
| P2 | `.taf` 语言核心语义 | 影响所有工具和流程。 |
| P3 | 项目构建与发布流程 | 影响开发者。 |
| P4 | 内部 API 与内部文件组织 | 主要影响 TAFFISH 开发者。 |

## 允许的兼容变化

通常允许：

1. 添加新的可选字段。
2. 添加新的标签或 emitter。
3. 添加新的 CLI 选项。
4. 放宽输入格式，但不改变已有输入的含义。
5. 增强错误信息。
6. 增加新的 schema 版本，同时继续读取旧版本。

## 需要迁移的变化

以下变化必须提供迁移策略：

1. 删除或重命名已有字段。
2. 改变已有字段的数据类型。
3. 改变 artifact 命名规则。
4. 改变默认安装目录。
5. 改变 command alias 指向规则。
6. 改变容器后端选择顺序或默认挂载语义。
7. 改变 `.taf` 中已有标签的语义。

迁移策略至少应说明：

1. 旧格式如何识别。
2. 旧格式是否继续支持。
3. 如果不继续支持，用户如何升级。
4. 是否需要自动迁移工具。
5. 是否需要在 `taf doctor` 中提示。

## schema 版本策略

TAFFISH 当前使用字符串 schema 版本：

| schema | 当前版本 | 文件 |
| --- | --- | --- |
| hub index | `taffish.index/v1` | `index/current.json` 与 snapshots。 |
| install metadata | `taffish.install/v1` | `apps/<name>/<version-id>/install.json`。 |
| config | `taffish.config/v1` | `config.toml`。 |
| list JSON 输出 | `taffish.list/v1` | `taf list --json` 输出。 |
| which JSON 输出 | `taffish.which/v1` | `taf which --json` 输出。 |

读取持久化文件时，遇到未知 schema 应报错，而不是静默猜测。命令输出 schema 可以独立演进。

## 弃用策略

弃用一个行为时，应尽量经历三个阶段：

1. 保持支持，并在文档中标记为 legacy。
2. 在命令输出或检查中给出提示。
3. 在下一个破坏性版本中删除。

当前代码中 `[container].platforms` 是 `[container].build_platforms` 的 legacy 兼容字段。两者同时存在且值不一致时，应报错。

## 一致性测试方向

未来应建立一致性测试集合，至少覆盖：

1. TAF lexer/parser/binder/compiler 的黄金输出。
2. `taffish.toml` schema 验证。
3. hub index 读取、搜索、解析和安装目标解析。
4. install metadata 的读写和 uninstall 兼容。
5. config merge、index URL 解析、source rewrite。
6. container backend 选择与生成 shell 的关键片段。

一致性测试不是当前规范草案的前置条件，但它是规范走向 `v1.0` 的必要条件。
