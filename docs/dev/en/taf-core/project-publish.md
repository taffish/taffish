# project/publish

`project/publish.lisp` publishes taf-app projects to GitHub. It is the most cautious step in the project lifecycle.

## Role

Publish handles:

1. Project checks.
2. LICENSE checks.
3. Remote tag checks.
4. Optional build.
5. git init, remote, commit, tag, push.
6. Optional GitHub repository creation.
7. Optional GitHub release creation.

The default is dry-run, so it does not actually publish.

## Tag Rule

Tag name:

```text
v<version>-r<release>
```

Example:

```text
v0.1.0-r1
```

Publish parses remote tags and compares version/release. The `latest` channel requires the current version to be greater than the remote latest; otherwise the `pre` channel should be used.

## GitHub URL Recognition

Publish supports parsing:

1. `https://github.com/owner/repo`
2. `git@github.com:owner/repo`
3. `ssh://git@github.com/owner/repo`

When comparing remote origin, it normalizes the owner/repo slug.

## Non-Interactive Authentication Policy

TAFFISH does not handle GitHub login. During default non-interactive execution, it sets:

1. `GIT_TERMINAL_PROMPT=0`
2. `GIT_ASKPASS=`
3. `SSH_ASKPASS=`
4. `GH_PROMPT_DISABLED=1`
5. `GH_NO_UPDATE_NOTIFIER=1`
6. `GIT_SSH_COMMAND=ssh -o BatchMode=yes`

If authentication fails, the error tells users to configure SSH keys, git credential helper, or run `gh auth login` outside TAFFISH.

## release.md

If release is enabled:

1. The project root must contain `release.md`.
2. The file must not be empty.
3. The first line must not still contain TODO.
4. The first line enters the commit message.
5. Full content becomes GitHub release notes.

When publishing a release, `release.md` is removed from the git index to avoid committing temporary release notes into the project repository.

## LICENSE Check

Publish requires LICENSE to exist, be non-empty, and not be a placeholder. This is a publication gate.

## Dry-Run Plan

Dry-run prints planned commands, including:

1. Possible `gh repo create`.
2. git init.
3. remote add.
4. git add.
5. git commit.
6. git tag.
7. git push.
8. Optional `gh release create`.

This lets users understand what will happen before real publication.

## Modification Guide

Be especially careful when changing publish:

1. Do not let TAFFISH silently handle user authentication.
2. Destructive git operations must be highly restrained.
3. Dry-run output should remain trustworthy.
4. Tag comparison should stay consistent with Hub version ordering.
5. If GitHub-specific logic later needs Gitee publishing support, abstract it into a higher-level release backend instead of simply adding it to the current function.

