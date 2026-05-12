# han.path Path Tools

`han.path` wraps Common Lisp pathname behavior and basic filesystem operations. Its goal is to let upper layers deal less directly with implementation-specific pathname details.

## Role

Common Lisp pathname is powerful, but it can be error-prone across implementations, platforms, string inputs, and directory-path detection. `han.path` provides a more direct set of helpers.

## Core APIs

| API | Role |
| --- | --- |
| `->pathname` | Convert string/pathname to pathname and normalize the directory list. |
| `->namestring` | Convert to namestring. |
| `directory-pathname-p` | Check whether a pathname looks like a directory pathname. |
| `directory-pathname` | Convert file-like input to a directory pathname. |
| `parent-directory-pathname` | Return the directory containing a file; directory input stays directory. |
| `join-path` | Merge path fragments from left to right. |
| `absolute-pathname-p` | Check whether a path is absolute. |
| `absolute-pathname` | Resolve a path to absolute form relative to a base. |
| `relative-path` | Compute relative path when host/device are the same. |
| `file-exists-p` | Return pathname when a file exists. |
| `directory-exists-p` | Return directory pathname when a directory exists. |
| `directory-files` | Direct child files. |
| `subdirectories` | Direct child directories. |
| `copy-file` | Copy a file. |
| `delete-directory-tree` | Recursively delete a directory. |
| `temporary-directory` | Temporary directory. |

## directory-pathname

`directory-pathname` treats:

```text
/tmp/foo
```

as a directory path:

```text
/tmp/foo/
```

This is common in TAFFISH because home, apps, index, and target paths are mostly directories.

## join-path

`join-path` uses `merge-pathnames` to merge fragments from left to right. For example:

```lisp
(han.path:join-path "/tmp/" "taffish" "index" "current.json")
```

It is suitable for constructing paths inside TAFFISH home.

## relative-path

`relative-path` only computes a true relative path when target and base share the same host/device. Otherwise it returns target directly. This avoids constructing invalid relative paths across devices.

## Filesystem Operations

File and directory operations ultimately delegate to `han.host`. This means implementation differences are handled by the host layer, while `han.path` focuses on path semantics.

## Modification Guide

When changing path logic, check:

1. Directory conventions in `taf-core/system/home.lisp`.
2. Snapshot and target paths in `taf-core/project/build.lisp`.
3. Install root and launcher paths in `hub/install/uninstall/list/which`.
4. Do not bypass safety checks in `delete-directory-tree`.

