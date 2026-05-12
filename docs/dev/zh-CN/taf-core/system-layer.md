# taf-core 系统层

系统层位于 `taf-core/system/`，负责 TAFFISH 在本机上的目录、配置、历史和诊断。

## 作用

系统层提供 `taf` 正常运行所需的环境基础。它回答这些问题：

1. TAFFISH 的系统目录在哪里？
2. 用户目录在哪里？
3. index、apps、images、bin、cache、logs 放在哪里？
4. 默认配置是什么？
5. 用户如何覆盖配置？
6. 如何记录历史和诊断环境？

## 核心文件

| 文件 | 作用 |
| --- | --- |
| `home.lisp` | 定义系统与用户目录约定。 |
| `config.lisp` | 定义配置 schema、默认值、读取与合并逻辑。 |
| `history.lisp` | 记录系统历史事件。 |
| `doctor.lisp` | 诊断系统环境。 |

## home 目录约定

系统层区分系统目录和用户目录。典型目录包括：

| 目录类型 | 意义 |
| --- | --- |
| system home | TAFFISH 系统级安装根。 |
| system bin | 系统命令链接或可执行入口。 |
| user home | 用户级数据根。 |
| apps | 已安装 taf-app。 |
| index | 本地 hub index。 |
| images | 容器或镜像相关缓存。 |
| bin | 用户级命令入口。 |
| cache | 临时缓存。 |
| share | 共享数据。 |
| logs | 日志。 |

目录约定会影响安装、卸载、which、doctor 等多个功能。修改时必须检查 hub 和 project 子系统。

## config 契约

当前配置 schema 为：

```text
taffish.config/v1
```

配置层支持默认配置、本地配置文件和环境变量覆盖。它还包含 GitHub/Gitee source rewrite 的默认设定，使 TAFFISH 可以服务不同网络环境。

常见覆盖来源包括：

1. `TAFFISH_CONFIG`
2. `TAFFISH_INDEX_URL`
3. 本地配置文件中的 `[index]`
4. 本地配置文件中的 `[[source.rewrite]]`

## 修改指南

修改系统层时应谨慎，因为它会影响用户安装状态。应检查：

1. 老用户目录是否仍能被识别。
2. config schema 是否需要升级。
3. 默认 GitHub/Gitee 规则是否正确。
4. doctor 是否能发现新配置或新依赖的问题。
5. history 是否记录了有助于排查问题的事件。
