# project/new

`project/new.lisp` implements `project-new`, which generates a new taf-app project skeleton.

## Role

`taf new` does more than create a directory. It generates a minimal project that can be checked, built, and published:

```text
<project>/
  taffish.toml
  src/main.taf
  docs/help.md
  README.md
  LICENSE
  .gitignore
  release.md
  target/.gitkeep
  docker/Dockerfile                 optional
  .github/workflows/build-image.yml optional
```

## Input Arguments

`project-new` uses `han.args` to parse arguments:

| Argument | Default | Role |
| --- | --- | --- |
| `--tool` / `-t` | false | Create a tool. |
| `--flow` / `-f` | false | Create a flow. |
| `--version` / `-v` | `0.1.0` | Initial version. |
| `--release` / `-r` | `1` | Initial release; must be a positive integer. |
| `--license` / `-l` | `Apache-2.0` | License template. |
| `--repo` / `-g` | default GitHub URL | Repository URL. |
| `--image` / `-i` | nil | Explicit container image. |
| `--docker` / `-d` | false | Generate Dockerfile and default GHCR image. |
| `--no-actions` | false | Do not generate GitHub Actions. |

If neither tool nor flow is specified, flow is created by default.

## taffish.toml Generation

`%make-taffish-toml-string` generates core metadata:

1. `[package]`
2. `[repository]`
3. `[command]`
4. `[runtime]`
5. Optional `[container]`
6. Optional `[smoke]` for containerized projects

It intentionally does not generate optional ecosystem metadata sections such as
`[meta]` and `[upstream]`. The default skeleton should stay small and locally
usable. Hub maintainers can add those sections manually when preparing an app
for public discovery, categorization, and upstream provenance tracking.

Tool default:

```toml
[runtime]
pipe = true
command_mode = true
```

Flow default:

```toml
[runtime]
pipe = false
command_mode = false
```

## main.taf Generation

Flow default:

```taf
<taffish>
echo '<flow>[name: version] Hello, World!'
```

Tool default:

```taf
<taf-app:shell>
echo '<tool>[name: version] Hello, World!'
```

If image is set, the tool entry becomes `taf-app:container:<image>`.

## Docker And Actions

If `--docker` is enabled:

1. Generate `docker/Dockerfile`.
2. Default image is derived as `ghcr.io/taffish/<name>:<version>-r<release>`.
3. Generate GitHub Actions workflow by default, unless `--no-actions` is passed.

The Actions workflow reads `taffish.toml`, builds amd64 and optional arm64 images, and publishes a manifest.

Containerized projects also get a default smoke template:

```toml
[smoke]
backend = "docker"
timeout = 60
exist = ["TODO"]
test = ["TODO --help"]
```

The template is intentionally a TODO placeholder. `taf check` rejects these
default values, so maintainers must replace them with app-specific checks before
the project is considered valid for publish/index.

## License

Currently only the Apache-2.0 template is supported. Other licenses are errors.

## Modification Guide

When changing `project/new`, also check:

1. Whether `project/check` still accepts the new skeleton, except for intended placeholders such as default smoke TODO values.
2. Whether `project/build` can build the new skeleton.
3. Whether `project/publish` can publish the new skeleton.
4. Whether Hub index generation needs to adapt to new fields.
5. Whether default Actions still match the current GitHub/GHCR strategy.
