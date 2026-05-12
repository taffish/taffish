# project/publish

`project/publish.lisp` 负责把 taf-app 项目发布到 GitHub。它是项目生命周期中最谨慎的一步。

## 作用

publish 负责：

1. 检查项目。
2. 检查 LICENSE。
3. 检查远程 tag。
4. 可选 build。
5. git init、remote、commit、tag、push。
6. 可选创建 GitHub repository。
7. 可选创建 GitHub release。

默认是 dry-run，不会实际发布。

## tag 规则

tag 名称为：

```text
v<version>-r<release>
```

例如：

```text
v0.1.0-r1
```

publish 会解析远程 tags，并比较 version/release。`latest` channel 要求当前版本高于远程 latest；否则应使用 `pre` channel。

## GitHub URL 识别

publish 支持解析：

1. `https://github.com/owner/repo`
2. `git@github.com:owner/repo`
3. `ssh://git@github.com/owner/repo`

比较 remote origin 时会归一化 owner/repo slug。

## 非交互认证策略

TAFFISH 不负责 GitHub 登录。默认非交互执行时会设置：

1. `GIT_TERMINAL_PROMPT=0`
2. `GIT_ASKPASS=`
3. `SSH_ASKPASS=`
4. `GH_PROMPT_DISABLED=1`
5. `GH_NO_UPDATE_NOTIFIER=1`
6. `GIT_SSH_COMMAND=ssh -o BatchMode=yes`

如果认证失败，错误会提示用户自行配置 SSH key、git credential helper 或在 TAFFISH 外运行 `gh auth login`。

## release.md

如果启用 release：

1. 项目根必须有 `release.md`。
2. 文件不能为空。
3. 第一行不能仍包含 TODO。
4. 第一行会进入 commit message。
5. 完整内容用于 GitHub release notes。

发布 release 时，`release.md` 会从 git index 中移除，避免把临时 release notes 提交到项目仓库。

## LICENSE 检查

publish 要求 LICENSE 存在、非空，并且不是 placeholder。这个检查是发布门槛。

## dry-run 计划

dry-run 会输出计划命令，包括：

1. 可能的 `gh repo create`。
2. git init。
3. remote add。
4. git add。
5. git commit。
6. git tag。
7. git push。
8. 可选 `gh release create`。

这使用户能在真正发布前理解会发生什么。

## 修改指南

修改 publish 时要特别谨慎：

1. 不要让 TAFFISH 静默处理用户认证。
2. destructive git 操作必须非常克制。
3. dry-run 输出应保持可信。
4. tag 比较规则应和 hub version 排序一致。
5. GitHub 专属逻辑未来如果要支持 Gitee 发布，应抽象为更高层发布后端，而不是简单塞进当前函数。
