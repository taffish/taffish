# TAFFISH 0.8.0 开源准备 Checklist

这份 checklist 用于把当前 TAFFISH 仓库从“二进制分发仓库”切换为“开源仓库”。目标不是一次性做到大型开源项目的全部成熟度，而是确保 0.8.0 作为首个开源版本时，仓库身份清楚、法律状态清楚、安装和测试路径可复现、没有明显私人信息或临时产物。

状态：本文是维护者 release engineering checklist，不是用户文档，也不是实时功能路线图。建议把它保留在源码树中，作为 `v0.8.0` 的历史发布上下文；发布后未来版本的开源发布 checklist 应创建新的版本化文件，而不是继续改写本文。

## 发布策略

- [ ] 确认 `v0.8.0` 是否尚未作为不可变 release 发布。
- [ ] 如果 `v0.8.0` 尚未正式发布，则把 `v0.8.0` 定义为 first open-source release。
- [ ] 如果 `v0.8.0` 已经作为闭源二进制 release 发布过，则不要重写旧 tag，改用 `v0.8.1` 或 `v0.9.0` 作为首个开源版本。
- [ ] 建立开源准备分支，例如 `open-source/v0.8.0`。
- [ ] 在准备分支上完成清理、测试和文档更新，不直接在已发布 tag 上修改历史。

## License 和法律状态

- [ ] 决定核心源码 license。
- [ ] 推荐优先考虑 `Apache-2.0`，因为它比 MIT 更明确地处理专利授权，适合 TAFFISH 这种有专利、生态和企业使用潜力的项目。
- [ ] 如果选择 MIT，需要确认专利授权边界是否符合预期。
- [ ] 如果选择 GPL/AGPL，需要确认是否接受对商业集成和企业部署的传播限制。
- [ ] 如果选择 source-available，则不要称为 open source。
- [ ] 更新根目录 `LICENSE`，移除 Binary Distribution License。
- [ ] 同步 `taffish.asd` 和 `taffish.dev.asd` 中的 `:license` 字段。
- [ ] 如果保留二进制 release，需要说明二进制和源码使用同一 license，或额外说明二进制分发条款。
- [ ] 检查自动生成 taf-app license template，确保它和 TAFFISH 自身 license 不混淆。

## `.gitignore` 和仓库可见性

- [ ] 把当前“忽略一切，只放二进制分发文件”的 `.gitignore` 改为源码仓库模式。
- [ ] 应纳入版本控制：`taffish-core/`、`taffish-cli/`、`taf-core/`、`taf-cli/`、`taffish-mcp/`、`vendor/han/`、`docs/`、`completion/`、`vim-highlight/`、`install/`、`*.asd`、`load-taffish*.lisp`。
- [ ] 应忽略：`*.fasl`、ASDF cache、临时文件、系统文件、编辑器备份、测试生成目录、本地 release 签名临时文件。
- [ ] 0.8.0 为保持 raw 安装器接口，应只把 `target/` 下有意发布的版本化 release 载荷纳入 git。
- [ ] 决定 `target/` 是否继续进入 git。
- [ ] 短期可继续提交 `target/` 二进制以保持安装器简单。
- [ ] 长期建议把二进制移到 GitHub Release assets，并在 git 中只保留源码、安装器和校验文件。
- [ ] 检查 `git status --ignored --short`，确认没有应该公开的源码仍被忽略。

## 私人信息和敏感信息清理

- [ ] 全仓库扫描个人路径、账号、token、secret、临时机器名。
- [ ] 将测试中的个人路径替换为中性路径，例如 `/home/alice`、`/tmp/work`。
- [ ] 将测试中的个人昵称替换为中性示例，例如 `alice`。
- [ ] 确认没有私有 GitHub token、Gitee token、SSH key、API key。
- [ ] 确认 docs 中没有不适合公开的导师、合作者、未公开平台或商业合作信息。
- [ ] 确认 `test/` 目录中没有私人实验项目、真实数据、未授权 app 或手动调试残留。
- [ ] 保留 Lisp 单元测试文件，但清理测试数据中的私人痕迹。

## README 和用户入口

- [ ] 把 `README.md` 标题从 Binary Distribution 改为 TAFFISH 项目主页。
- [ ] 删除“Source code is not published here yet”之类的旧状态说明。
- [ ] 增加源码构建说明。
- [ ] 增加运行测试说明。
- [ ] 明确三个入口：`taffish`、`taf`、`taffish-mcp`。
- [ ] 保留二进制安装说明，但区分“从二进制安装”和“从源码构建”。
- [ ] 保留中国地区 Gitee 安装说明和镜像源配置说明。
- [ ] 说明 0.8.0 的关键能力：TAF 编译器、本地包管理、MCP、smoke metadata、source commit verification。
- [ ] README-CN 和 README 保持结构一致。

## Docs 公开化

- [ ] 把 `docs/README.*.md` 中“内部文档”“docs 被 .gitignore 忽略”的状态说明改为公开开发者文档说明。
- [ ] 检查 docs 中所有链接，确保开源后路径可访问。
- [ ] 明确 docs 分层：developer manual、standards、architecture。
- [ ] 将 `compile-taf-program` 未实现状态标为 experimental 或 future interface。
- [ ] 检查 hub/index 相关文档，确认它们描述的是当前 0.8.0 契约，而不是未完成愿景。
- [ ] 确认中英文文档至少在入口、标题和关键标准文档上同步。

## 代码 API 和公开边界

- [ ] 确认 public package exports 是否都应该公开。
- [ ] 确认 `compile-taf-program` 在 0.8.0 中不导出，并且仅作为内部保留实现细节记录。
- [ ] 确认 `vendor/han` 是随 TAFFISH 一起公开的内部基础库，还是未来独立项目。
- [ ] 当前建议：先作为 TAFFISH vendored foundation 公开，不急着拆仓库。
- [ ] 确认生产代码不直接使用实现专属包，例如 `sb-ext:`、`system:`、`uiop:`，除 `han.host`、loader、测试之外。
- [ ] 确认 error message 不暴露本地开发路径。
- [ ] 检查旧注释、注释掉的旧 error 代码、临时 debug 注释；能删的开源前删掉。

## 测试和质量门槛

- [ ] SBCL/macOS 完整测试通过。
- [ ] LispWorks/Linux 完整测试通过。
- [ ] 如果有 macOS LispWorks，未来补 macOS LispWorks 测试。
- [ ] `bash -n install/install-taffish.sh` 通过。
- [ ] `bash -n completion/bash/taf` 通过。
- [ ] `zsh -n completion/zsh/_taf` 通过。
- [ ] 如果本机有 fish，运行 `fish -n completion/fish/taf.fish`。
- [ ] `git diff --check` 通过。
- [ ] `taf --version`、`taffish --version`、`taffish-mcp --version` 输出正确。
- [ ] 对 `taf new`、`taf check`、`taf build`、`taf install --from`、`taf publish --dry-run` 做至少一轮手动 smoke。
- [ ] 对 `taffish-mcp` 用一个 MCP 客户端或 JSON-RPC 手工请求做至少一轮 tools/list 和关键 tool 调用。

## CI 和自动化

- [ ] 首个开源版本不强制要求完整 CI，但应规划最小 CI。
- [ ] 最小 CI 可先只做 SBCL 测试、shell syntax、completion syntax。
- [ ] LispWorks CI 因授权问题可以先保留为本地手动 release gate。
- [ ] 如果暂时没有 CI，在 README 或 release checklist 中明确“LispWorks binary is built and tested manually by maintainer”。
- [ ] 未来把 release 二进制从手动上传升级为 GitHub Actions 构建时，再加入 artifact attestation。

## Release artifacts 和供应链安全

- [ ] 为 0.8.0 release 明确二进制文件名：
- [ ] `taf-darwin-arm64-0.8.0`
- [ ] `taffish-darwin-arm64-0.8.0`
- [ ] `taffish-mcp-darwin-arm64-0.8.0`
- [ ] `taf-linux-amd64-0.8.0`
- [ ] `taffish-linux-amd64-0.8.0`
- [ ] `taffish-mcp-linux-amd64-0.8.0`
- [ ] 生成 `SHA256SUMS`。
- [ ] 用 TAFFISH release GPG key 对 `SHA256SUMS` 签名。
- [ ] 公开 release public key，例如 `TAFFISH-RELEASE-KEY.asc`。
- [ ] README 说明如何校验 SHA256 和签名。
- [ ] 如果还没有 GitHub Actions provenance，不要声称 release 已有 provenance 或 reproducible build。
- [ ] 对 taf-app 生态的供应链安全由 hub index 负责：`source.commit`、container digest、platforms、smoke result。

## Hub / Index 配合

- [ ] 确认 0.8.0 的 index schema 文档包含 `source.commit`、container digest、platforms、smoke metadata。
- [ ] 确认 `taf install` 在 index 提供 `source.commit` 时会校验 Git HEAD 和 clean worktree。
- [ ] 确认 taffish-index 自动化只收录通过 smoke 的 containerized app。
- [ ] 确认已经存在的 app/version-release 不重复 smoke，除非版本或 release 改变。
- [ ] 确认 `taf info` 能显示 digest、platforms、smoke 和 source commit。
- [ ] 确认 `taf which` 和 `taf list --local --json` 能显示本地安装 origin 和 source commit。

## GitHub 仓库治理

- [ ] 开启 release/tag 保护或 ruleset。
- [ ] 保持 release immutable。
- [ ] 如果公开 issue，需要准备 issue template。
- [ ] 添加 `SECURITY.md`，说明安全问题如何报告。
- [ ] 添加 `CONTRIBUTING.md`，说明贡献方式、测试要求和编码约定。
- [ ] 可选：添加 `CODE_OF_CONDUCT.md`。
- [ ] 确认默认分支保护策略是否需要 PR review。
- [ ] 确认 GitHub Actions 权限最小化。

## 0.8.0 开源发布前最终命令

```sh
git status --short
git diff --check

sbcl --load load-taffish.dev.lisp \
  --eval '(han.test:run-all-tests)' \
  --quit

bash -n install/install-taffish.sh
bash -n install/install-taffish.gitee.sh
bash -n completion/bash/taf
bash -n completion/bash/taffish
zsh -n completion/zsh/_taf
zsh -n completion/zsh/_taffish

./target/taf-darwin-arm64-0.8.0 --version
./target/taffish-darwin-arm64-0.8.0 --version
./target/taffish-mcp-darwin-arm64-0.8.0 --version
```

LispWorks/Linux 端需要在对应机器上额外运行：

```sh
(han.test:run-all-tests)
./target/taf-linux-amd64-0.8.0 --version
./target/taffish-linux-amd64-0.8.0 --version
./target/taffish-mcp-linux-amd64-0.8.0 --version
```

## 首个开源版本验收标准

- [ ] 仓库 clone 后，读者能理解 TAFFISH 是什么、如何安装、如何从源码构建、如何运行测试。
- [ ] license、README、ASDF metadata 一致。
- [ ] 源码、测试、docs 都进入 git 管理。
- [ ] 没有明显私人路径、账号、secret 或临时产物。
- [ ] 当前测试在 SBCL 和 LispWorks 两侧通过。
- [ ] 0.8.0 的新增供应链安全能力在文档和代码中一致。
- [ ] 二进制安装方式仍然可用。
- [ ] 旧的“二进制分发仓库”叙述已经切换为“TAFFISH 开源源码仓库”叙述。

## 可以延后到 0.8.x / 0.9.0 的事项

- [ ] 完整 GitHub Actions release pipeline。
- [ ] GitHub artifact attestation。
- [ ] 可复现构建。
- [ ] 自动生成 SBOM。
- [ ] `target/` 从 git 迁移到 release assets。
- [ ] 更完整的外部贡献者指南。
- [ ] 更精细的 issue/PR 模板。
- [ ] 独立拆分 `vendor/han` 为单独仓库。
