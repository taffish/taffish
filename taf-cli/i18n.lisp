(in-package :taf.cli)

;;;; ============================================================
;;;; i18n.lisp
;;;; ============================================================

(defparameter *taf-help-zh*
  (list
   (cons nil
         "用法：
  taf [-h | --help]
  taf [-v | --version]
  taf help [COMMAND]
  taf <COMMAND> [-h | --help]
  taf <COMMAND> [ARGS...]

项目命令：
  new         创建新的 TAFFISH app 项目
  check       检查当前 TAFFISH app 项目
  compile     编译当前项目并输出 shell 代码
  build       构建版本化命令包装器或镜像
  run         编译并运行当前项目
  publish     将当前项目发布到 GitHub

Hub 命令：
  update      更新本地 TAFFISH index
  search      在本地 index 中搜索 app
  info        显示 index 中的 app/版本信息
  install     从 index 或本地项目安装 app
  outdated    显示落后于本地 index 的已安装 app
  upgrade     安装 index 中较新的版本
  prune       删除本地已安装的旧版本
  uninstall   卸载本地 app 或命令
  list        列出已安装或 index 中的 app
  which       显示本地路径和元数据

系统命令：
  doctor      检查或初始化 TAFFISH 环境
  config      显示或管理 TAFFISH 运行时配置
  history     显示或清理本地执行历史

语言：
  taf config language             显示当前语言及可用语言
  taf config language auto        跟随主机 locale [默认]
  taf config language zh          将内置中文保存为首选语言
  TAFFISH_LANGUAGE=en taf --help  仅为单次命令覆盖语言

示例：
  taf help install
  taf update
  taf install fastqc
  taf run -- --help")
   (cons "new"
         (format nil "用法：
  taf new [-h | --help]
  taf new <APP-NAME> [OPTIONS]

创建新的 TAFFISH app 项目。

生成的文件包含一个被忽略的 release.md 草稿，供 `taf publish --release` 使用。

选项：
  -t, --tool                创建 tool 项目
  -f, --flow                创建 flow 项目 [默认]
  -v, --version <VERSION>   设置版本，默认 0.1.0
  -r, --release <RELEASE>   设置 release，默认 1
  -l, --license <LICENSE>   设置许可证模板，默认 Apache-2.0
  -g, --repo <URL>          设置仓库 URL
                            [https://~A/~A/<APP-NAME>]
  -i, --image <IMAGE>       设置容器镜像
  -d, --docker              创建 docker/Dockerfile，并添加容器元数据和
                            GitHub Actions workflow
                            [~A/~A/<APP-NAME>:<VERSION>-r<RELEASE>]
      --no-actions          使用 --docker 时不创建 GitHub Actions workflow
  -h, --help                显示此帮助"
                 taf.core:*default-github-host*
                 taf.core:*default-github-owner*
                 taf.core:*default-container-registry*
                 taf.core:*default-github-owner*))
   (cons "check"
         "用法：
  taf check [-h | --help]
  taf check

检查当前 TAFFISH app 项目。

细节：
  - 从当前目录向上查找 taffish.toml
  - 校验必需文件以及 package/repository/command 元数据
  - 为容器化项目校验 container、build 和 smoke 元数据
  - 解析主 .taf 文件并校验依赖与镜像一致性
  - 输出项目摘要

选项：
  -h, --help                显示此帮助")
   (cons "compile"
         "用法：
  taf compile [-h | --help]
  taf compile [ARGS...]
  taf compile -- [ARGS...]

把当前 TAFFISH app 项目编译为 shell 代码。

细节：
  - 从当前目录向上查找 taffish.toml
  - 读取 [package].main 指定的项目主 .taf 文件
  - 将 ARGS 传给该 .taf 程序
  - 将生成的 shell 代码输出到 STDOUT

选项：
  -h, --help                显示此帮助

注意：
  如需把 -h 传给 .taf 程序，请使用 `taf compile -- -h`。")
   (cons "build"
         "用法：
  taf build [-h | --help]
  taf build
  taf build [-i | --image | -d | --docker] [-b | --backend <docker|podman>]
  taf build [-a | --all] [-b | --backend <docker|podman>]

构建当前 TAFFISH app 项目。

细节：
  - 不带选项时只构建带版本的命令 wrapper
  - --image/--docker 只构建容器镜像
  - --all 同时构建命令 wrapper 和容器镜像
  - 将冻结的源码快照保存到 target/.<artifact>

选项：
  -i, --image                  只构建容器镜像
  -d, --docker                 只构建容器镜像
  -a, --all                    构建容器镜像和命令 wrapper
  -b, --backend <docker|podman>
                               选择镜像构建后端
  -h, --help                   显示此帮助

生成的命令：
  target/<command-name>-v<version>-r<release>

生成的命令使用冻结快照，而不是实时 src 文件。")
   (cons "run"
         "用法：
  taf run [-h | --help]
  taf run [-b | --backend <docker|podman|apptainer>] [ARGS...]
  taf run [-b | --backend <docker|podman|apptainer>] -- [ARGS...]

编译并运行当前 TAFFISH app 项目。

细节：
  - 从当前目录向上查找 taffish.toml
  - 将 [package].main 编译到临时 shell 文件
  - 运行该 shell 文件，并继承 STDOUT/STDERR
  - 仅当当前 STDIN 来自 pipe/file 时才传递 STDIN
  - 将 ARGS 传给 .taf 程序
  - 未给出 --backend 时使用
    TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker
  - TAFFISH_DOCKER_RUN_ARGS、TAFFISH_PODMAN_RUN_ARGS 和
    TAFFISH_APPTAINER_RUN_ARGS 追加本地后端专用运行参数

选项：
  -b, --backend <docker|podman|apptainer>
                            强制通用 <container:...> tag 使用指定后端
  -h, --help                显示此帮助

注意：
  当 .taf 程序需要类似选项的参数时，请在 ARGS 前使用 `--`，
  例如 `taf run -- -h` 或 `taf run -- --backend value`。")
   (cons "publish"
         "用法：
  taf publish [-h | --help]
  taf publish [-n | --dry-run] [--latest | --pre] [-b | --build]
              [-r | --release] [--create-repo] [--public | --private]
              [--no-lock-repo] [--prompt]
  taf publish [-y | --yes] [--latest | --pre] [-b | --build]
              [-r | --release] [--create-repo] [--public | --private]
              [--no-lock-repo] [--prompt]

将当前 TAFFISH app 项目发布到 GitHub 仓库。

细节：
  - 首先运行 taf check
  - 从 taffish.toml 读取 [repository].url
  - 检查名为 v<version>-r<release> 的远端 tag
  - 除非给出 --prompt，否则远端 git 检查为非交互模式
  - 使用 --release 时读取 release.md 并创建 GitHub release
  - 使用 --create-repo 时可以创建 GitHub 仓库
  - 新建仓库默认会锁定：启用 immutable releases，并保护 v* tag
    使其不能被更新或删除
  - 发布中断后重新运行完全相同的命令；已匹配的 repository、tag 和 release
    阶段会被跳过，包括已由 --create-repo 创建的仓库
  - 已完整匹配的发布不会重复执行发布修改，并以成功结束
  - 拒绝冲突的 commit、tag、release 或已改变的发布意图
  - 仅在给出 --yes 时执行 commit、tag、push 和可选 release 创建

选项：
  -n, --dry-run              仅输出发布计划 [默认]
  -y, --yes                  执行 commit、tag、push 和 release
  -b, --build                发布前构建命令 wrapper
  -r, --release              读取项目根目录的 release.md：
                              第一行作为发布消息；整个文件作为
                              GitHub release notes
  --latest                   要求版本比远端最新版本更新 [默认]
  --pre                      允许发布非最新的预发布 tag
  --create-repo              仓库不存在时创建 GitHub 仓库
  --public                   将缺失仓库创建为 public [默认]
  --private                  将缺失仓库创建为 private
  --no-lock-repo             不锁定新创建的仓库
  --prompt                   允许 git 在终端询问凭据
  -h, --help                 显示此帮助

注意：
  TAF 不管理 GitHub 登录。未使用 --prompt 时，远端 git 命令会快速失败，
  而不会询问凭据。")
   (cons "update"
         "用法：
  taf update [-h | --help]
  taf update [-u | --user | -s | --system] [--url <INDEX-URL>] [-y | --yes]

更新本地 TAFFISH index 缓存。

细节：
  - 下载静态 TAFFISH index JSON 文件
  - 为选定 scope 写入 index/current.json
  - 在 index/snapshots/ 下保存带时间戳的副本
  - 未给出 --url 时读取 TAFFISH_INDEX_URL
  - 默认使用官方 taffish index

选项：
  -u, --user                更新用户级 index [默认]
  -s, --system              更新系统级 index
  --url <INDEX-URL>         覆盖 index URL 或使用本地 index 文件
  -y, --yes                 为非交互兼容性接受此选项
  -h, --help                显示此帮助")
   (cons "search"
         "用法：
  taf search [-h | --help]
  taf search [-u | --user | -s | --system] [-j | --json]
             [-l | --limit <N>] <KEYWORD...>

从本地 index 搜索 TAFFISH app。

细节：
  - 读取选定 scope 的 index/current.json
  - 匹配 package 名、命令名、kind、version、repository 和 image
  - 多个关键词按 AND 处理
  - 默认显示 20 个结果
  - 本地 index 缺失时请先运行 `taf update`

选项：
  -u, --user                读取用户级 index [默认]
  -s, --system              读取系统级 index
  -j, --json                以 JSON 输出搜索结果
  -l, --limit <N>           限制结果数量，默认 20
  -h, --help                显示此帮助")
   (cons "info"
         "用法：
  taf info [-h | --help]
  taf info [-u | --user | -s | --system] [-j | --json]
           <APP-NAME|TAF-COMMAND>...
  taf info [-u | --user | -s | --system] [-j | --json]
           <APP-NAME|TAF-COMMAND> <VERSION-ID>

显示本地 index 中的 TAFFISH app 信息。

细节：
  - 读取选定 scope 的 index/current.json
  - 显示 package 最新版本和所有 index 版本
  - 接受 package 名，例如 my-tool
  - 接受命令名，例如 taf-my-tool
  - 接受精确版本命令名，例如 taf-my-tool-v0.1.0-r1
  - 一次可接受多个 app/command 目标
  - 省略 VERSION-ID 时默认使用 package 最新版本
  - VERSION-ID 可带或不带前导 v，例如 0.1.0-r1
  - 批量指定精确版本时，优先使用精确版本命令名
  - --json 对单个目标输出 object，对多个目标输出 array
  - 本地 index 缺失时请先运行 `taf update`

选项：
  -u, --user                读取用户级 index [默认]
  -s, --system              读取系统级 index
  -j, --json                以 JSON 输出解析后的版本记录
  -h, --help                显示此帮助")
   (cons "install"
         "用法：
  taf install [-h | --help]
  taf install [OPTIONS] <APP-NAME|TAF-COMMAND>...
  taf install [OPTIONS] <APP-NAME|TAF-COMMAND> <VERSION-ID>
  taf install [OPTIONS] --from <PROJECT-DIR>
  taf install [OPTIONS] --all

从本地 index 或本地项目安装 TAFFISH app。

模式：
  indexed target       从 index/current.json 安装一个或多个 app/command
  indexed exact        按明确 VERSION-ID 安装一个 app/command
  local project        使用 --from <PROJECT-DIR> 安装私有项目
  batch index          按 --kind 选择并计划或安装所有 index app

细节：
  - 接受 package 名，例如 my-tool
  - 接受命令名，例如 taf-my-tool
  - 接受精确版本命令名，例如 taf-my-tool-v0.1.0-r1
  - 省略 VERSION-ID 时默认使用 package 最新版本
  - 首先安装选定版本记录声明的依赖
  - 安装精确命令，例如 taf-my-tool-v0.1.0-r1
  - 将无版本命令别名（例如 taf-my-tool）刷新到本地已安装的最新版本
  - 本地 index 缺失时请先运行 `taf update`
  - --from 向上查找 taffish.toml，并将来源记录为
    [local-project] <PROJECT-ROOT>；此模式不读取 index
  - --all 默认为 dry-run；使用 --yes 才执行安装

选项：
  -u, --user                安装到用户 home [默认]
  -s, --system              将 app 数据安装到系统 home，并将命令安装到
                            TAFFISH_SYSTEM_BIN_DIR [/usr/local/bin]
  -n, --dry-run             输出安装计划，不修改文件
  -y, --yes                 执行 --all 安装计划；仅可与 --all 一起使用
  -f, --force               替换此版本的已有安装
  -a, --all                 安装 --kind 选中的所有 index app
  -k, --kind <KIND>         按 tool、flow 或 all 过滤 --all [all]
      --tools               --kind tool 的快捷形式
      --flows               --kind flow 的快捷形式
      --prune-old           --all 后只保留本地最新版本
  -j, --json                以 JSON 输出 --all 计划/结果；仅可与 --all 使用
  --from <PROJECT-DIR>      从本地 TAFFISH 项目目录安装
  --prompt                  允许 git 在终端询问凭据
  -h, --help                显示此帮助

示例：
  taf install fastqc
  taf install taf-fastqc-v0.12.1-r1
  taf install --from .
  taf install --all --tools --yes")
   (cons "outdated"
         "用法：
  taf outdated [-h | --help]
  taf outdated [-u | --user | -s | --system] [-a | --all] [-j | --json]
               [-k | --kind <tool|flow|all>] [APP-NAME|TAF-COMMAND...]

显示比本地 index 更旧的已安装 TAFFISH app。

细节：
  - 读取本地安装元数据和 index/current.json
  - 不给出目标时检查所有本地已安装 app
  - 默认文本只显示变化；全部为最新时输出 no changes
  - --json 为自动化保留 current/skipped 项
  - 本地/私有 --from 安装显示为 skipped，不会升级
  - 使用 taf upgrade 执行 install-latest 动作

选项：
  -u, --user                检查用户 home [默认]
  -s, --system              检查系统 home
  -a, --all                 明确检查所有已安装 app [默认]
  -k, --kind <KIND>         按 tool、flow 或 all 过滤 [all]
      --tools               --kind tool 的快捷形式
      --flows               --kind flow 的快捷形式
  -j, --json                以 JSON 输出结果
  -h, --help                显示此帮助

示例：
  taf outdated
  taf outdated --json
  taf outdated --tools taf-fastqc")
   (cons "upgrade"
         "用法：
  taf upgrade [-h | --help]
  taf upgrade [-u | --user | -s | --system] [-n | --dry-run | -y | --yes]
              [-a | --all] [-k | --kind <tool|flow|all>] [-f | --force]
              [--prompt] [--prune-old] [-j | --json]
              [APP-NAME|TAF-COMMAND...]

为本地已安装的 TAFFISH app 安装较新的 index 版本。

细节：
  - 不给出目标时检查所有本地已安装 app
  - 默认为 dry-run；使用 --yes 才执行计划
  - 默认文本只显示变化；全部为最新时输出 no changes
  - --json 为自动化保留 current/skipped 项
  - 跳过本地/私有 --from 安装
  - --prune-old 在升级成功后删除本地旧版本

选项：
  -u, --user                升级用户 home [默认]
  -s, --system              升级系统 home
  -n, --dry-run             输出升级计划，不修改文件 [默认]
  -y, --yes                 执行升级计划
  -f, --force               必要时替换已有安装路径
  -a, --all                 明确升级所有已安装 app [默认]
  -k, --kind <KIND>         按 tool、flow 或 all 过滤 [all]
      --tools               --kind tool 的快捷形式
      --flows               --kind flow 的快捷形式
      --prune-old           升级后只保留本地最新版本
      --prompt              允许 git 在终端询问凭据
  -j, --json                以 JSON 输出结果
  -h, --help                显示此帮助

示例：
  taf upgrade
  taf upgrade --yes
  taf upgrade taf-fastqc --yes --prune-old")
   (cons "prune"
         "用法：
  taf prune [-h | --help]
  taf prune [-u | --user | -s | --system] [-n | --dry-run | -y | --yes]
            [-a | --all] [-k | --kind <tool|flow|all>] [-j | --json]
            [APP-NAME|TAF-COMMAND...]

删除本地已安装的 TAFFISH app 旧版本。

细节：
  - 不给出目标时检查所有本地已安装 app
  - 为每个选定 app 保留本地最新版本
  - 默认为 dry-run；使用 --yes 才删除旧版本
  - 默认文本只显示可删除版本；没有变化时输出 no changes
  - 保留共享容器镜像和 SIF 文件

选项：
  -u, --user                清理用户 home [默认]
  -s, --system              清理系统 home
  -n, --dry-run             输出清理计划，不执行删除 [默认]
  -y, --yes                 执行清理计划
  -a, --all                 明确清理所有已安装 app [默认]
  -k, --kind <KIND>         按 tool、flow 或 all 过滤 [all]
      --tools               --kind tool 的快捷形式
      --flows               --kind flow 的快捷形式
  -j, --json                以 JSON 输出结果
  -h, --help                显示此帮助

示例：
  taf prune
  taf prune --yes
  taf prune --kind flow --yes")
   (cons "uninstall"
         "用法：
  taf uninstall [-h | --help]
  taf uninstall [-u | --user | -s | --system] [-n | --dry-run]
                [-f | --force]
                <APP-NAME|TAF-COMMAND>...
  taf uninstall [-u | --user | -s | --system] [-n | --dry-run]
                [-f | --force]
                <APP-NAME|TAF-COMMAND> <VERSION-ID>

从本地 TAFFISH home 卸载 TAFFISH app。

细节：
  - 读取本地安装元数据，而不是在线 index
  - 接受 package 名，例如 my-tool
  - 接受命令名，例如 taf-my-tool
  - 接受精确版本命令名，例如 taf-my-tool-v0.1.0-r1
  - 一次可接受多个 app/command 目标
  - 删除 apps/<APP-NAME>/<VERSION-ID>/ 和精确命令 launcher
  - 将无版本命令别名刷新到剩余的本地最新版本；无版本剩余时删除别名
  - 保留共享容器镜像和 SIF 文件
  - 省略 VERSION-ID 时必须恰好匹配一个已安装版本
  - 批量指定精确版本时，优先使用精确版本命令名

选项：
  -u, --user                从用户 home 卸载 [默认]
  -s, --system              从系统 home 卸载
  -n, --dry-run             输出卸载计划，不修改文件
  -f, --force               app 未安装时不报错
  -h, --help                显示此帮助")
   (cons "list"
         "用法：
  taf list [-h | --help]
  taf list [-l | --local | -o | --online] [-u | --user | -s | --system]
           [-j | --json] [-n | --limit <N>]

列出 TAFFISH app。

细节：
  - --local 从安装元数据列出本地已安装 app 版本
  - --online 从 index/current.json 列出 index app
  - 默认为 --local 和 --user
  - --online 读取本地 index 缓存，因此请先运行 `taf update`
  - --limit 限制文本或 JSON 项目数量

选项：
  -l, --local, --installed  列出本地已安装 app 版本 [默认]
  -o, --online, --index     从本地 index 缓存列出 app
  -u, --user                读取用户 home [默认]
  -s, --system              读取系统 home
  -j, --json                以 JSON 输出结果
  -n, --limit <N>           限制结果数量
  -h, --help                显示此帮助")
   (cons "which"
         "用法：
  taf which [-h | --help]
  taf which [-u | --user | -s | --system] [-j | --json]
            <APP-NAME|TAF-COMMAND>...
  taf which [-u | --user | -s | --system] [-j | --json]
            <APP-NAME|TAF-COMMAND> <VERSION-ID>

显示 TAFFISH 命令的本地安装路径和元数据。

细节：
  - 读取本地安装元数据，而不是在线 index
  - 接受 package 名，例如 my-tool
  - 接受命令名，例如 taf-my-tool
  - 接受精确版本命令名，例如 taf-my-tool-v0.1.0-r1
  - 一次可接受多个 app/command 目标
  - 显示 launcher、冻结命令文件、源码快照和安装元数据
  - 省略 VERSION-ID 时必须恰好匹配一个已安装版本
  - 批量指定精确版本时，优先使用精确版本命令名
  - --json 对单个目标输出 object，对多个目标输出 array

选项：
  -u, --user                搜索用户 home [默认]
  -s, --system              搜索系统 home
  -j, --json                以 JSON 输出结果
  -h, --help                显示此帮助")
   (cons "doctor"
         "用法：
  taf doctor [-h | --help]
  taf doctor [-u | --user | -s | --system] [--shell SHELL]
  taf doctor [-i | --init] [-u | --user | -s | --system]
  taf doctor [-j | --json | --verbose] [--shell SHELL]

检查或初始化本地 TAFFISH 环境。

细节：
  - 解析 TAFFISH_USER_HOME、TAFFISH_SYSTEM_HOME 和 TAFFISH_SYSTEM_BIN_DIR
  - 检查 home/config/index、PATH、补全、Vim、SIF 缓存和容器后端
  - 对 docker、podman 和 apptainer 使用有时限探测，不运行 app
  - 报告 mksquashfs、squashfuse、fuse2fs 和 gocryptfs 可用性
  - 不编辑 shell/Vim 配置、权限、服务或容器状态
  - --init 为选定 scope 创建缺失目录
  - --system --init 需要 root 权限

选项：
  -i, --init                创建缺失的 TAFFISH home 目录
  -u, --user                检查或初始化用户 home [默认]
  -s, --system              检查或初始化系统 home
  -j, --json                输出稳定 JSON 诊断
  --verbose                 为每项检查输出 evidence 和 remediation
  --shell SHELL             检查 auto|bash|zsh|fish [默认：auto]
  -h, --help                显示此帮助")
   (cons "config"
         "用法：
  taf config [-h | --help]
  taf config [show] [-u | --user | -s | --system]
  taf config path [-u | --user | -s | --system]
  taf config init [-u | --user | -s | --system]
                  [--github | --china] [-f | --force]
  taf config language [--show] [-u | --user | -s | --system]
  taf config language <LANGUAGE> [-u | --user | -s | --system]

显示、初始化或管理 TAFFISH 运行时配置。

细节：
  - 若已设置，则读取 TAFFISH_USER_HOME 和 TAFFISH_SYSTEM_HOME
  - 否则回退到 ~/.local/share/taffish 和 /opt/taffish
  - 存在时读取选定 TAFFISH home 中的 config.toml
  - 若已设置，则将 TAFFISH_CONFIG 作为显式配置文件覆盖
  - config 控制 index URL 和安装时的源码 URL 重写
  - language 可列出内置及有效外部语言，也可以保存选择
  - en 和 zh 为内置语言；auto 为默认值并跟随主机 locale
  - 主机 locale 无法识别或缺失时回退英文
  - TAFFISH_LANGUAGE 可临时覆盖已保存的语言
  - 输出当前 apps/index/images/bin/cache/share/logs 路径
  - show/path 不检查、创建或修复目录

选项：
  -u, --user                将用户 home 作为当前 scope 显示 [默认]
  -s, --system              将系统 home 作为当前 scope 显示
  --github                  初始化 GitHub/default profile
  --china                   初始化中国镜像 profile 模板
  --show                    显示语言配置和可用语言
  -f, --force               init 时替换已有配置文件
  -h, --help                显示此帮助

示例：
  taf config language
  taf config language zh
  taf config language auto
  taf config init --china")
   (cons "history"
         "用法：
  taf history [-h | --help]
  taf history [-l | --last <N>] [-j | --json]
  taf history [-i | --id <RUN-ID>] [-j | --json]
  taf history [-p | --path]
  taf history [-c | --clear]

显示本地 TAFFISH 执行历史与溯源信息。

细节：
  - 读取 $TAFFISH_USER_HOME/logs/history.jsonl
  - 记录 taf run、taf build、生成命令执行和成功的 taf publish 事件
  - 默认显示最近 20 个事件
  - 不记录 config/doctor/纯系统命令

选项：
  -l, --last <N>            显示最近 N 个事件，默认 20
  -i, --id <RUN-ID>         按 history id 显示一个事件
  -j, --json                输出原始 JSONL 记录
  -p, --path                输出 history 文件路径
  -c, --clear               清空 history 文件
  -h, --help                显示此帮助")))

(declaim
 (ftype (function () string)
        %get-taf-help-string-english
        %get-taf-new-help-string-english
        %get-taf-check-help-string-english
        %get-taf-compile-help-string-english
        %get-taf-build-help-string-english
        %get-taf-run-help-string-english
        %get-taf-publish-help-string-english
        %get-taf-update-help-string-english
        %get-taf-search-help-string-english
        %get-taf-info-help-string-english
        %get-taf-install-help-string-english
        %get-taf-outdated-help-string-english
        %get-taf-upgrade-help-string-english
        %get-taf-prune-help-string-english
        %get-taf-uninstall-help-string-english
        %get-taf-list-help-string-english
        %get-taf-which-help-string-english
        %get-taf-doctor-help-string-english
        %get-taf-config-help-string-english
        %get-taf-history-help-string-english))

(defun %taf-help-zh (command english)
  (or (cdr (assoc command *taf-help-zh* :test #'equal)) english))

(defun %localized-taf-help (command english)
  (taffish.i18n:help-text "taf" command english
                          (%taf-help-zh command english)))

(defmacro %define-taf-help-wrapper (name command english-name)
  `(defun ,name ()
     (%localized-taf-help ,command (,english-name))))

(%define-taf-help-wrapper %get-taf-help-string nil
                          %get-taf-help-string-english)
(%define-taf-help-wrapper %get-taf-new-help-string "new"
                          %get-taf-new-help-string-english)
(%define-taf-help-wrapper %get-taf-check-help-string "check"
                          %get-taf-check-help-string-english)
(%define-taf-help-wrapper %get-taf-compile-help-string "compile"
                          %get-taf-compile-help-string-english)
(%define-taf-help-wrapper %get-taf-build-help-string "build"
                          %get-taf-build-help-string-english)
(%define-taf-help-wrapper %get-taf-run-help-string "run"
                          %get-taf-run-help-string-english)
(%define-taf-help-wrapper %get-taf-publish-help-string "publish"
                          %get-taf-publish-help-string-english)
(%define-taf-help-wrapper %get-taf-update-help-string "update"
                          %get-taf-update-help-string-english)
(%define-taf-help-wrapper %get-taf-search-help-string "search"
                          %get-taf-search-help-string-english)
(%define-taf-help-wrapper %get-taf-info-help-string "info"
                          %get-taf-info-help-string-english)
(%define-taf-help-wrapper %get-taf-install-help-string "install"
                          %get-taf-install-help-string-english)
(%define-taf-help-wrapper %get-taf-outdated-help-string "outdated"
                          %get-taf-outdated-help-string-english)
(%define-taf-help-wrapper %get-taf-upgrade-help-string "upgrade"
                          %get-taf-upgrade-help-string-english)
(%define-taf-help-wrapper %get-taf-prune-help-string "prune"
                          %get-taf-prune-help-string-english)
(%define-taf-help-wrapper %get-taf-uninstall-help-string "uninstall"
                          %get-taf-uninstall-help-string-english)
(%define-taf-help-wrapper %get-taf-list-help-string "list"
                          %get-taf-list-help-string-english)
(%define-taf-help-wrapper %get-taf-which-help-string "which"
                          %get-taf-which-help-string-english)
(%define-taf-help-wrapper %get-taf-doctor-help-string "doctor"
                          %get-taf-doctor-help-string-english)
(%define-taf-help-wrapper %get-taf-config-help-string "config"
                          %get-taf-config-help-string-english)
(%define-taf-help-wrapper %get-taf-history-help-string "history"
                          %get-taf-history-help-string-english)

(taffish.i18n:register-message
 "taf.cli.unknown-command"
 "Unknown taf command: {arguments}"
 "未知的 taf 命令：{arguments}")

(taffish.i18n:register-message
 "taf.cli.help.unknown-command"
 "[help] unknown command: {command}"
 "[help] 未知命令：{command}")

(taffish.i18n:register-message
 "taf.cli.help.too-many-commands"
 "[help] expected at most one command, got: {arguments}"
 "[help] 最多只能指定一个命令，实际收到：{arguments}")

(taffish.i18n:register-message
 "taf.cli.unknown-option"
 "[{command}] unknown option: {option}"
 "[{command}] 未知选项：{option}")

(taffish.i18n:register-message
 "taf.cli.unknown-option-or-argument"
 "[{command}] unknown option or argument: {option}"
 "[{command}] 未知选项或参数：{option}")

(defun %taf-unknown-command-message (arguments)
  (taffish.i18n:message
   "taf.cli.unknown-command"
   (list (cons "arguments" (prin1-to-string arguments)))))

(defun %taf-help-unknown-command-message (command)
  (taffish.i18n:message
   "taf.cli.help.unknown-command"
   (list (cons "command" (prin1-to-string command)))))

(defun %taf-help-too-many-message (arguments)
  (taffish.i18n:message
   "taf.cli.help.too-many-commands"
   (list (cons "arguments" (prin1-to-string arguments)))))

(defun %taf-unknown-option-message (command option)
  (taffish.i18n:message
   "taf.cli.unknown-option"
   (list (cons "command" command)
         (cons "option" (prin1-to-string option)))))

(defun %taf-unknown-option-or-argument-message (command option)
  (taffish.i18n:message
   "taf.cli.unknown-option-or-argument"
   (list (cons "command" command)
         (cons "option" (prin1-to-string option)))))
