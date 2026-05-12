# taf-core System Layer

The system layer lives in `taf-core/system/` and owns TAFFISH local directories, config, history, and diagnostics.

## Role

The system layer provides the environment foundation required for normal `taf` operation. It answers:

1. Where is the TAFFISH system directory?
2. Where is the user directory?
3. Where do index, apps, images, bin, cache, and logs live?
4. What is the default config?
5. How can users override config?
6. How are history and environment diagnostics recorded?

## Core Files

| File | Role |
| --- | --- |
| `home.lisp` | Define system and user directory conventions. |
| `config.lisp` | Define config schema, defaults, read and merge logic. |
| `history.lisp` | Record system history events. |
| `doctor.lisp` | Diagnose system environment. |

## Home Directory Conventions

The system layer distinguishes system directories from user directories. Typical directories include:

| Directory type | Meaning |
| --- | --- |
| system home | System-level TAFFISH installation root. |
| system bin | System command links or executable entries. |
| user home | User-level data root. |
| apps | Installed taf-apps. |
| index | Local Hub index. |
| images | Container or image-related cache. |
| bin | User-level command entries. |
| cache | Temporary cache. |
| share | Shared data. |
| logs | Logs. |

Directory conventions affect install, uninstall, which, doctor, and other features. Changes must be checked against Hub and project subsystems.

## Config Contract

Current config schema:

```text
taffish.config/v1
```

The config layer supports default config, local config files, and environment variable overrides. It also contains default GitHub/Gitee source rewrite settings so TAFFISH can serve different network environments.

Common override sources include:

1. `TAFFISH_CONFIG`
2. `TAFFISH_INDEX_URL`
3. `[index]` in local config files
4. `[[source.rewrite]]` in local config files

## Modification Guide

Change the system layer carefully because it affects user installation state. Check:

1. Whether old user directories are still recognized.
2. Whether config schema needs upgrading.
3. Whether default GitHub/Gitee rules are correct.
4. Whether doctor can detect new config or dependency issues.
5. Whether history records events useful for debugging.

