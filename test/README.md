# TAFFISH External Tests

This directory contains shell-level tests for built TAFFISH binaries. These
tests complement the Common Lisp unit tests by exercising the delivered
`taf`, `taffish`, and `taffish-mcp` commands as external programs.

Prerequisites are a POSIX shell with the standard macOS/Linux command-line
utilities, Git, Python 3, `curl`, and the three executable binaries for the current
OS/architecture. The suite is supported on macOS and Linux, matching TAFFISH's
release platforms. Run it from a complete TAFFISH checkout because the i18n
contract also inspects the tracked Bash, Zsh, and Fish completion fixtures.

From the repository root, verify the signed platform archives and run the full suite against the installed native commands:

```sh
scratch=$(mktemp -d)
bash test/ci-release-payloads.sh "$scratch/release"
./test/run-tests.sh --target-dir "$scratch/release/target"
```

This path requires `bash`, `gpg` and `gpgv`. The runner infers the version from `taffish.asd`. When working with versioned executables directly under `target/`, you can omit `--target-dir` or add `--version VERSION` to select a different version.

For local unsuffixed builds:

```sh
./test/run-tests.sh \
  --taf ./target/taf \
  --taffish ./target/taffish \
  --taffish-mcp ./target/taffish-mcp
```

For a current-source SBCL development build that leaves official `target/`
payloads untouched, use a new empty directory outside the checkout:

```sh
build_dir=$(mktemp -d)
sh test/ci-build.sh "$build_dir"
./test/run-tests.sh \
  --taf "$build_dir/taf" \
  --taffish "$build_dir/taffish" \
  --taffish-mcp "$build_dir/taffish-mcp"
```

The build script keeps compilation caches and logs in the selected directory. Public CI runs source builds with SBCL on macOS and Linux and with CCL on Apple Silicon macOS. On unsigned builds, only `installer/gpg-verification` may skip. The two signed-payload jobs require the entire external suite to pass without skips. Maintainers separately build and test the official Linux executables with LispWorks.

For the ECL or Clozure CL developer build, select an installed implementation and a new output directory outside the checkout:

```sh
work=$(mktemp -d)
sh test/source-build.sh ecl "$work/ecl"
# Or: sh test/source-build.sh ccl "$work/ccl"
```

This checks that compiler failure leaves no partial output and that a second build refuses an occupied directory. It builds all three commands and exercises their binary smoke, arguments, stdin and terminal progress using paths with spaces. The resulting commands remain in the chosen directory under `bin/`. See the [source build instructions](../docs/dev/en/build-from-source.md) for prerequisites and running the full suite.

Run `python3 -I test/loader-build.py ccl` or `python3 -I test/loader-build.py ecl` to test the root loader. Each test builds the three executables in the `target/` of a temporary source copy, rebuilds MCP alone, and checks the existing programs, release asset and signature files after a forced compiler error.

Rerun only cases whose names contain a literal substring:

```sh
./test/run-tests.sh --target-dir "$scratch/release/target" --filter publish-resumes
```

The filter is a literal case-name substring. A filter matching no cases fails
instead of reporting a vacuous success.

Use `--filter cli-boundary/` for executable error-boundary regression tests.
These exercise startup path errors, normal compiler diagnostics, unavailable
stderr, broken stdout pipes, SIGINT, and MCP recovery after failed requests.
Every child has a live controlling terminal and an eight-second timeout so an
interactive debugger cannot be mistaken for a successful EOF exit. Both captured
output and terminal output are checked for raw debugger diagnostics. MCP request
and error-reporting stdout must stay protocol-only. SIGINT separately preserves
LispWorks delivery's existing fixed `Interrupted - quitting` stdout notification
and failure exit; the suite does not redefine its global signal handlers.
Linux additionally tests `/dev/full` writes.
Unwritable-output probes use read-only descriptors and broken pipes. Merely
closing stdout/stderr before startup is not a portable write-failure fixture:
the runtime may reuse those descriptor numbers when opening its terminal.
Closed-stderr help probes therefore also force an independent stdout pipe failure;
they still require failure exit, no stdout pollution, and no debugger output.
The MCP transport probe sends a valid `ping` with no reader on its response
pipe. It checks exit status 1 with read-only or closed stderr, and with stderr
on `/dev/full` on Linux. A separate startup failure keeps stdout open and
checks it stays empty when stderr is read-only. The session recovery test
sends a second request after malformed JSON.
Tests do not run containers or contact a remote service. They require rebuilt
binaries containing the error-boundary fix; old binaries intentionally fail.

Each run uses isolated `HOME`, XDG, temporary, TAFFISH home, Git config, and
language state. The ordinary conformance baseline also fixes the child-process
locale to `C`, so Git and other host tools cannot make assertions depend on the
machine's configured language. The i18n suite overrides that baseline
explicitly where locale selection is the behavior under test.

For the complete offline publish subset, use `--filter taf-project/publish`.
It includes version-independent admission (PLINK2-style and maintenance
versions), explicit Latest/Pre-release/non-Latest creation, channel conflicts,
strict Release identity, old/new/missing journals, post-create outage recovery,
tag-only compatibility, and no-op retries that preserve a later Latest pointer.
The fake GitHub transport requires `--verify-tag` and an explicit Latest policy;
these tests do not create any real repository, tag, Release, or container image.

Publish conformance additionally injects a non-English missing-tag diagnostic
through fake Git. This proves that publish state reconciliation uses exact refs
and exit status rather than parsing localized human-readable Git errors.

Successful runs remove the isolated root by default. Failed runs preserve it
automatically and print the path; every case has a complete stdout/stderr log
under `<test-root>/logs/`. Preserve a successful run for inspection with either:

```sh
./test/run-tests.sh --target-dir "$scratch/release/target" --keep-tmp
TAFFISH_TEST_KEEP_TMP=1 ./test/run-tests.sh --version 0.12.0
```

Current suites:

- `binary-smoke.sh`: binary startup, version/help, minimal compilation,
  project, and MCP startup smoke checks.
- `taffish/conformance.sh`: real `taffish` source/stdin compilation behavior,
  argument binding, error paths, and container runtime-argument compilation.
  Tests that inspect generated container commands, including binary smoke, put
  temporary Docker, Podman, and Apptainer commands on the compiler's `PATH`.
  The test fails if the compiler calls one. Coverage includes generic
  `<container:...>` backend selection for structured `$@[...]` arguments,
  plus concurrent delivered-binary
  compilation to catch temporary-file collisions and process cross-talk.
  `taffish/argument-contract.py` adds offline compiler cases for scalar text, block
  token forwarding/display, raw and quoted `*ARGV*`, command-mode shell text,
  three-level compilation, delayed expansion, empty input, source-only inline
  boundaries and non-evaluating failure diagnostics. Run
  `--filter taffish/argument-contract`. Argument counts and
  contents are checked after actual shell execution, including quotes, `$HOME`,
  backslashes, whitespace, and Unicode. Nested tests use shell-only `--compile`
  adapters that invoke the real compiler, not installed Hub apps or containers.
  Empty strings, mixed quotes and `]]` are also checked through nested calls.
  `--filter taffish/argument-contract-inline-` includes SPACE/TAB/mixed separators,
  an explicit `--compile` followed by TAB, and full or indented comment lines
  containing valid, empty or unclosed inline markers. A harmless child records
  NUL-delimited argv and detects accidental entry into its run branch. Project
  checks/builds must discover only real dependencies without invoking children;
  live compilation and frozen wrappers must agree after the source changes.
  MCP source/file compilation must return valid shell without invoking children;
  the test harness then executes that text separately to check its semantics.
  These regressions require rebuilt binaries containing the inline fixes. The
  old release candidates intentionally fail; no real apps or containers run.
  See the bilingual
  [argument guide](../docs/standards/en/argument-passing.md).
- `taf-project/conformance.sh`: `taf-project/inline-source-boundaries` checks
  matching source dependency discovery, live compilation and frozen wrappers.
  The suite also exercises real `taf new/check/compile/build` project
  workflows, built-wrapper behavior, concurrent wrapper pipelines, `taf run`
  stdin forwarding, exact build idempotency including dotless version strings,
  and offline publish transaction recovery at each remote boundary. Fake
  Git/GitHub commands record mutations, exit status, stdout/stderr, and
  before/after state snapshots without contacting a remote service.
  `--filter taf-project/wrapper-history-concurrency` runs 32 instances of a
  generated wrapper and eight native history writers against one file. It matches
  each wrapper's PID, original arguments (including long UTF-8 strings), working directory and
  exit code to its record. It also holds the history lock during append and
  clear, then checks that operations resume after the lock holder is killed.
  While holding the history lock, the caller checks the exit status of both a
  successful tool and a failing tool and reads their stdout and stderr to EOF.
  After unlocking, it checks the corresponding asynchronous records, including
  the original arguments and exit status. It also checks disabled recording and
  history paths containing literal shell and pathname metacharacters.
- `taf-hub/conformance.sh`: real local Hub package-maintenance workflows,
  including `install --all`, `outdated`, `upgrade --prune-old`, and `prune`
  against a temporary local index and local source projects. It also checks
  that default text output hides unchanged/current apps while JSON output keeps
  structured detail, and verifies repeat-install, dry-run, and uninstall
  filesystem invariants.
  `taf-hub/version-order.py` adds five offline cases for mixed numeric versions,
  authoritative index.latest (including a nonmaximum latest), aliases without an
  index, invalid/missing retention targets, private/unknown/conflicting sources,
  failed upgrades, kind/scope isolation, and CLI/MCP dry-run agreement. Run this
  subset with `--filter taf-hub/version-order-`. These require freshly built
  binaries containing the shared comparator and maintenance fix.
  `taf-hub/diagnostics.py` includes fifteen offline cases for legacy manifests,
  safe batch continuation, aggregate preflight failures, protected pruning,
  malformed index/installation records, read permissions and symlinks,
  localized guidance, CLI exit codes and MCP read-only diagnostics. Run them
  with `--filter taf-hub/diagnostics-`. Each case has its own fixture namespace;
  missing old evidence is never regenerated by the tests' commands.
  These cases also cover mismatched metadata paths with unrelated-file sentinels,
  unsupported/missing install schemas, invalid apps-root types, separate alias
  warnings, and applied install/upgrade/prune JSON (including `--prune-old`).
  `summary-211`, `summary-300` and `summary-mixed` cover repeated/mixed issues,
  exact counts, at most three examples per issue/policy group, default summaries
  versus complete verbose/JSON evidence, English/Chinese guidance and unchanged
  filesystem state on blocking failures. Assertions target stable semantics and
  safe repair-preview/detailed-doctor entry points, not whole legacy sentences.
  `taf-hub/repair.py` is the offline explicit-repair subset
  (`--filter taf-hub/repair-`): option conflicts, verified skips, legacy/corrupt evidence,
  fixed commit/source conflicts, private/unknown/unsafe/custom-entry rejection,
  exact old identities, multiple targets, whole-batch no-write preflight,
  all-selection and unchanged MCP repair exposure. It uses temporary homes and
  local sources, not real installations. This coverage description is not an
  acceptance result or evidence for crash durability; transaction/recovery
  acceptance requires the matching final implementation and its own run logs.
- `taf-system/conformance.sh`: doctor policy and initialization checks plus
  read-only MCP environment behavior, a multi-request MCP stdio session,
  Unicode MCP compilation, stderr isolation, and cross-process history record
  identity/append safety.
  `taf-system/display.py` adds `display-layout` and `display-progress-streams`:
  conservative Unicode layout, long/complex field fallback, TTY in-place progress,
  redirected/closed stderr, `TERM=dumb`, and JSON/MCP progress isolation. Run with
  `--filter taf-system/display-` against freshly built temporary candidates.
  `taf-system/command-progress.py` checks early download status using a gated
  fake downloader, TTY/pipe/dumb/closed stderr, failures, sparse external locale
  fallback and MCP silence. Its real local Git fixtures cover install, upgrade,
  repair, prune and uninstall counts/stages plus previews and JSON isolation.
  Run with `--filter command-progress`. `taf-project/publish-stage-output`
  additionally checks stage notices against the existing fake remote, including
  dry-run and repeated publication without extra writes. These tests use no
  real network, container, app installation, or publication.
- `i18n/conformance.sh`: built-in/external locale selection, runtime output,
  fallback behavior, UTF-8 stdout/stderr pipes for all three delivered
  binaries, and language invariance of shell, JSON, and MCP protocols.
  The top-level help checks cover section order, terminal display width (including
  Chinese characters), concise line counts, contact links, unchanged version
  output, and the absence of contact footers from subcommand help.
- `installer/conformance.sh`: canonical-template drift, dry-run, official and
  custom verification policy, SHA256 and signed-manifest GPG checks, archive
  safety, complete home layout, SIF permissions, collision/lock handling, transactional rollback,
  receipt integrity, post-install warnings, and idempotent reinstall behavior.
  Real installed binaries also verify built-in English/Chinese help without
  external locale files, provider-independent `auto` selection, saved-language
  preservation on reinstall, and per-command environment overrides.
  `installer/fixture-tests.py` adds 13 offline unit checks for prerequisite
  detection and the harness's explicit skip/failure semantics.
- `cli-boundary/conformance.sh` and `cli-boundary/probe.py`: startup and compiler
  errors, unavailable output streams, SIGINT, and MCP request recovery, with
  controlling-terminal and timeout checks for accidental debugger entry.

The registered conformance scripts define the current delivered-binary case set;
use the selected run's report for totals rather than a fixed development count.
A case can contain multiple subprocess assertions; counts do not imply exhaustive coverage.
The `version-order-kind-tools` and `version-order-kind-flows` cases check that
excluded app kinds cannot block CLI/MCP plans with unrelated ordering errors,
while selected kinds still fail safely and planning does not change installed files.

### Hub Scale Tests

`taf-hub/performance.py` adds two offline cases with 300 and 1000 small installed
apps. Each has real launchers, frozen files and matching build-manifest hashes.
The cases time a no-op `install --all --yes`, a full `doctor hub --json` scan and
a targeted doctor scan. They check human progress, complete JSON plans/doctor
evidence and a 300-app MCP plan's stderr isolation, compare filesystem inventories, then corrupt a wrapper to verify
that the next invocation detects it and refuses writes. They never fetch images
or contact a repository. Temporary disk space is required for the fixtures.

```sh
TAFFISH_TEST_PERFORMANCE_MAX_SECONDS=5 ./test/run-tests.sh \
  --taf ./target/taf --taffish ./target/taffish \
  --taffish-mcp ./target/taffish-mcp --filter taf-hub/performance- --keep-tmp
```

The limit applies to the 300-app no-op command and full doctor scan and scales
proportionally for 1000 apps; targeted scan timing is reported separately.
The general suite defaults to 30 seconds to tolerate shared CI
hosts; use 5 for the focused local-disk performance acceptance check. Fixture
creation is not timed. Preserved per-case logs include `[perf]` measurements.
These limits are regression budgets, not promises for arbitrary snapshot sizes
or slow network filesystems. Internal tests additionally bound child-process
counts, check UTF-8/special paths, permissions, incomplete probe responses,
cache lifetime and delayed en/zh progress output.
Stage-specific internal tests additionally cover target filtering, alias grouping
across versions/canonical bin paths, localized enumeration/probe failures,
unknown-schema/unsafe-path refusal before deep traversal, summary counts and
whole-batch blocking before any writer. Display unit tests cover supported
Unicode widths and conservative fallback, not universal terminal/grapheme behavior.

### Installer Subset

To test the signed platform package, prepare its executables and run the installer subset:

```sh
scratch=$(mktemp -d)
bash test/ci-release-payloads.sh "$scratch/release"
./test/run-tests.sh --target-dir "$scratch/release/target" --filter installer/
```

The dedicated `installer/gpg-verification` case requires `gpg`, `gpgv`, the
three signed release materials in the selected `--target-dir` (default `target/`), and current-platform binaries
matching that manifest. It copies the **complete signed manifest unchanged**,
including other-platform entries; no private key or new signature is needed.
It tests strict `gpg` and automatic verification, checks the recorded `gpg`
verification level, and rejects altered signatures/manifests/binaries, an
untrusted public key, and missing signature/key materials in strict mode.
Rejection must leave both a fresh destination and an existing installation
unchanged. Automatic mode must not bypass present but invalid signatures.

Missing tools/materials or an explicitly selected unsigned local build produce
`[SKIP]` with a reason and a separate `SKIPPED` count, never a PASS. A mismatched
default release binary, duplicate manifest entry, or invalid signature fails.
A filtered run in which every case is skipped also fails. Require actual GPG
coverage before release, as CI does, with:

```sh
./test/run-tests.sh --target-dir "$scratch/release/target" --filter installer/gpg-verification
```

Also verify the final release materials independently as described in
[Release Verification](../install/README.md#release-verification).

For source checkouts, exercise the release packager and both providers without a network connection:

```sh
python3 -I test/package-release.py
python3 -I test/installer/platform-packages.py
```

The first test runs the [unified signing and packaging script](../target/make-sha-asc.sh) against temporary payloads and disposable GPG keys. It covers the default sign-then-package path, separate-stage retries, signature reuse, UTF-8 settings passed to GPG, input locking, existing-output protection, and signing or compression failure recovery. The generated archive signer is tested separately; no maintainer key is used. macOS transport-part tests cover ordered reassembly, size boundaries, existing-output protection and split-only operation without modifying the original archive. Linux archives remain unsplit.
The second test uses a temporary GPG key and two installer copies pinned to its fingerprint.
It covers Gitee/macOS part downloads and rejection of missing, damaged, reordered or mismatched parts before installation, both archive formats, a 0.11.0 to 0.12.0 upgrade, dry-run, local package selection
and renamed package verification. Failure at either verification layer must preserve an existing installation. The tests also check platform-specific notices, runtime text display before any program execution, explicit Linux acceptance, terminal refusal/EOF, recorded terms, and rollback of installed licenses with the binaries and receipt.

To run the full external suite on the files prepared above:

```sh
test/run-tests.sh --target-dir "$scratch/release/target"
```

For 0.12.0 and later, preparation reads `target/packages-<version>/`, verifies both archive digests
against the signed manifest and installs the native package using `--local --verify gpg --accept-runtime-license`. The external suite receives the installed
programs together with their original signed inner manifest. The 0.11.0 branch checks all six raw binaries.

A non-root run covers user installation and rejects unauthorized system
mutation. Exercise the administrator-only `0755` and sticky-`1777` branches
against the suite's temporary tree with:

```sh
sudo ./test/run-tests.sh \
  --target-dir "$scratch/release/target" \
  --filter installer/system-permissions
```

The installer subset has been exercised with the delivered macOS/arm64 and
Linux/amd64 binaries. It remains an offline test: no real installation paths,
remote repositories, or package indexes are modified.

The default suite does not pull images or run containers. Container tests
compile TAF and inspect generated shell contracts so they stay fast and
portable. Hub and publish tests use local fixtures and command shims; the suite
does not require network access, GitHub authentication, a real `gh` command, or
container engines, and it does not mutate real repositories. Environment
independence here means the suite isolates host state and declares its small
toolchain prerequisites; it does not reimplement the standard POSIX userland.

### All Installed Version Repair

`--filter taf-hub/repair-installed-` checks the `--all-installed --repair` path:
historical/latest selection, old-only installations without upgrades or dependency
installation, unreadable/unindexed/private/unknown records, type and scope filters,
English/Chinese summaries, unchanged default aliases, actual repair and idempotence.
All fixtures use isolated homes and local Git sources. The ordinary repair subset
also verifies that `--all --repair` still selects installed index.latest only.
