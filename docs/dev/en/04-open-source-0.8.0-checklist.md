# TAFFISH 0.8.0 Open-Source Preparation Checklist

This checklist turns the current TAFFISH repository from a binary distribution repository into an open-source repository. The goal is not to reach every maturity milestone of a large open-source project at once. The goal is to make the first open-source 0.8.0 release clear, legally coherent, testable, installable, and free of obvious private or temporary material.

Status: this file is a maintainer release-engineering checklist, not user-facing documentation and not a live feature roadmap. Keep it in the source tree as historical release context for `v0.8.0`; after the release, future open-source release checklists should be created as separate versioned files instead of rewriting this one.

## Release Strategy

- [ ] Confirm whether `v0.8.0` has already been published as an immutable release.
- [ ] If `v0.8.0` has not been formally published, define it as the first open-source release.
- [ ] If `v0.8.0` was already published as a closed-source binary release, do not rewrite the old tag; use `v0.8.1` or `v0.9.0` as the first open-source release.
- [ ] Create an open-source preparation branch, for example `open-source/v0.8.0`.
- [ ] Do cleanup, testing, and documentation updates on the preparation branch instead of editing an already published tag.

## License And Legal State

- [ ] Decide the core source license.
- [ ] Prefer considering `Apache-2.0` first because it has clearer patent terms than MIT and fits a project with patents, ecosystem ambitions, and possible enterprise usage.
- [ ] If choosing MIT, confirm that the patent boundary is acceptable.
- [ ] If choosing GPL/AGPL, confirm that the propagation requirements are acceptable for commercial and enterprise deployments.
- [ ] If choosing source-available terms, do not call it open source.
- [ ] Replace the root `LICENSE`; remove the Binary Distribution License.
- [ ] Synchronize the `:license` field in `taffish.asd` and `taffish.dev.asd`.
- [ ] If binary releases remain available, clarify whether binaries use the same license as the source or have extra distribution terms.
- [ ] Check generated taf-app license templates so they are not confused with TAFFISH's own license.

## `.gitignore` And Repository Visibility

- [ ] Change `.gitignore` from binary-distribution mode to source-repository mode.
- [ ] Track: `taffish-core/`, `taffish-cli/`, `taf-core/`, `taf-cli/`, `taffish-mcp/`, `vendor/han/`, `docs/`, `completion/`, `vim-highlight/`, `install/`, `*.asd`, and `load-taffish*.lisp`.
- [ ] Ignore: `*.fasl`, ASDF cache, temporary files, system files, editor backups, generated test directories, and local release-signing scratch files.
- [ ] Keep only intentional versioned release payloads under `target/` tracked by git for the 0.8.0 raw installer interface.
- [ ] Decide whether `target/` should stay in git.
- [ ] Short term: keeping `target/` in git can keep the installer simple.
- [ ] Long term: move binaries to GitHub Release assets and keep only source, installers, and verification files in git.
- [ ] Run `git status --ignored --short` and confirm no source file that should be public is still ignored.

## Private Information And Secret Cleanup

- [ ] Scan the whole repository for private paths, account names, tokens, secrets, and machine names.
- [ ] Replace personal paths in tests with neutral examples such as `/home/alice` and `/tmp/work`.
- [ ] Replace personal names in tests with neutral examples such as `alice`.
- [ ] Confirm there are no private GitHub tokens, Gitee tokens, SSH keys, or API keys.
- [ ] Confirm docs do not expose private advisor, collaborator, unpublished platform, or business-collaboration information.
- [ ] Confirm `test/` does not contain private experiments, real data, unauthorized apps, or manual debugging leftovers.
- [ ] Keep Lisp unit tests, but remove private traces from test data.

## README And User Entry

- [ ] Change `README.md` from Binary Distribution to the TAFFISH project homepage.
- [ ] Remove stale text such as "Source code is not published here yet".
- [ ] Add build-from-source instructions.
- [ ] Add test instructions.
- [ ] Clearly introduce the three entrypoints: `taffish`, `taf`, and `taffish-mcp`.
- [ ] Keep binary installation instructions, but separate binary install from source build.
- [ ] Keep China/Gitee installation and mirror configuration instructions.
- [ ] Explain key 0.8.0 capabilities: TAF compiler, local package management, MCP, smoke metadata, and source commit verification.
- [ ] Keep `README.md` and `README-CN.md` structurally aligned.

## Public Docs

- [ ] Update `docs/README.*.md` so they no longer describe `docs/` as ignored internal-only material.
- [ ] Check all docs links and ensure they work after opening the source.
- [ ] Keep docs split into developer manual, standards, and architecture.
- [ ] Mark `compile-taf-program` as experimental or future interface.
- [ ] Review hub/index docs and make sure they describe the current 0.8.0 contract, not only future intent.
- [ ] Keep at least the entry docs, headings, and key standards docs aligned between Chinese and English.

## Code API And Public Boundary

- [ ] Review public package exports.
- [ ] Confirm `compile-taf-program` is not exported in 0.8.0 and is documented only as an internal reserved implementation detail.
- [ ] Decide whether `vendor/han` is a TAFFISH vendored foundation or a future standalone project.
- [ ] Current recommendation: publish it as the TAFFISH vendored foundation first; do not split the repository yet.
- [ ] Confirm production code does not directly use implementation-specific packages such as `sb-ext:`, `system:`, or `uiop:` outside `han.host`, loader code, and tests.
- [ ] Confirm error messages do not expose local development paths.
- [ ] Remove stale commented-out code and temporary debug comments where practical.

## Tests And Quality Gate

- [ ] Full SBCL/macOS test suite passes.
- [ ] Full LispWorks/Linux test suite passes.
- [ ] Add macOS LispWorks tests later if that platform becomes part of distribution.
- [ ] `bash -n install/install-taffish.sh` passes.
- [ ] `bash -n completion/bash/taf` passes.
- [ ] `zsh -n completion/zsh/_taf` passes.
- [ ] If fish is available, run `fish -n completion/fish/taf.fish`.
- [ ] `git diff --check` passes.
- [ ] `taf --version`, `taffish --version`, and `taffish-mcp --version` print the expected version.
- [ ] Manually smoke-test `taf new`, `taf check`, `taf build`, `taf install --from`, and `taf publish --dry-run`.
- [ ] Test `taffish-mcp` with an MCP client or a manual JSON-RPC request for tools/list and key tools.

## CI And Automation

- [ ] Full CI is not required for the first open-source release, but define a minimal plan.
- [ ] Minimal CI can start with SBCL tests, shell syntax checks, and completion syntax checks.
- [ ] LispWorks CI can remain a manual local release gate because of licensing.
- [ ] If CI is not ready, state in the README or release checklist that LispWorks binaries are built and tested manually by the maintainer.
- [ ] Add artifact attestation later when release binaries are built by GitHub Actions.

## Release Artifacts And Supply-Chain Security

- [ ] Confirm 0.8.0 binary file names:
- [ ] `taf-darwin-arm64-0.8.0`
- [ ] `taffish-darwin-arm64-0.8.0`
- [ ] `taffish-mcp-darwin-arm64-0.8.0`
- [ ] `taf-linux-amd64-0.8.0`
- [ ] `taffish-linux-amd64-0.8.0`
- [ ] `taffish-mcp-linux-amd64-0.8.0`
- [ ] Generate `SHA256SUMS`.
- [ ] Sign `SHA256SUMS` with the TAFFISH release GPG key.
- [ ] Publish the release public key, for example `TAFFISH-RELEASE-KEY.asc`.
- [ ] Document how users can verify SHA256 and signatures.
- [ ] Do not claim provenance or reproducible builds until GitHub Actions provenance exists.
- [ ] For taf-app ecosystem security, rely on hub index metadata: `source.commit`, container digest, platforms, and smoke results.

## Hub / Index Integration

- [ ] Confirm 0.8.0 index schema docs include `source.commit`, container digest, platforms, and smoke metadata.
- [ ] Confirm `taf install` verifies Git HEAD and clean worktree when the index provides `source.commit`.
- [ ] Confirm taffish-index automation only includes containerized apps after smoke checks pass.
- [ ] Confirm existing app/version-release records are not re-smoked unless version or release changes.
- [ ] Confirm `taf info` can display digest, platforms, smoke, and source commit.
- [ ] Confirm `taf which` and `taf list --local --json` can display local install origin and source commit.

## GitHub Repository Governance

- [ ] Enable release/tag protection or rulesets.
- [ ] Keep releases immutable.
- [ ] Add issue templates if issues are enabled.
- [ ] Add `SECURITY.md` for vulnerability reporting.
- [ ] Add `CONTRIBUTING.md` with contribution, testing, and style expectations.
- [ ] Optional: add `CODE_OF_CONDUCT.md`.
- [ ] Decide whether the default branch requires PR review.
- [ ] Keep GitHub Actions permissions minimal.

## Final Commands Before The 0.8.0 Open-Source Release

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

Run the following on the LispWorks/Linux machine:

```sh
(han.test:run-all-tests)
./target/taf-linux-amd64-0.8.0 --version
./target/taffish-linux-amd64-0.8.0 --version
./target/taffish-mcp-linux-amd64-0.8.0 --version
```

## Acceptance Criteria For The First Source-Visible Release

- [ ] A fresh reader can understand what TAFFISH is, how to install it, how to build it from source, and how to run tests.
- [ ] License, README, and ASDF metadata are consistent.
- [ ] Source code, tests, and docs are tracked by git.
- [ ] No obvious private paths, account names, secrets, or temporary artifacts remain.
- [ ] Current tests pass on both SBCL and LispWorks.
- [ ] 0.8.0 supply-chain-related features are consistent between code and docs.
- [ ] Binary installation still works.
- [ ] The old "binary distribution repository" narrative has been replaced by the "TAFFISH open-source source repository" narrative.

## Items That Can Wait Until 0.8.x / 0.9.0

- [ ] Full GitHub Actions release pipeline.
- [ ] GitHub artifact attestation.
- [ ] Reproducible builds.
- [ ] Automatic SBOM generation.
- [ ] Moving `target/` out of git and into release assets.
- [ ] More complete external contributor guide.
- [ ] More detailed issue/PR templates.
- [ ] Splitting `vendor/han` into a standalone repository.
