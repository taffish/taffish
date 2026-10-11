# project/publish

`project/publish.lisp` 负责把 taf-app 项目发布到 GitHub。它是项目生命周期中
最谨慎的一步，内部实现是 inspect/ensure 状态机，而不是可以回滚的数据库事务。

## 作用

publish 负责：

1. 检查项目与 LICENSE。
2. 检查 repository、policy、commit、branch、tag 和 Release。
3. 可选构建本地 command wrapper。
4. git 初始化、origin 配置、commit、tag 与 push。
5. 可选创建 GitHub repository 并配置发布保护策略。
6. 可选创建 GitHub Release。
7. 在匹配的发布过程中断后自动继续。

默认是 dry-run，不会发布，也不会写 publish journal。

## 状态机

发布阶段依次为：

```text
project-validated
repository-ready
repository-policy-ready
build-ready                 # 仅在请求 --build 时存在
commit-ready
branch-pushed
local-tag-ready
remote-tag-ready
github-release-ready
publish-complete
```

每个可能产生副作用的阶段都遵循同一规则：

1. 先检查当前本地或远端事实。
2. 已存在且与发布意图一致时跳过。
3. 缺失时创建。
4. 创建命令无论成功或报错，都重新检查对应事实。
5. 事实冲突或仍不可确认时停止。

这是向前恢复，而不是回滚。publish 不会通过删除、force-update 或覆盖 tag/Release
来伪造事务回滚。

## 自动断点续跑

不需要新增 `--resume` 参数。网络或命令中断后，重新运行完全相同的命令即可：

```sh
taf publish --release --yes --build
```

TAFFISH 会重新检查 Git 与 GitHub，跳过已经匹配的阶段，只补齐缺失阶段。已经完整
发布时，同一命令会成为成功的 no-op。典型 outcome 为：

| outcome | 含义 |
| --- | --- |
| `planned` | 仅 dry-run，没有执行修改。 |
| `created` | 完成了一次全新发布。 |
| `resumed` | 补齐并完成了一次匹配的中断发布。 |
| `skipped` | 该发布已经完整存在。 |

如果 local tag、remote tag、repository 身份、visibility、release notes 或其他不可变
身份不一致，publish 会报 conflict，而不是继续覆盖。

## `--build` 协同

`--build` 也进入 inspect/ensure 模型，不会在每次命令开始时无条件重复运行：

1. dry-run 只记录 planned `build-ready` 阶段，不写 build 产物。
2. 发布 commit 尚未存在时，publish 调用幂等的 command build。
3. 未变化且有效的 wrapper/snapshot 会直接接受，不重写文件。
4. 匹配的发布 commit、local tag 或 remote tag 身份一旦建立，续跑会校验本地 clean
   commit 身份并跳过 build。
5. 越过该边界后若本地状态 dirty 或冲突，会在触碰 target 产物前失败。

publish journal 会记录是否请求 build，因此续跑命令不能静默增加或删除 `--build`。
Git 与 GitHub 身份仍是事实来源；journal 不会授权跳过不一致的 build。

## Publish Journal

非 dry-run 发布会在以下位置记录发布意图和最近进度：

```text
$TAFFISH_USER_HOME/history/publish/<owner>--<repo>/<tag>.json
```

journal 记录 repository、tag、目标 commit、build 意图、Release 意图、repository policy 意图、
最近处理阶段与最后确认阶段。它只是辅助证据，不是事实来源。每次重跑仍会检查本地
Git 和 GitHub；journal 缺失或损坏也不会授权覆盖远端对象。

## Tag 与版本规则

tag 名称为：

```text
v<version>-r<release>
```

发布不以版本大小作为准入条件。只要新的固定身份合法且不冲突，即使版本低于历史版本
也可以发布，不要求上游版本改成严格 SemVer。已有 tag 只有在 commit 和发布意图一致时
才能续跑或成为 no-op，不允许覆盖不同内容。

使用 `--release` 时选择一个渠道：

| 选项 | 新建 GitHub Release 的行为 |
| --- | --- |
| 默认或 `--latest` | 正式发布，明确设为 Latest。 |
| `--pre` | 预发布，明确不设为 Latest。 |
| `--no-latest` | 正式发布但不设为 Latest，例如旧维护分支修复。 |

三个选项互斥。未使用 `--release` 时仍然只发布 tag；渠道选项不会创建 Release，也不会
设置 GitHub Latest 或 Pre-release 状态。版本字符串含 `alpha`、`rc` 不会自动选择
`--pre`。这里不管理名为 `latest` 的 Git tag 或容器镜像。

dry-run 和正式执行共用 Release 参数构造函数。创建时使用 `--verify-tag`，防止 GitHub
CLI 从默认分支自行补建缺失 tag。检查 Release 时校验 tag、标题、归一化说明、draft 和
prerelease 类型。身份/类型字段缺失或异常属于 unavailable，不当成匹配；冲突的 Release
不会被自动修改或重建。

新 journal 保存 `channel` 和 `latest_policy`，重试时改变策略会报冲突。旧日志仍可读取，
但已有 Release 的真实类型必须匹配。旧版 `--pre` 实际创建了正式 Release 时，不会静默
转换类型；如果 Release 尚未创建，则采用本次请求的渠道。
渠道不匹配的尝试不会覆盖已有 journal 的意图；旧日志缺失的渠道字段只在 Release
状态核对成功后补齐，避免错误重试导致之后的正确重试无法恢复。

Latest 是创建时策略，不是 Release 的不可变身份。如果 A 发布后 B 已成为 Latest，
再次执行 A 的发布命令仍是 no-op，不会抢回 Latest。网络响应丢失时继续使用已有
inspect/ensure 阶段核对事实，不盲目重复创建或修改。

API 旧返回字段 `:remote-latest` 为兼容仍保留排序诊断含义，但不代表 GitHub Latest，
不再作为发布门槛，也不再显示成人类可读的默认版本推荐。共享 Hub 比较器和 Index 选择
不属于这个 publish 策略的修改范围。

## GitHub URL 识别

publish 接受以下 GitHub canonical 形式：

1. `https://github.com/owner/repo`
2. `git@github.com:owner/repo`
3. `ssh://git@github.com/owner/repo`

repository 与 origin 比较时会归一化为 owner/repo slug。publish 仍然只面向 GitHub；
Gitee 是读取与安装镜像。

## 非交互认证与网络策略

TAFFISH 不负责 GitHub 登录。默认执行会关闭 Git/GitHub 的交互式凭据提示；用户需要
在 TAFFISH 外配置 SSH key、Git credential helper 或运行 `gh auth login`。

只读远端查询会对疑似网络错误做有限重试。修改操作不会盲目重试：命令报错后先重新
检查远端事实。如果仍不能确认，错误会给出失败阶段与最后确认阶段，并要求网络恢复后
重新运行同一条 publish 命令。

## `release.md`

使用 `--release` 时：

1. 项目根必须有非空的 `release.md`。
2. 第一行不能保留默认 TODO 摘要。
3. 第一行会进入 commit message。
4. 完整内容会成为 GitHub Release notes。
5. 归一化后的 notes 哈希会成为不可变发布意图的一部分。

归一化会把 CRLF/CR 转换为 LF，并忽略末尾换行，因为 GitHub 可能为保存后的 Release
body 添加一个最终 LF。内部换行、普通空格和其他所有正文仍属于严格身份的一部分。

commit 前会把 `release.md` 从 git index 中移除。

## Repository 创建与保护策略

使用 `--create-repo` 新建 repository 时，默认安全路径还会确保 immutable GitHub
Releases 和 TAFFISH release-tag ruleset。`--no-lock-repo` 可以显式跳过。publish
不会无条件改造所有已经存在的 repository。

## History 与返回值

publish history 会区分 `created`、`resumed`、`skipped`、`conflict` 和 `failed`。
`project-publish` 保留原有返回字段，并增加结构化的 `:outcome`、`:phases`、
`:resumed-p`、`:complete-p`、`:journal-file`、`:warnings` 与 `:build-status`。实际运行
build 时，旧有 `:build` 字段保存其结果；发布身份已经建立而跳过 build 时，该字段可以为空。

## 修改指南

修改 publish 时必须：

1. 保持 dry-run 完全无副作用。
2. 保持 GitHub 认证由用户在外部管理。
3. 每次远端修改后都重新检查，不盲目重试写操作。
4. 绝不 force、删除或覆盖不可变 tag/Release。
5. journal 只作提示，Git/GitHub 事实优先。
6. 每增加一个副作用边界，都增加对应故障注入测试。
7. publish 始终位于 MCP 修改能力边界之外。

## 操作状态提示

慢操作会在 stderr 提示当前目标与阶段。TTY 更新、日志限频、目标计数的含义、
静默/JSON 行为及限制见[命令状态与进度](command-progress.md)。提示不改变校验、写操作、重试或退出码规则。
