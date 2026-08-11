# project/publish

`project/publish.lisp` publishes taf-app projects to GitHub. It is the most
cautious step in the project lifecycle and is implemented as an inspect/ensure
state machine rather than a rollback transaction.

## Role

Publish handles:

1. Project and LICENSE checks.
2. Repository, policy, commit, branch, tag, and Release inspection.
3. Optional local command-wrapper build.
4. git initialization, origin setup, commit, tag, and push.
5. Optional GitHub repository creation and release-policy setup.
6. Optional GitHub Release creation.
7. Automatic continuation after an interrupted matching publish.

The default is dry-run, so it does not publish or write a publish journal.

## State Machine

The ordered phases are:

```text
project-validated
repository-ready
repository-policy-ready
commit-ready
branch-pushed
local-tag-ready
remote-tag-ready
github-release-ready
publish-complete
```

Every mutable phase follows the same rule:

1. Inspect the current local or remote fact.
2. Skip an object that already matches the intended release.
3. Create a missing object.
4. Inspect again after the mutation, including after a command reports failure.
5. Stop on conflicting or still-unavailable facts.

This is roll-forward recovery. Publish never deletes, force-updates, or
overwrites a tag or GitHub Release to simulate rollback.

## Automatic Resume

No separate `--resume` option is required. Run the same command again:

```sh
taf publish --release --yes --build
```

TAFFISH re-inspects Git and GitHub. Matching completed phases are skipped and
only missing phases are performed. A fully completed rerun is a successful
no-op. Typical outcomes are:

| Outcome | Meaning |
| --- | --- |
| `planned` | Dry-run only; no mutation was performed. |
| `created` | A new publication completed. |
| `resumed` | A matching partial publication was completed. |
| `skipped` | The publication was already complete. |

If a local tag, remote tag, repository identity, visibility, release notes, or
other immutable identity differs, publish raises a conflict instead of
continuing.

## Publish Journal

Non-dry-run publication records intent and last-known progress under:

```text
$TAFFISH_USER_HOME/history/publish/<owner>--<repo>/<tag>.json
```

The journal records the repository, tag, target commit, release intent,
repository-policy intent, last processed phase, and last confirmed phase. It is
supporting evidence, not the source of truth. Every rerun still inspects local
Git and GitHub. A missing or corrupt journal does not authorize an overwrite.

## Tag And Version Rule

Tag name:

```text
v<version>-r<release>
```

The `latest` channel requires the current version/release to be newer than the
latest other remote release. `--pre` permits a non-latest publication; it does
not weaken tag identity checks.

## GitHub URL Recognition

Publish accepts canonical GitHub forms such as:

1. `https://github.com/owner/repo`
2. `git@github.com:owner/repo`
3. `ssh://git@github.com/owner/repo`

Repository and origin comparisons normalize these forms to the owner/repo
slug. Publish remains GitHub-only; Gitee is a read/install mirror.

## Non-Interactive Authentication

TAFFISH does not handle GitHub login. Default execution disables interactive
Git/GitHub credential prompts. Users must configure SSH keys, a Git credential
helper, or `gh auth login` outside TAFFISH.

Read-only remote queries use bounded retries for likely network failures.
Mutations are not blindly retried: after a reported failure, TAFFISH first
re-inspects the corresponding remote fact. If it still cannot confirm the
result, the error reports the failed phase and last confirmed phase and asks the
user to rerun the same command after connectivity is restored.

## `release.md`

With `--release`:

1. The project root must contain a non-empty `release.md`.
2. Its first line must not be the default TODO summary.
3. The first line enters the commit message.
4. The full content becomes GitHub Release notes.
5. Normalized release notes are hashed into the immutable publish intent.

`release.md` is removed from the git index before committing.

## Repository Creation And Policy

When `--create-repo` creates a repository, the default safe path also ensures
immutable GitHub Releases and the TAFFISH release-tag ruleset. `--no-lock-repo`
explicitly opts out. Publish does not silently retrofit policy onto every
pre-existing repository.

## History And Return Data

Publish history distinguishes `created`, `resumed`, `skipped`, `conflict`, and
`failed`. `project-publish` preserves its existing result fields and adds
structured `:outcome`, `:phases`, `:resumed-p`, `:complete-p`, `:journal-file`,
and `:warnings` fields.

## Modification Guide

When changing publish:

1. Preserve dry-run as a no-side-effect operation.
2. Keep GitHub authentication external.
3. Inspect after every remote mutation; do not blindly retry writes.
4. Never force, delete, or overwrite immutable tags or Releases.
5. Treat journals as hints and Git/GitHub facts as authoritative.
6. Add fault-injection tests at every new side-effect boundary.
7. Keep publish outside the MCP mutation surface.
