# hub/install、uninstall

`hub/install.lisp` 和 `hub/uninstall.lisp` 管理 TAFFISH app 的本地安装状态。

## install 的作用

`hub-install` 把 hub index 中的一个 package/version 安装到 TAFFISH home：

1. 解析 query 和 version。
2. 解析 source URL，并应用 source rewrite。
3. 解析依赖。
4. clone 或复制源码。
5. 如果 index 提供 `source.commit`，校验 Git `HEAD` 和干净工作区。
6. 调用 `project-build` 构建 command wrapper。
7. 写 launcher。
8. 写 install metadata。
9. 刷新 command alias。

`hub-install-from-project` 用于安装本地/私有 TAFFISH 项目，不读取 index。它会先运行
`project-check`，根据本地 `taffish.toml` 构造内存中的安装记录，然后复用同一套安装
pipeline，记录来源为 `[local-project] <PROJECT-DIR>`。第一版不自动安装依赖。

## 安装目录

某个 package/version 的安装根：

```text
apps/<package-name>/<version-id>/
```

内部主要包含：

```text
source/
install.json
```

命令入口放在：

```text
bin/<artifact-name>
bin/<command-name>
```

其中 artifact launcher 指向精确版本，command alias 指向该 command 的最新已安装版本。

## install metadata

`install.json` schema 为：

```text
taffish.install/v1
```

它记录：

1. scope。
2. package name。
3. version id。
4. artifact name。
5. command name。
6. command file。
7. launcher file。
8. bin dir。
9. install root。
10. source dir。
11. repository/source/ref/commit。
12. 运行 commit 校验时的 actual/verified source commit。
13. origin kind/value/display。

`list`、`which`、`uninstall` 都依赖这个 metadata。

## source URL 与 rewrite

source URL 来源优先级：

1. record 的 `source.local_path`。
2. record 的 `source.clone_url`。
3. record 的 `source.repository_url`。
4. record 的 `repository_url`。

安装前会调用 system config 的 source rewrite。china profile 会把 GitHub source 改写到 Gitee 镜像。

如果 record 包含 `source.commit`，install 会在 build 前校验 resolved source：

1. `git rev-parse HEAD` 必须等于 `source.commit`。
2. `git status --porcelain --untracked-files=all` 必须为空。
3. commit 不匹配或源码工作区不干净都会中止安装，并触发清理。

这样 mirror/source-rewrite 安装可以保持可审计，而不需要改写 app 源码。

## 依赖安装

record 中的 `dependencies` 必须是 object。依赖 version 可以是：

1. 字符串。
2. 字符串数组。
3. `latest`、`*` 或空值，表示 latest。

install 会递归安装依赖，并用 `*hub-install-stack*` 检测循环依赖。

## force 与 dry-run

`force-p` 允许替换已存在 install root 或 launcher。`dry-run-p` 只返回计划结果，不 clone、不 build、不写文件。

安装失败时会清理已写 launcher 和 install root，避免半安装状态。

## uninstall 的作用

`hub-uninstall` 根据 query 和可选 version-id 找到已安装 entry，然后删除：

1. install root。
2. artifact launcher。
3. command alias，如果 alias 确实指向该 command file。

卸载后会刷新 command alias，使它指向剩余版本中最新的一个。如果没有剩余版本，则删除 alias。

## query 匹配

uninstall 可以匹配：

1. package name。
2. artifact name。
3. command base。

如果多个版本匹配且没有指定 version-id，会要求用户明确版本。

## 修改指南

修改 install/uninstall 时要检查：

1. `install.json` schema 是否仍和 list/which/uninstall 兼容。
2. alias 刷新是否正确处理多版本。
3. source rewrite 是否只在 config 层定义。
4. 失败清理是否完整。
5. 递归依赖是否能避免循环。
6. dry-run 是否不产生副作用。
7. source commit 校验是否仍发生在 `project-build` 之前。
