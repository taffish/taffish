# External conformance tests for real taf project workflows.
# This file is sourced by test/run-tests.sh.

_taf_project_artifact_fingerprint() {
  wrapper=$1
  snapshot=$2
  {
    printf 'wrapper '
    cksum "$wrapper"
    find "$snapshot" -type d -print | LC_ALL=C sort | sed 's/^/directory /'
    find "$snapshot" -type f -print | LC_ALL=C sort | while IFS= read -r file; do
      printf 'file '
      cksum "$file"
    done
  } | LC_ALL=C sort
}

_taf_project_mtime() {
  path=$1
  case "$(uname -s)" in
    Darwin) stat -f '%m' "$path" ;;
    Linux) stat -c '%Y' "$path" ;;
    *) return 1 ;;
  esac
}

_taf_project_case_new_check_compile_from_nested() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-nested
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new external-flow --flow >/dev/null || exit 1
    cd external-flow/src || exit 1
    "$TAF_BIN" check >/dev/null || exit 1
    shell=$("$TAF_BIN" compile) || exit 1
    output=$(printf '%s\n' "$shell" | sh) || exit 1
    assert_eq "<flow>[external-flow: 0.1.0] Hello, World!" "$output" \
      "taf compile from nested project" || exit 1
  )
}

_taf_project_case_smoke_placeholder_boundary() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-smoke-placeholder
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new autodock4 --tool --docker --no-actions >/dev/null || exit 1
    toml=autodock4/taffish.toml
    sed \
      -e 's/exist = \["TODO"\]/exist = ["autodock4"]/' \
      -e 's/test = \["TODO --help"\]/test = ["autodock4 --help"]/' \
      "$toml" > "$toml.tmp" || exit 1
    mv "$toml.tmp" "$toml" || exit 1

    cd autodock4 || exit 1
    capture_command env TAFFISH_LANGUAGE=en "$TAF_BIN" check
    assert_capture_success "smoke command containing TODO substring" || exit 1

    sed 's/exist = \["autodock4"\]/exist = ["TODO"]/' \
      taffish.toml > taffish.toml.tmp || exit 1
    mv taffish.toml.tmp taffish.toml || exit 1
    capture_command env TAFFISH_LANGUAGE=en "$TAF_BIN" check
    assert_capture_failure "exact smoke TODO placeholder" || exit 1
    output=$TAFFISH_CAPTURE_OUTPUT
    expected='contains TODO placeholder: "TODO".
  Replace default smoke checks'
    assert_contains "$output" "$expected" \
      "smoke placeholder diagnostic preserves line break" || exit 1
    assert_not_contains "$output" '.n  Replace default smoke checks' \
      "smoke placeholder diagnostic has no literal n escape" || exit 1
  )
}

_taf_project_case_build_wrapper_run_compile_help() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-build-wrapper
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new wrapper-flow --flow >/dev/null || exit 1
    cd wrapper-flow || exit 1
    cat > docs/help.md <<'HELP'
# wrapper-flow help

This help text is frozen into the built wrapper.
HELP
    "$TAF_BIN" build >/dev/null || exit 1
    wrapper=target/taf-wrapper-flow-v0.1.0-r1
    assert_executable "$wrapper" || exit 1

    help_output=$("$wrapper" --help) || exit 1
    assert_contains "$help_output" "wrapper-flow help" "built wrapper help" || exit 1

    compile_output=$("$wrapper" --compile) || exit 1
    assert_contains "$compile_output" "<flow>[wrapper-flow: 0.1.0] Hello, World!" \
      "built wrapper compile" || exit 1

    run_output=$("$wrapper") || exit 1
    assert_eq "<flow>[wrapper-flow: 0.1.0] Hello, World!" "$run_output" \
      "built wrapper run" || exit 1
  )
}

_taf_project_case_build_uses_frozen_snapshot() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-frozen
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new frozen-flow --flow >/dev/null || exit 1
    cd frozen-flow || exit 1
    "$TAF_BIN" build >/dev/null || exit 1
    wrapper=target/taf-frozen-flow-v0.1.0-r1
    assert_executable "$wrapper" || exit 1

    cat > src/main.taf <<'TAF'
<taffish>
echo 'LIVE SOURCE CHANGED'
TAF

    run_output=$("$wrapper") || exit 1
    assert_eq "<flow>[frozen-flow: 0.1.0] Hello, World!" "$run_output" \
      "built wrapper uses frozen snapshot" || exit 1

    live_shell=$("$TAF_BIN" compile) || exit 1
    assert_contains "$live_shell" "LIVE SOURCE CHANGED" "live project compile sees changed source" || exit 1
  )
}

_taf_project_case_wrapper_pipeline_concurrency() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-wrapper-pipeline
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new pipe-tool --tool >/dev/null || exit 1
    cd pipe-tool || exit 1
    cat > src/main.taf <<'TAF'
<taf-app:shell>
::*ARGV*::
TAF
    "$TAF_BIN" build >/dev/null || exit 1
    wrapper=$PWD/target/taf-pipe-tool-v0.1.0-r1
    assert_executable "$wrapper" || exit 1

    pids=
    for worker in 1 2 3 4 5 6
    do
      (
        TAF_HISTORY_MODE=off "$wrapper" echo "pipeline-$worker" |
          TAF_HISTORY_MODE=off "$wrapper" cat
      ) >"$dir/pipeline-$worker.log" 2>&1 &
      pids="$pids $!"
    done

    failed=0
    worker=1
    for pid in $pids
    do
      if ! wait "$pid"; then
        failed=1
      fi
      expected="pipeline-$worker"
      actual=$(cat "$dir/pipeline-$worker.log")
      if [ "$actual" != "$expected" ]; then
        printf 'wrapper pipeline %s expected %s, got:\n%s\n' \
          "$worker" "$expected" "$actual" >&2
        failed=1
      fi
      worker=$((worker + 1))
    done
    [ "$failed" -eq 0 ] || exit 1
  )
}

_taf_project_case_wrapper_history_concurrency() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-wrapper-history
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    TAF_HISTORY_MODE=off "$TAF_BIN" new history-tool --tool >/dev/null || exit 1
    cd history-tool || exit 1
    cat > src/main.taf <<'TAF'
<taf-app:shell>
::*ARGV*::
TAF
    TAF_HISTORY_MODE=off "$TAF_BIN" build >/dev/null || exit 1
    wrapper=$PWD/target/taf-history-tool-v0.1.0-r1
    history_file=$dir/history.jsonl
    assert_executable "$wrapper" || exit 1

    pids=
    for worker in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 \
                  17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32
    do
      (
        TAF_HISTORY_MODE=sync TAF_HISTORY_FILE="$history_file" \
          "$wrapper" printf 'worker-%s\n' "$worker"
      ) >"$dir/history-worker-$worker.log" 2>&1 &
      pids="$pids $!"
    done

    failed=0
    for pid in $pids
    do
      wait "$pid" || failed=1
    done
    [ "$failed" -eq 0 ] || harness_fail "one or more history workers failed"

    python3 - "$history_file" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    lines = [line.rstrip("\n") for line in handle if line.strip()]

assert len(lines) == 32, (len(lines), lines)
records = [json.loads(line) for line in lines]
assert all(record.get("event") == "exec" for record in records), records
assert all(record.get("history_backend") == "shell-wrapper" for record in records), records
ids = [record.get("id") for record in records]
assert all(ids), ids
assert len(set(ids)) == len(ids), ids
PY
  )
}

_taf_project_case_unicode_build_and_history() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-unicode/项目目录
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    env LC_ALL="$TAFFISH_TEST_UTF8_LOCALE" LANG="$TAFFISH_TEST_UTF8_LOCALE" \
      TAF_HISTORY_MODE=off "$TAF_BIN" new unicode-flow --flow >/dev/null || exit 1
    cd unicode-flow || exit 1
    mkdir -p src/数据 docs/说明
    printf '%s\n' '冻结的数据文件' > src/数据/输入.txt
    printf '%s\n' '构建说明' > docs/说明/构建.md
    cat > src/main.taf <<'TAF'
<taffish>
printf '%s\n' '你好，构建'
TAF

    build_output=$(env LC_ALL="$TAFFISH_TEST_UTF8_LOCALE" \
      LANG="$TAFFISH_TEST_UTF8_LOCALE" TAF_HISTORY_MODE=sync \
      "$TAF_BIN" build) || exit 1
    assert_contains "$build_output" "built command" "Unicode project build" || exit 1

    wrapper=target/taf-unicode-flow-v0.1.0-r1
    snapshot=target/.taf-unicode-flow-v0.1.0-r1
    assert_executable "$wrapper" || exit 1
    [ -f "$snapshot/src/数据/输入.txt" ] || \
      harness_fail "Unicode source file was not frozen"
    [ -f "$snapshot/docs/说明/构建.md" ] || \
      harness_fail "Unicode docs file was not frozen"

    output=$(env LC_ALL="$TAFFISH_TEST_UTF8_LOCALE" \
      LANG="$TAFFISH_TEST_UTF8_LOCALE" TAF_HISTORY_MODE=off "$wrapper") || exit 1
    assert_eq "你好，构建" "$output" "Unicode built wrapper output" || exit 1

    history_file=$TAFFISH_USER_HOME/logs/history.jsonl
    [ -f "$history_file" ] || harness_fail "Unicode build history is missing"
    python3 - "$history_file" "$PWD" <<'PY'
import json
import os
import sys

path, project_root = sys.argv[1:]
with open(path, "r", encoding="utf-8") as handle:
    records = [json.loads(line) for line in handle if line.strip()]
matches = [record for record in records if record.get("event") == "build"]
assert matches, records
expected_root = os.path.realpath(project_root)
assert any(
    os.path.realpath(record.get("project_root", "")) == expected_root
    for record in matches
), matches
PY
  )
}

_taf_project_case_run_stdin_process_boundary() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-run-stdin
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new stdin-flow --flow >/dev/null || exit 1
    cd stdin-flow || exit 1
    cat > src/main.taf <<'TAF'
RUN
<shell>
cat
TAF

    TAF_BIN="$TAF_BIN" PROJECT_DIR="$PWD" python3 - <<'PY'
import os
import pty
import subprocess
import tempfile

taf = os.environ["TAF_BIN"]
project = os.environ["PROJECT_DIR"]
env = os.environ.copy()

without_input = subprocess.run(
    [taf, "run"],
    cwd=project,
    env=env,
    stdin=subprocess.DEVNULL,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    timeout=10,
    check=False,
)
assert without_input.returncode == 0, without_input.stderr.decode(errors="replace")
assert without_input.stdout == b"", (
    f"taf run with /dev/null produced {without_input.stdout!r}; "
    f"stderr={without_input.stderr!r}"
)

terminal_master, terminal_slave = pty.openpty()
try:
    terminal_input = subprocess.run(
        [taf, "run"],
        cwd=project,
        env=env,
        stdin=terminal_slave,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=10,
        check=False,
    )
finally:
    os.close(terminal_slave)
    os.close(terminal_master)
assert terminal_input.returncode == 0, terminal_input.stderr.decode(errors="replace")
assert terminal_input.stdout == b"", (
    f"taf run inherited terminal stdin unexpectedly: "
    f"stdout={terminal_input.stdout!r}; stderr={terminal_input.stderr!r}"
)

with tempfile.TemporaryFile() as redirected_input:
    redirected_input.write(b"file-data\nsecond-file-line\n")
    redirected_input.seek(0)
    with_file = subprocess.run(
        [taf, "run"],
        cwd=project,
        env=env,
        stdin=redirected_input,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=10,
        check=False,
    )
assert with_file.returncode == 0, with_file.stderr.decode(errors="replace")
assert with_file.stdout == b"file-data\nsecond-file-line\n", (
    f"taf run did not forward file stdin: stdout={with_file.stdout!r}; "
    f"stderr={with_file.stderr!r}"
)

with_input = subprocess.run(
    [taf, "run"],
    cwd=project,
    env=env,
    input=b"pipe-data\nsecond-line\n",
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    timeout=10,
    check=False,
)
assert with_input.returncode == 0, with_input.stderr.decode(errors="replace")
assert with_input.stdout == b"pipe-data\nsecond-line\n", (
    f"taf run did not forward piped stdin: stdout={with_input.stdout!r}; "
    f"stderr={with_input.stderr!r}"
)
PY
  )
}

_taf_project_case_build_is_idempotent_and_exact() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-build-idempotent
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new idempotent-flow --flow >/dev/null || exit 1
    cd idempotent-flow || exit 1

    sed 's/version = "0.1.0"/version = "492"/' \
      taffish.toml > taffish.toml.tmp || exit 1
    mv taffish.toml.tmp taffish.toml || exit 1

    first_output=$(TAFFISH_LANGUAGE=en "$TAF_BIN" build) || exit 1
    wrapper=target/taf-idempotent-flow-v492-r1
    snapshot=target/.taf-idempotent-flow-v492-r1
    manifest=$snapshot/.taf-build.json
    assert_contains "$first_output" "built command" "first build status" || exit 1
    assert_executable "$wrapper" || exit 1
    [ -f "$manifest" ] || {
      printf 'build manifest is missing: %s\n' "$manifest" >&2
      exit 1
    }
    build_residue=$(find target \( -name '*wrapper-tmp-*' \
      -o -name '*wrapper-backup-*' -o -name '*build-tmp-*' \
      -o -name '*build-backup-*' \) -print)
    [ -z "$build_residue" ] || {
      printf 'first dotless-version build left transaction residue:\n%s\n' \
        "$build_residue" >&2
      exit 1
    }

    fingerprint_before=$(_taf_project_artifact_fingerprint "$wrapper" "$snapshot") || exit 1
    wrapper_mtime_before=$(_taf_project_mtime "$wrapper") || exit 1
    manifest_mtime_before=$(_taf_project_mtime "$manifest") || exit 1
    printf 'legacy residue\n' > target/taf-idempotent-flow-v492-r1.wrapper-tmp-legacy
    sleep 1
    second_output=$(TAFFISH_LANGUAGE=en "$TAF_BIN" build) || exit 1
    fingerprint_after=$(_taf_project_artifact_fingerprint "$wrapper" "$snapshot") || exit 1
    assert_contains "$second_output" "command is up to date" \
      "second build status" || exit 1
    assert_eq "$fingerprint_before" "$fingerprint_after" \
      "second build preserves artifact content" || exit 1
    assert_eq "$wrapper_mtime_before" "$(_taf_project_mtime "$wrapper")" \
      "second build preserves wrapper mtime" || exit 1
    assert_eq "$manifest_mtime_before" "$(_taf_project_mtime "$manifest")" \
      "second build preserves manifest mtime" || exit 1
    [ ! -e target/taf-idempotent-flow-v492-r1.wrapper-tmp-legacy ] || {
      printf 'build did not remove legacy non-hidden wrapper residue\n' >&2
      exit 1
    }

    printf 'unexpected residue\n' > "$snapshot/help2.md"
    mkdir -p "$snapshot/docs2/nested" "$snapshot/src2"
    cleanup_output=$(TAFFISH_LANGUAGE=en "$TAF_BIN" build) || exit 1
    assert_contains "$cleanup_output" "built command" \
      "abnormal snapshot is rebuilt" || exit 1
    [ ! -e "$snapshot/help2.md" ] || {
      printf 'build preserved unexpected help2.md\n' >&2
      exit 1
    }
    [ ! -e "$snapshot/docs2" ] || {
      printf 'build preserved unexpected docs2 directory\n' >&2
      exit 1
    }
    [ ! -e "$snapshot/src2" ] || {
      printf 'build preserved unexpected src2 directory\n' >&2
      exit 1
    }

    cat > src/main.taf <<'TAF'
<taffish>
echo 'REBUILT SOURCE'
TAF
    cat > docs/help.md <<'HELP'
# idempotent-flow rebuilt help
HELP
    changed_output=$(TAFFISH_LANGUAGE=en "$TAF_BIN" build) || exit 1
    assert_contains "$changed_output" "built command" "changed source rebuild" || exit 1
    compile_output=$(TAF_HISTORY_MODE=off "$wrapper" --compile) || exit 1
    help_output=$("$wrapper" --help) || exit 1
    run_output=$(TAF_HISTORY_MODE=off "$wrapper") || exit 1
    assert_contains "$compile_output" "REBUILT SOURCE" \
      "rebuilt wrapper compile" || exit 1
    assert_contains "$help_output" "idempotent-flow rebuilt help" \
      "rebuilt wrapper help" || exit 1
    assert_eq "REBUILT SOURCE" "$run_output" "rebuilt wrapper run" || exit 1
    build_residue=$(find target \( -name '*wrapper-tmp-*' \
      -o -name '*wrapper-backup-*' -o -name '*build-tmp-*' \
      -o -name '*build-backup-*' \) -print)
    [ -z "$build_residue" ] || {
      printf 'rebuilt dotless-version project left transaction residue:\n%s\n' \
        "$build_residue" >&2
      exit 1
    }
  )
}

_taf_project_case_new_docker_workflow_contract() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-native-actions
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new native-actions --tool --docker >/dev/null || exit 1
    workflow=native-actions/.github/workflows/build-image.yml
    if [ ! -f "$workflow" ]; then
      printf 'taf new did not generate workflow: %s\n' "$workflow" >&2
      exit 1
    fi

    for required in \
      "actions/checkout@v6" \
      "docker/setup-buildx-action@v4" \
      "docker/login-action@v4" \
      "docker/build-push-action@v7" \
      "ubuntu-24.04-arm" \
      "source_ref:" \
      "platforms:" \
      'ref: ${{ env.SOURCE_REF }}' \
      "fromJSON(needs.prepare.outputs.matrix)" \
      "source_commit=" \
      'ref: ${{ needs.prepare.outputs.source_commit }}' \
      "docker buildx imagetools inspect" \
      "final manifest is missing declared platforms"
    do
      assert_contains "$(cat "$workflow")" "$required" \
        "generated native Actions workflow: $required" || exit 1
    done

    for forbidden in \
      "docker/setup-qemu-action" \
      "continue-on-error: true" \
      "publishing amd64-only manifest" \
      "signac"
    do
      if grep -F "$forbidden" "$workflow" >/dev/null 2>&1; then
        printf 'generated workflow contains forbidden legacy behavior: %s\n' "$forbidden" >&2
        exit 1
      fi
    done

    "$TAF_BIN" new native-no-actions --tool --docker --no-actions >/dev/null || exit 1
    if [ -e native-no-actions/.github/workflows/build-image.yml ]; then
      printf 'taf new --no-actions unexpectedly generated build-image.yml\n' >&2
      exit 1
    fi

    command -v python3 >/dev/null 2>&1 || {
      printf 'python3 is required to validate generated workflow scripts\n' >&2
      exit 1
    }

    extract_python_block() {
      wanted=$1
      output_file=$2
      awk -v wanted="$wanted" '
        /^          import json$/ { seen += 1 }
        seen == wanted && !capture { capture = 1 }
        capture && /^          PY$/ { exit }
        capture { sub(/^          /, ""); print }
      ' "$workflow" > "$output_file"
    }

    extract_python_block 1 native-actions/.workflow-prepare.py
    extract_python_block 3 native-actions/.workflow-verify-manifest.py
    python3 -m py_compile native-actions/.workflow-prepare.py || exit 1
    python3 -m py_compile native-actions/.workflow-verify-manifest.py || exit 1

    cd native-actions || exit 1
    cp taffish.toml .workflow-taffish.toml.original || exit 1
    source_commit=0123456789abcdef0123456789abcdef01234567

    set_build_platforms() {
      value=$1
      awk -v value="$value" '
        /^build_platforms = / {
          print "build_platforms = \"" value "\""
          found = 1
          next
        }
        { print }
        END { if (!found) exit 2 }
      ' taffish.toml > .workflow-taffish.toml.next || return 1
      mv .workflow-taffish.toml.next taffish.toml
    }

    restore_toml() {
      cp .workflow-taffish.toml.original taffish.toml
    }

    run_prepare() {
      source_ref=$1
      requested_platforms=$2
      env SOURCE_REF="$source_ref" \
          SOURCE_COMMIT="$source_commit" \
          REQUESTED_PLATFORMS="$requested_platforms" \
          python3 .workflow-prepare.py
    }

    expect_prepare_failure() {
      expected_message=$1
      source_ref=$2
      requested_platforms=$3
      set +e
      failure_output=$(run_prepare "$source_ref" "$requested_platforms" 2>&1)
      failure_status=$?
      set -e
      if [ "$failure_status" -eq 0 ]; then
        printf 'workflow prepare unexpectedly succeeded: %s\n' "$expected_message" >&2
        return 1
      fi
      assert_contains "$failure_output" "$expected_message" \
        "workflow prepare failure" || return 1
    }

    prepare_output=$(run_prepare refs/tags/v0.1.0-r1 "") || exit 1
    assert_contains "$prepare_output" '"runner":"ubuntu-24.04"' \
      "default amd64 native runner" || exit 1
    assert_contains "$prepare_output" '"runner":"ubuntu-24.04-arm"' \
      "default arm64 native runner" || exit 1
    assert_contains "$prepare_output" "taffish-amd64-$source_commit" \
      "default amd64 commit image" || exit 1
    assert_contains "$prepare_output" "taffish-arm64-$source_commit" \
      "default arm64 commit image" || exit 1

    set_build_platforms linux/amd64 || exit 1
    prepare_output=$(run_prepare refs/tags/v0.1.0-r1 "") || exit 1
    assert_contains "$prepare_output" '"runner":"ubuntu-24.04"' \
      "amd64-only native runner" || exit 1
    assert_not_contains "$prepare_output" 'ubuntu-24.04-arm' \
      "amd64-only excludes arm64 runner" || exit 1
    assert_not_contains "$prepare_output" 'taffish-arm64-' \
      "amd64-only excludes arm64 image" || exit 1

    restore_toml || exit 1
    prepare_output=$(run_prepare refs/tags/v0.1.0-r1 linux/arm64) || exit 1
    prepare_matrix=$(printf '%s\n' "$prepare_output" | sed -n 's/^matrix=//p')
    platform_images=$(printf '%s\n' "$prepare_output" | sed -n 's/^platform_images=//p')
    assert_contains "$prepare_matrix" '"runner":"ubuntu-24.04-arm"' \
      "arm64 recovery matrix" || exit 1
    assert_not_contains "$prepare_matrix" '"runner":"ubuntu-24.04"' \
      "arm64 recovery skips amd64 build" || exit 1
    assert_contains "$platform_images" "taffish-amd64-$source_commit" \
      "arm64 recovery keeps amd64 manifest prerequisite" || exit 1
    assert_contains "$platform_images" "taffish-arm64-$source_commit" \
      "arm64 recovery keeps arm64 manifest prerequisite" || exit 1

    run_prepare main "" >/dev/null || {
      printf 'manual branch source_ref was incorrectly treated as a release tag\n' >&2
      exit 1
    }

    set_build_platforms linux/amd64,linux/amd64 || exit 1
    expect_prepare_failure "build platforms must be non-empty and unique" \
      refs/tags/v0.1.0-r1 "" || exit 1
    set_build_platforms "" || exit 1
    expect_prepare_failure "build platforms must be non-empty and unique" \
      refs/tags/v0.1.0-r1 "" || exit 1
    set_build_platforms linux/s390x || exit 1
    expect_prepare_failure "unsupported native build platforms: linux/s390x" \
      refs/tags/v0.1.0-r1 "" || exit 1

    restore_toml || exit 1
    expect_prepare_failure "requested platforms are not declared: linux/s390x" \
      refs/tags/v0.1.0-r1 linux/s390x || exit 1
    expect_prepare_failure "source tag v0.2.0-r1 does not match v0.1.0-r1" \
      refs/tags/v0.2.0-r1 "" || exit 1

    awk '
      /^image = / {
        print "image = \"ghcr.io/taffish/native-actions:0.1.0-r2\""
        next
      }
      { print }
    ' taffish.toml > .workflow-taffish.toml.next || exit 1
    mv .workflow-taffish.toml.next taffish.toml || exit 1
    expect_prepare_failure "container image tag must be 0.1.0-r1" \
      refs/tags/v0.1.0-r1 "" || exit 1
    restore_toml || exit 1

    manifest_dir=$PWD/.workflow-manifest
    mkdir -p "$manifest_dir"
    cat > "$manifest_dir/taffish-final-manifest.json" <<'JSON'
{"schemaVersion":2,"manifests":[{"platform":{"os":"linux","architecture":"amd64"}},{"platform":{"os":"linux","architecture":"arm64"}},{"platform":{"os":"unknown","architecture":"unknown"}}]}
JSON
    RUNNER_TEMP="$manifest_dir" \
      DECLARED_PLATFORMS='["linux/amd64","linux/arm64"]' \
      python3 .workflow-verify-manifest.py >/dev/null || exit 1

    cat > "$manifest_dir/taffish-final-manifest.json" <<'JSON'
{"schemaVersion":2,"manifests":[{"platform":{"os":"linux","architecture":"amd64"}}]}
JSON
    set +e
    manifest_output=$(RUNNER_TEMP="$manifest_dir" \
      DECLARED_PLATFORMS='["linux/amd64","linux/arm64"]' \
      python3 .workflow-verify-manifest.py 2>&1)
    manifest_status=$?
    set -e
    [ "$manifest_status" -ne 0 ] || {
      printf 'manifest verification accepted a missing declared platform\n' >&2
      exit 1
    }
    assert_contains "$manifest_output" \
      "final manifest is missing declared platforms: linux/arm64" \
      "missing manifest platform" || exit 1

    cat > "$manifest_dir/taffish-final-manifest.json" <<'JSON'
{"schemaVersion":2,"manifests":[{"platform":{"os":"linux","architecture":"amd64"}},{"platform":{"os":"linux","architecture":"arm64"}},{"platform":{"os":"linux","architecture":"s390x"}}]}
JSON
    set +e
    manifest_output=$(RUNNER_TEMP="$manifest_dir" \
      DECLARED_PLATFORMS='["linux/amd64","linux/arm64"]' \
      python3 .workflow-verify-manifest.py 2>&1)
    manifest_status=$?
    set -e
    [ "$manifest_status" -ne 0 ] || {
      printf 'manifest verification accepted an unexpected platform\n' >&2
      exit 1
    }
    assert_contains "$manifest_output" \
      "final manifest has unexpected platforms: linux/s390x" \
      "unexpected manifest platform" || exit 1
  )
}

_taf_project_setup_fake_publish_commands() {
  fake_root=$1
  fake_bin=$fake_root/bin
  fake_state=$fake_root/state
  mkdir -p "$fake_bin" "$fake_state"
  : > "$fake_state/commands.log"
  : > "$fake_state/mutations.log"
  : > "$fake_state/local-git-results.log"
  : > "$fake_state/git-results.log"
  : > "$fake_state/gh-results.log"

  REAL_GIT=$(command -v git) || return 1
  export REAL_GIT
  export FAKE_PUBLISH_STATE=$fake_state
  export FAKE_PUBLISH_BIN=$fake_bin

  cat > "$fake_bin/git-impl" <<'SH'
#!/bin/sh
set -eu

state=$FAKE_PUBLISH_STATE
root=$PWD
if [ "${1:-}" = "-C" ]; then
  root=$2
  shift 2
fi
command=${1:-}
printf 'git %s\n' "$*" >> "$state/commands.log"

require_noninteractive() {
  [ "${GIT_TERMINAL_PROMPT:-}" = 0 ] || {
    printf 'fake git expected GIT_TERMINAL_PROMPT=0\n' >&2
    exit 90
  }
}

case "$command" in
  ls-remote)
    require_noninteractive
    if [ -f "$state/outage-git" ]; then
      printf 'fatal: connection reset by peer\n' >&2
      exit 128
    fi
    if [ ! -f "$state/repository" ]; then
      printf 'remote: Repository not found.\n' >&2
      exit 128
    fi
    mode=${2:-}
    if [ "$mode" = "--heads" ]; then
      if [ -f "$state/remote-branch" ]; then
        commit=$(cat "$state/remote-branch")
        ref=${4:-refs/heads/main}
        printf '%s\t%s\n' "$commit" "$ref"
      fi
    elif [ "$mode" = "--tags" ]; then
      if [ -f "$state/other-tags" ]; then
        cat "$state/other-tags"
      fi
      if [ -f "$state/remote-tag" ]; then
        commit=$(cat "$state/remote-tag")
        tag=$(cat "$state/remote-tag-name")
        printf '%s\trefs/tags/%s\n' "$commit" "$tag"
      fi
    fi
    ;;
  push)
    require_noninteractive
    commit=$($REAL_GIT -C "$root" rev-parse HEAD)
    if [ "${2:-}" = "-u" ]; then
      printf '%s' "$commit" > "$state/remote-branch"
      printf 'branch-push\n' >> "$state/mutations.log"
      if [ -f "$state/fail-after-branch" ]; then
        rm -f "$state/fail-after-branch"
        : > "$state/outage-git"
        printf 'fatal: connection reset by peer\n' >&2
        exit 128
      fi
    else
      tag=${3:-}
      printf '%s' "$commit" > "$state/remote-tag"
      printf '%s' "$tag" > "$state/remote-tag-name"
      printf 'remote-tag-push\n' >> "$state/mutations.log"
      if [ -f "$state/fail-after-remote-tag" ]; then
        rm -f "$state/fail-after-remote-tag"
        : > "$state/outage-git"
        printf 'fatal: connection reset by peer\n' >&2
        exit 128
      fi
    fi
    ;;
  *)
    stdout_file=$state/local-git-$$.stdout
    stderr_file=$state/local-git-$$.stderr
    set +e
    "$REAL_GIT" -C "$root" "$@" >"$stdout_file" 2>"$stderr_file"
    status=$?
    set -e
    if [ "$command" = show-ref ] && [ "$status" -eq 1 ] && \
       [ -f "$state/localized-missing-tag" ]; then
      printf 'fatal: se necesita una sola revision\n' > "$stderr_file"
    fi
    printf 'status=%s git -C %s %s\n' "$status" "$root" "$*" \
      >> "$state/local-git-results.log"
    cat "$stdout_file"
    cat "$stderr_file" >&2
    rm -f "$stdout_file" "$stderr_file"
    exit "$status"
    ;;
esac
SH

  cat > "$fake_bin/git" <<'SH'
#!/bin/sh
set -u

state=$FAKE_PUBLISH_STATE
stdout_file=$state/fake-git-$$.stdout
stderr_file=$state/fake-git-$$.stderr

fake_state_snapshot() {
  separator=
  for marker in \
    repository immutable-releases ruleset remote-branch remote-tag \
    release-tag outage-git outage-gh fail-after-repository \
    fail-after-immutable fail-after-ruleset fail-after-branch \
    fail-after-remote-tag fail-after-release localized-missing-tag
  do
    if [ -e "$state/$marker" ]; then
      printf '%s%s' "$separator" "$marker"
      separator=,
    fi
  done
  [ -n "$separator" ] || printf '(none)'
}

before_state=$(fake_state_snapshot)
"$FAKE_PUBLISH_BIN/git-impl" "$@" >"$stdout_file" 2>"$stderr_file"
status=$?
after_state=$(fake_state_snapshot)

{
  printf 'status=%s command=git' "$status"
  for arg in "$@"; do
    printf ' <%s>' "$arg"
  done
  printf '\n'
  printf 'before-state=%s\n' "$before_state"
  printf 'after-state=%s\n' "$after_state"
  for value_file in visibility remote-branch remote-tag remote-tag-name release-tag; do
    if [ -f "$state/$value_file" ]; then
      printf 'state-value[%s]=' "$value_file"
      cat "$state/$value_file"
      printf '\n'
    fi
  done
  printf 'stdout:\n'
  if [ -s "$stdout_file" ]; then
    sed 's/^/  /' "$stdout_file"
  else
    printf '  (empty)\n'
  fi
  printf 'stderr:\n'
  if [ -s "$stderr_file" ]; then
    sed 's/^/  /' "$stderr_file"
  else
    printf '  (empty)\n'
  fi
  printf '%s\n' '---'
} >> "$state/git-results.log"

cat "$stdout_file"
cat "$stderr_file" >&2
rm -f "$stdout_file" "$stderr_file"
exit "$status"
SH

  cat > "$fake_bin/gh-impl" <<'SH'
#!/bin/sh
set -eu

state=$FAKE_PUBLISH_STATE
printf 'gh %s\n' "$*" >> "$state/commands.log"
[ "${GH_PROMPT_DISABLED:-}" = 1 ] || {
  printf 'fake gh expected GH_PROMPT_DISABLED=1\n' >&2
  exit 90
}

if [ -f "$state/outage-gh" ]; then
  printf 'connection reset by peer\n' >&2
  exit 1
fi

case "${1:-} ${2:-}" in
  "repo view")
    if [ ! -f "$state/repository" ]; then
      printf 'Could not resolve to a Repository\n' >&2
      exit 1
    fi
    slug=$3
    visibility=$(cat "$state/visibility")
    printf '{"nameWithOwner":"%s","visibility":"%s","url":"https://github.com/%s"}\n' \
      "$slug" "$visibility" "$slug"
    ;;
  "repo create")
    slug=$3
    visibility=PUBLIC
    for arg in "$@"; do
      [ "$arg" != "--private" ] || visibility=PRIVATE
    done
    : > "$state/repository"
    printf '%s' "$visibility" > "$state/visibility"
    printf 'repository-create\n' >> "$state/mutations.log"
    printf 'https://github.com/%s\n' "$slug"
    if [ -f "$state/fail-after-repository" ]; then
      rm -f "$state/fail-after-repository"
      : > "$state/outage-gh"
      printf 'connection reset by peer\n' >&2
      exit 1
    fi
    ;;
  "release view")
    if [ ! -f "$state/release-tag" ]; then
      printf 'release not found\n' >&2
      exit 1
    fi
    tag=$(cat "$state/release-tag")
    title=$(cat "$state/release-title")
    body=$(cat "$state/release-notes")
    prerelease=$(cat "$state/release-prerelease")
    draft=false
    [ ! -f "$state/release-draft" ] || draft=true
    # GitHub's release API can return a final LF even when the local reader
    # supplied the same notes without one.
    printf '{"tagName":"%s","name":"%s","body":"%s\\n","isDraft":%s,"isPrerelease":%s,"targetCommitish":"main"}\n' \
      "$tag" "$title" "$body" "$draft" "$prerelease"
    ;;
  "release create")
    tag=$3
    shift 3
    title=
    notes_file=
    prerelease=false
    latest=
    verify_tag=false
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --repo) shift ;;
        --title) shift; title=$1 ;;
        --notes-file) shift; notes_file=$1 ;;
        --prerelease) prerelease=true ;;
        --latest) latest=true ;;
        --latest=false) latest=false ;;
        --verify-tag) verify_tag=true ;;
        *) printf 'unsupported fake release option: %s\n' "$1" >&2; exit 2 ;;
      esac
      shift
    done
    [ "$verify_tag" = true ] && [ -n "$latest" ] || {
      printf 'release requires verify-tag and explicit latest policy\n' >&2
      exit 2
    }
    [ -f "$state/remote-tag-name" ] && \
      [ "$(cat "$state/remote-tag-name")" = "$tag" ] || {
      printf 'remote tag missing; fake gh will not synthesize a tag\n' >&2
      exit 1
    }
    [ ! -f "$state/release-tag" ] || {
      printf 'release already exists; refusing duplicate create\n' >&2
      exit 1
    }
    [ "$prerelease:$latest" != true:true ] || exit 2
    printf '%s' "$tag" > "$state/release-tag"
    printf '%s' "$title" > "$state/release-title"
    cat "$notes_file" > "$state/release-notes"
    printf '%s' "$prerelease" > "$state/release-prerelease"
    printf '%s' "$latest" > "$state/release-latest-policy"
    [ "$latest" != true ] || printf '%s' "$tag" > "$state/latest-tag"
    printf 'release-create\n' >> "$state/mutations.log"
    if [ -f "$state/fail-after-release" ]; then
      rm -f "$state/fail-after-release"
      : > "$state/outage-gh"
      printf 'connection reset by peer\n' >&2
      exit 1
    fi
    ;;
  "api -X")
    method=$3
    endpoint=$4
    case "$method:$endpoint" in
      PUT:*immutable-releases)
        : > "$state/immutable-releases"
        printf 'immutable-put\n' >> "$state/mutations.log"
        printf '{"enabled":true}\n'
        if [ -f "$state/fail-after-immutable" ]; then
          rm -f "$state/fail-after-immutable"
          : > "$state/outage-gh"
          printf 'connection reset by peer\n' >&2
          exit 1
        fi
        ;;
      POST:*rulesets)
        : > "$state/ruleset"
        printf 'ruleset-post\n' >> "$state/mutations.log"
        printf '{"id":1}\n'
        if [ -f "$state/fail-after-ruleset" ]; then
          rm -f "$state/fail-after-ruleset"
          : > "$state/outage-gh"
          printf 'connection reset by peer\n' >&2
          exit 1
        fi
        ;;
      *)
        printf 'unsupported fake gh mutation: %s %s\n' "$method" "$endpoint" >&2
        exit 2
        ;;
    esac
    ;;
  api*)
    endpoint=$2
    case "$endpoint" in
      */immutable-releases)
        if [ -f "$state/immutable-releases" ]; then
          printf '{"enabled":true}\n'
        else
          printf '{"enabled":false}\n'
        fi
        ;;
      */rulesets/1)
        printf '{"id":1,"name":"TAFFISH release tag lock","target":"tag","enforcement":"active","conditions":{"ref_name":{"include":["refs/tags/v*"],"exclude":[]}},"rules":[{"type":"update"},{"type":"deletion"}]}\n'
        ;;
      */rulesets)
        if [ -f "$state/ruleset" ]; then
          printf '[{"id":1,"name":"TAFFISH release tag lock"}]\n'
        else
          printf '[]\n'
        fi
        ;;
      *)
        printf 'unsupported fake gh query: %s\n' "$endpoint" >&2
        exit 2
        ;;
    esac
    ;;
  *)
    printf 'unsupported fake gh command: %s\n' "$*" >&2
    exit 2
    ;;
esac
SH

  cat > "$fake_bin/gh" <<'SH'
#!/bin/sh
set -u

state=$FAKE_PUBLISH_STATE
stdout_file=$state/fake-gh-$$.stdout
stderr_file=$state/fake-gh-$$.stderr

fake_state_snapshot() {
  separator=
  for marker in \
    repository immutable-releases ruleset remote-branch remote-tag \
    release-tag outage-git outage-gh fail-after-repository \
    fail-after-immutable fail-after-ruleset fail-after-branch \
    fail-after-remote-tag fail-after-release
  do
    if [ -e "$state/$marker" ]; then
      printf '%s%s' "$separator" "$marker"
      separator=,
    fi
  done
  [ -n "$separator" ] || printf '(none)'
}

before_state=$(fake_state_snapshot)
"$FAKE_PUBLISH_BIN/gh-impl" "$@" >"$stdout_file" 2>"$stderr_file"
status=$?
after_state=$(fake_state_snapshot)

{
  printf 'status=%s command=gh' "$status"
  for arg in "$@"; do
    printf ' <%s>' "$arg"
  done
  printf '\n'
  printf 'before-state=%s\n' "$before_state"
  printf 'after-state=%s\n' "$after_state"
  for value_file in visibility remote-branch remote-tag remote-tag-name release-tag; do
    if [ -f "$state/$value_file" ]; then
      printf 'state-value[%s]=' "$value_file"
      cat "$state/$value_file"
      printf '\n'
    fi
  done
  printf 'stdout:\n'
  if [ -s "$stdout_file" ]; then
    sed 's/^/  /' "$stdout_file"
  else
    printf '  (empty)\n'
  fi
  printf 'stderr:\n'
  if [ -s "$stderr_file" ]; then
    sed 's/^/  /' "$stderr_file"
  else
    printf '  (empty)\n'
  fi
  printf '%s\n' '---'
} >> "$state/gh-results.log"

cat "$stdout_file"
cat "$stderr_file" >&2
rm -f "$stdout_file" "$stderr_file"
exit "$status"
SH

  chmod +x "$fake_bin/git" "$fake_bin/git-impl" \
    "$fake_bin/gh" "$fake_bin/gh-impl"
  PATH=$fake_bin:$PATH
  export PATH
  export GIT_AUTHOR_NAME='TAFFISH Test'
  export GIT_AUTHOR_EMAIL='taffish-test@example.invalid'
  export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
  export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
}

_taf_project_publish_diagnostics() {
  printf '%s\n' '--- publish diagnostics ---' >&2
  for diagnostic_file in \
    commands.log mutations.log git-results.log gh-results.log \
    local-git-results.log
  do
    diagnostic_path=$FAKE_PUBLISH_STATE/$diagnostic_file
    printf '%s:\n' "$diagnostic_path" >&2
    if [ -s "$diagnostic_path" ]; then
      sed 's/^/  /' "$diagnostic_path" >&2
    else
      printf '  (empty)\n' >&2
    fi
  done
  if [ -n "${REAL_GIT:-}" ]; then
    printf 'local git status:\n' >&2
    "$REAL_GIT" -C "$PWD" status --short --branch 2>&1 | \
      sed 's/^/  /' >&2 || true
  fi
  if [ -d "$TAFFISH_USER_HOME/history/publish" ]; then
    printf 'publish journals:\n' >&2
    find "$TAFFISH_USER_HOME/history/publish" -type f -print 2>/dev/null | \
      LC_ALL=C sort | while IFS= read -r diagnostic_path; do
        printf '  %s:\n' "$diagnostic_path" >&2
        sed 's/^/    /' "$diagnostic_path" >&2
      done
  fi
  printf '%s\n' '--- end publish diagnostics ---' >&2
}

_taf_project_require_publish_success() {
  publish_label=$1
  if assert_capture_success "$publish_label"; then
    return 0
  fi
  _taf_project_publish_diagnostics
  return 1
}

_taf_project_require_publish_failure() {
  publish_label=$1
  if assert_capture_failure "$publish_label"; then
    return 0
  fi
  _taf_project_publish_diagnostics
  return 1
}

_taf_project_assert_publish_interruption() {
  publish_output=$1
  publish_operation=$2
  publish_stage=$3
  publish_label=$4
  assert_contains "$publish_output" "[publish:unavailable]" \
    "$publish_label classification" || return 1
  assert_contains "$publish_output" \
    "could not confirm whether $publish_operation completed" \
    "$publish_label operation" || return 1
  assert_contains "$publish_output" \
    "Last confirmed stage: $publish_stage" \
    "$publish_label last confirmed stage" || return 1
  assert_contains "$publish_output" "rerun the same taf publish command" \
    "$publish_label retry guidance" || return 1
}

_taf_project_assert_mutation_count() {
  mutation=$1
  expected=$2
  label=$3
  actual=$(grep -c "^$mutation\$" "$FAKE_PUBLISH_STATE/mutations.log" || true)
  assert_eq "$expected" "$actual" "$label"
}

_taf_project_prepare_publish_project() {
  parent=$1
  name=$2
  mkdir -p "$parent"
  cd "$parent" || return 1
  "$TAF_BIN" new "$name" --flow --version "${3:-0.1.0}" >/dev/null || return 1
  cd "$name" || return 1
  printf '# offline publish recovery' > release.md
}

_taf_project_case_publish_resumes_remote_tag() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-remote-tag
  mkdir -p "$dir"
  (
    _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
    _taf_project_prepare_publish_project "$dir/work" publish-remote-tag || exit 1
    : > "$FAKE_PUBLISH_STATE/fail-after-remote-tag"

    capture_command "$TAF_BIN" publish --yes --release --create-repo
    _taf_project_require_publish_failure \
      "publish remote-tag interruption" || exit 1
    first_output=$TAFFISH_CAPTURE_OUTPUT
    _taf_project_assert_publish_interruption "$first_output" \
      "CREATE-REMOTE-TAG" "LOCAL-TAG-READY" \
      "remote tag interruption" || {
      _taf_project_publish_diagnostics
      exit 1
    }
    git_results=$(cat "$FAKE_PUBLISH_STATE/git-results.log")
    assert_contains "$git_results" "status=128" \
      "fake git records interrupted status" || exit 1
    assert_contains "$git_results" "after-state=" \
      "fake git records post-command state" || exit 1
    assert_contains "$git_results" "outage-git" \
      "fake git records outage marker" || exit 1
    assert_contains "$git_results" "fatal: connection reset by peer" \
      "fake git records interrupted stderr" || exit 1
    [ ! -f "$FAKE_PUBLISH_STATE/release-tag" ] || {
      printf 'release was created before remote tag confirmation\n' >&2
      exit 1
    }

    rm -f "$FAKE_PUBLISH_STATE/outage-git"
    capture_command "$TAF_BIN" publish --yes --release --create-repo
    _taf_project_require_publish_success \
      "publish remote-tag recovery" || exit 1
    second_output=$TAFFISH_CAPTURE_OUTPUT
    assert_contains "$second_output" "outcome : resumed" \
      "remote tag resumed outcome" || exit 1
    _taf_project_assert_mutation_count remote-tag-push 1 \
      "remote tag push count after recovery" || exit 1
    _taf_project_assert_mutation_count repository-create 1 \
      "repository create count after remote-tag recovery" || exit 1
    [ -f "$FAKE_PUBLISH_STATE/release-tag" ] || {
      printf 'release was not created after remote tag recovery\n' >&2
      exit 1
    }
  )
}

_taf_project_case_publish_build_resumes_without_rebuild() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-build-resume
  mkdir -p "$dir"
  (
    _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
    _taf_project_prepare_publish_project "$dir/work" publish-build-resume || exit 1
    : > "$FAKE_PUBLISH_STATE/fail-after-remote-tag"

    wrapper=target/taf-publish-build-resume-v0.1.0-r1
    snapshot=target/.taf-publish-build-resume-v0.1.0-r1
    manifest=$snapshot/.taf-build.json
    capture_command env TAFFISH_LANGUAGE=en "$TAF_BIN" publish \
      --yes --release --create-repo --build
    _taf_project_require_publish_failure \
      "publish --build remote-tag interruption" || exit 1
    first_output=$TAFFISH_CAPTURE_OUTPUT
    _taf_project_assert_publish_interruption "$first_output" \
      "CREATE-REMOTE-TAG" "LOCAL-TAG-READY" \
      "publish --build remote tag interruption" || {
      _taf_project_publish_diagnostics
      exit 1
    }
    assert_contains "$first_output" "built command" \
      "publish performs initial build" || exit 1
    assert_executable "$wrapper" || exit 1
    [ -f "$manifest" ] || {
      printf 'publish --build did not create build manifest\n' >&2
      exit 1
    }
    fingerprint_before=$(_taf_project_artifact_fingerprint "$wrapper" "$snapshot") || exit 1
    wrapper_mtime_before=$(_taf_project_mtime "$wrapper") || exit 1
    manifest_mtime_before=$(_taf_project_mtime "$manifest") || exit 1

    rm -f "$FAKE_PUBLISH_STATE/outage-git"
    sleep 1
    capture_command env TAFFISH_LANGUAGE=en "$TAF_BIN" publish \
      --yes --release --create-repo --build
    _taf_project_require_publish_success \
      "publish --build remote-tag recovery" || exit 1
    second_output=$TAFFISH_CAPTURE_OUTPUT
    fingerprint_after=$(_taf_project_artifact_fingerprint "$wrapper" "$snapshot") || exit 1
    assert_contains "$second_output" "outcome : resumed" \
      "publish --build resumed outcome" || exit 1
    assert_contains "$second_output" "build was skipped" \
      "publish --build established identity" || exit 1
    assert_eq "$fingerprint_before" "$fingerprint_after" \
      "publish resume preserves build artifacts" || exit 1
    assert_eq "$wrapper_mtime_before" "$(_taf_project_mtime "$wrapper")" \
      "publish resume preserves wrapper mtime" || exit 1
    assert_eq "$manifest_mtime_before" "$(_taf_project_mtime "$manifest")" \
      "publish resume preserves manifest mtime" || exit 1
    _taf_project_assert_mutation_count remote-tag-push 1 \
      "remote tag push count after publish --build recovery" || exit 1
    _taf_project_assert_mutation_count release-create 1 \
      "release create count after publish --build recovery" || exit 1

    mutations_before=$(wc -l < "$FAKE_PUBLISH_STATE/mutations.log")
    cat > src/main.taf <<'TAF'
<taffish>
echo 'DIRTY AFTER RELEASE'
TAF
    capture_command env TAFFISH_LANGUAGE=en "$TAF_BIN" publish \
      --yes --release --create-repo --build
    _taf_project_require_publish_failure \
      "publish --build dirty identity" || exit 1
    dirty_output=$TAFFISH_CAPTURE_OUTPUT
    assert_contains "$dirty_output" "[publish:conflict]" \
      "dirty release identity conflict" || exit 1
    assert_eq "$fingerprint_after" \
      "$(_taf_project_artifact_fingerprint "$wrapper" "$snapshot")" \
      "dirty resume preserves build artifacts" || exit 1
    assert_eq "$wrapper_mtime_before" "$(_taf_project_mtime "$wrapper")" \
      "dirty resume preserves wrapper mtime" || exit 1
    assert_eq "$manifest_mtime_before" "$(_taf_project_mtime "$manifest")" \
      "dirty resume preserves manifest mtime" || exit 1
    assert_eq "$mutations_before" \
      "$(wc -l < "$FAKE_PUBLISH_STATE/mutations.log")" \
      "dirty resume performs no remote mutation" || exit 1
  )
}

_taf_project_case_publish_resumes_early_remote_boundaries() {
  for boundary in repository immutable ruleset branch; do
    dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-$boundary
    mkdir -p "$dir"
    (
      _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
      _taf_project_prepare_publish_project "$dir/work" "publish-$boundary" || exit 1
      : > "$FAKE_PUBLISH_STATE/fail-after-$boundary"

      capture_command "$TAF_BIN" publish --yes --release --create-repo
      _taf_project_require_publish_failure \
        "publish $boundary interruption" || exit 1
      first_output=$TAFFISH_CAPTURE_OUTPUT
      case "$boundary" in
        repository)
          operation=
          stage=REPOSITORY-READY
          mutation=repository-create
          ;;
        immutable)
          operation=CREATE-POLICY
          stage=REPOSITORY-READY
          mutation=immutable-put
          ;;
        ruleset)
          operation=CREATE-POLICY
          stage=REPOSITORY-READY
          mutation=ruleset-post
          ;;
        branch)
          operation=CREATE-BRANCH
          stage=COMMIT-READY
          mutation=branch-push
          ;;
      esac
      if [ "$boundary" = repository ]; then
        assert_contains "$first_output" "[publish:unavailable]" \
          "repository interruption classification" || exit 1
        assert_contains "$first_output" \
          "failed to inspect GitHub repository metadata" \
          "repository post-create metadata inspection" || exit 1
        assert_contains "$first_output" \
          "Last confirmed stage: $stage" \
          "repository interruption last confirmed stage" || exit 1
        assert_contains "$first_output" \
          "rerun the same taf publish command" \
          "repository interruption retry guidance" || exit 1
        gh_results=$(cat "$FAKE_PUBLISH_STATE/gh-results.log")
        assert_contains "$gh_results" "status=1" \
          "fake gh records interrupted status" || exit 1
        assert_contains "$gh_results" "after-state=" \
          "fake gh records post-command state" || exit 1
        assert_contains "$gh_results" "outage-gh" \
          "fake gh records outage marker" || exit 1
        assert_contains "$gh_results" "connection reset by peer" \
          "fake gh records interrupted stderr" || exit 1
      else
        _taf_project_assert_publish_interruption "$first_output" \
          "$operation" "$stage" "$boundary interruption" || {
          _taf_project_publish_diagnostics
          exit 1
        }
      fi

      rm -f "$FAKE_PUBLISH_STATE/outage-git" "$FAKE_PUBLISH_STATE/outage-gh"
      capture_command "$TAF_BIN" publish --yes --release --create-repo
      _taf_project_require_publish_success \
        "publish $boundary recovery" || exit 1
      second_output=$TAFFISH_CAPTURE_OUTPUT
      assert_contains "$second_output" "outcome : resumed" \
        "$boundary resumed outcome" || exit 1
      _taf_project_assert_mutation_count "$mutation" 1 \
        "$boundary mutation count after recovery" || exit 1
      _taf_project_assert_mutation_count repository-create 1 \
        "$boundary repository create count" || exit 1
      _taf_project_assert_mutation_count release-create 1 \
        "$boundary release create count" || exit 1
    ) || return 1
  done
}

_taf_project_case_publish_resumes_release_and_noops() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-release
  mkdir -p "$dir"
  (
    _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
    _taf_project_prepare_publish_project "$dir/work" publish-release || exit 1
    : > "$FAKE_PUBLISH_STATE/fail-after-release"

    capture_command "$TAF_BIN" publish --yes --release --create-repo
    _taf_project_require_publish_failure \
      "publish release interruption" || exit 1
    first_output=$TAFFISH_CAPTURE_OUTPUT
    _taf_project_assert_publish_interruption "$first_output" \
      "CREATE-RELEASE" "REMOTE-TAG-READY" \
      "release interruption" || {
      _taf_project_publish_diagnostics
      exit 1
    }

    rm -f "$FAKE_PUBLISH_STATE/outage-gh"
    capture_command "$TAF_BIN" publish --yes --release --create-repo
    _taf_project_require_publish_success \
      "publish release recovery" || exit 1
    second_output=$TAFFISH_CAPTURE_OUTPUT
    assert_contains "$second_output" "outcome : resumed" \
      "release resumed outcome" || exit 1
    mutations_before=$(wc -l < "$FAKE_PUBLISH_STATE/mutations.log")
    capture_command "$TAF_BIN" publish --yes --release --create-repo
    _taf_project_require_publish_success \
      "completed publish no-op" || exit 1
    third_output=$TAFFISH_CAPTURE_OUTPUT
    mutations_after=$(wc -l < "$FAKE_PUBLISH_STATE/mutations.log")
    assert_contains "$third_output" "outcome : skipped" \
      "completed publish no-op outcome" || exit 1
    assert_eq "$mutations_before" "$mutations_after" \
      "completed publish has no repeated mutations" || exit 1
    _taf_project_assert_mutation_count release-create 1 \
      "release create count after no-op" || exit 1
  )
}

_taf_project_case_publish_dry_run_and_conflict() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-conflict
  mkdir -p "$dir"
  (
    _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
    _taf_project_prepare_publish_project "$dir/work" publish-conflict || exit 1

    capture_command "$TAF_BIN" publish --dry-run --release --create-repo --build
    _taf_project_require_publish_success "publish dry-run" || exit 1
    dry_output=$TAFFISH_CAPTURE_OUTPUT
    assert_contains "$dry_output" "outcome : planned" "publish dry-run outcome" || exit 1
    if [ -s "$FAKE_PUBLISH_STATE/mutations.log" ]; then
      printf 'dry-run executed fake remote mutations\n' >&2
      exit 1
    fi
    journal=$TAFFISH_USER_HOME/history/publish/taffish--publish-conflict/v0.1.0-r1.json
    [ ! -e "$journal" ] || {
      printf 'dry-run created a publish journal: %s\n' "$journal" >&2
      exit 1
    }
    [ ! -e target/taf-publish-conflict-v0.1.0-r1 ] || {
      printf 'dry-run --build created a command wrapper\n' >&2
      exit 1
    }
    [ ! -e target/.taf-publish-conflict-v0.1.0-r1 ] || {
      printf 'dry-run --build created a frozen snapshot\n' >&2
      exit 1
    }

    capture_command "$TAF_BIN" publish --yes --release --create-repo
    _taf_project_require_publish_success \
      "publish before conflict fixture" || exit 1
    printf '%040d' 0 > "$FAKE_PUBLISH_STATE/remote-tag"
    mutations_before=$(wc -l < "$FAKE_PUBLISH_STATE/mutations.log")
    capture_command "$TAF_BIN" publish --yes --release --create-repo
    _taf_project_require_publish_failure \
      "publish conflicting remote tag" || exit 1
    conflict_output=$TAFFISH_CAPTURE_OUTPUT
    assert_contains "$conflict_output" "[publish:conflict]" \
      "publish conflict classification" || exit 1
    mutations_after=$(wc -l < "$FAKE_PUBLISH_STATE/mutations.log")
    assert_eq "$mutations_before" "$mutations_after" \
      "conflict performs no further mutations" || exit 1
  )
}

_taf_project_case_publish_local_tag_locale_independent() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-localized-tag
  mkdir -p "$dir"
  (
    _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
    _taf_project_prepare_publish_project \
      "$dir/work" publish-localized-tag || exit 1
    : > "$FAKE_PUBLISH_STATE/localized-missing-tag"

    capture_command "$TAF_BIN" publish --yes --release --create-repo
    _taf_project_require_publish_success \
      "publish with localized missing-tag diagnostic" || {
      _taf_project_publish_diagnostics
      exit 1
    }
    output=$TAFFISH_CAPTURE_OUTPUT
    assert_contains "$output" "outcome : created" \
      "localized missing-tag publish outcome" || exit 1
    git_results=$(cat "$FAKE_PUBLISH_STATE/git-results.log")
    assert_contains "$git_results" "show-ref" \
      "localized missing-tag uses exact ref inspection" || exit 1
    assert_contains "$git_results" "se necesita una sola revision" \
      "fake git emitted non-English missing-tag diagnostic" || exit 1
    _taf_project_assert_mutation_count repository-create 1 \
      "localized missing-tag repository create count" || exit 1
    _taf_project_assert_mutation_count release-create 1 \
      "localized missing-tag release create count" || exit 1
  )
}

_taf_project_case_publish_channel_policy() {
  for policy in latest pre no-latest; do
    (
      dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-policy-$policy
      mkdir -p "$dir"
      _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
      case "$policy" in
        latest) set --; version=2.0.0-a.7.10; previous=2.0.0-a.7.3 ;;
        pre) set -- --pre; version=2.0.0-rc.10; previous=2.0.0 ;;
        no-latest) set -- --no-latest; version=1.9.0; previous=2.0.0 ;;
      esac
      _taf_project_prepare_publish_project \
        "$dir/work" "publish-policy-$policy" "$version" || exit 1
      : > "$FAKE_PUBLISH_STATE/repository"
      printf '%040d\trefs/tags/v%s-r1\n' 1 "$previous" > "$FAKE_PUBLISH_STATE/other-tags"
      printf 'v%s-r1' "$previous" > "$FAKE_PUBLISH_STATE/latest-tag"
      local_before=$(find . -type f -exec cksum {} \; | LC_ALL=C sort)
      capture_command "$TAF_BIN" publish --release --build --dry-run "$@"
      _taf_project_require_publish_success "channel $policy dry-run" || exit 1
      planned=$TAFFISH_CAPTURE_OUTPUT
      assert_contains "$planned" '--verify-tag' "channel verifies remote tag" || exit 1
      local_after=$(find . -type f -exec cksum {} \; | LC_ALL=C sort)
      assert_eq "$local_before" "$local_after" "channel dry-run leaves project intact" || exit 1
      [ ! -s "$FAKE_PUBLISH_STATE/mutations.log" ] || exit 1
      journal=$TAFFISH_USER_HOME/history/publish/taffish--publish-policy-$policy/v$version-r1.json
      [ ! -e "$journal" ] || exit 1

      capture_command "$TAF_BIN" publish --release --build --yes "$@"
      _taf_project_require_publish_success "channel $policy execution" || exit 1
      create_command=$(grep '^gh release create ' "$FAKE_PUBLISH_STATE/commands.log")
      # Plans show a project-relative notes path; execution uses its absolute path.
      notes_and_flags=${create_command#* --notes-file }
      assert_eq "$(pwd -P)/release.md" "${notes_and_flags%% --verify-tag*}" \
        "execution notes file" || exit 1
      normalized_command="${create_command%% --notes-file *} --notes-file release.md --verify-tag${create_command#* --verify-tag}"
      assert_contains "$planned" "$normalized_command" "plan/execution channel command" || exit 1
      expected_pre=false
      [ "$policy" != pre ] || expected_pre=true
      assert_eq "$expected_pre" "$(cat "$FAKE_PUBLISH_STATE/release-prerelease")" \
        "channel prerelease state" || exit 1
      if [ "$policy" = latest ]; then
        assert_eq "v$version-r1" "$(cat "$FAKE_PUBLISH_STATE/latest-tag")" \
          "default explicitly promotes alpha-named version" || exit 1
      else
        assert_eq "v$previous-r1" "$(cat "$FAKE_PUBLISH_STATE/latest-tag")" \
          "non-latest channel preserves recommendation" || exit 1
      fi
      # Model another release becoming Latest after this transaction completes.
      printf 'v99.0.0-r1' > "$FAKE_PUBLISH_STATE/latest-tag"
      before=$(cat "$FAKE_PUBLISH_STATE/mutations.log")
      capture_command "$TAF_BIN" publish --release --build --yes "$@"
      _taf_project_require_publish_success "channel $policy no-op" || exit 1
      assert_eq "$before" "$(cat "$FAKE_PUBLISH_STATE/mutations.log")" \
        "channel no-op does not mutate" || exit 1
      assert_eq v99.0.0-r1 "$(cat "$FAKE_PUBLISH_STATE/latest-tag")" \
        "retry does not reclaim Latest" || exit 1
    ) || return 1
  done
}

_taf_project_case_publish_channel_resume_and_journal() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-channel-resume
  mkdir -p "$dir"
  (
    _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
    _taf_project_prepare_publish_project "$dir/work" publish-channel-resume || exit 1
    : > "$FAKE_PUBLISH_STATE/fail-after-release"
    capture_command "$TAF_BIN" publish --release --pre --yes --create-repo
    _taf_project_require_publish_failure "pre-release transport interruption" || exit 1
    _taf_project_assert_publish_interruption "$TAFFISH_CAPTURE_OUTPUT" \
      CREATE-RELEASE REMOTE-TAG-READY "pre-release interruption" || exit 1
    before=$(cat "$FAKE_PUBLISH_STATE/mutations.log")
    capture_command "$TAF_BIN" publish --release --no-latest --yes --create-repo
    _taf_project_require_publish_failure "channel intent changed during outage" || exit 1
    assert_contains "$TAFFISH_CAPTURE_OUTPUT" '[publish:conflict]' "journal channel conflict" || exit 1
    assert_eq "$before" "$(cat "$FAKE_PUBLISH_STATE/mutations.log")" "conflict does not mutate" || exit 1
    rm -f "$FAKE_PUBLISH_STATE/outage-gh"
    capture_command "$TAF_BIN" publish --release --pre --yes --create-repo
    _taf_project_require_publish_success "pre-release recovery" || exit 1
    assert_eq true "$(cat "$FAKE_PUBLISH_STATE/release-prerelease")" "recovered prerelease" || exit 1
    _taf_project_assert_mutation_count release-create 1 "recovery avoids duplicate Release" || exit 1
    journal=$TAFFISH_USER_HOME/history/publish/taffish--publish-channel-resume/v0.1.0-r1.json
    # Old journals lack channel fields. Remote facts must still enforce type.
    sed '/"channel"/d; /"latest_policy"/d' "$journal" > "$dir/legacy.json"
    cp "$dir/legacy.json" "$journal"
    capture_command "$TAF_BIN" publish --release --yes --create-repo
    _taf_project_require_publish_failure "legacy journal remote type conflict" || exit 1
    assert_contains "$TAFFISH_CAPTURE_OUTPUT" '[publish:conflict]' "remote type conflict" || exit 1
    assert_eq "$before" "$(cat "$FAKE_PUBLISH_STATE/mutations.log")" "legacy conflict does not mutate" || exit 1
    capture_command "$TAF_BIN" publish --release --pre --yes --create-repo
    _taf_project_require_publish_success "legacy journal matching pre-release" || exit 1
    rm "$journal"
    capture_command "$TAF_BIN" publish --release --pre --yes --create-repo
    _taf_project_require_publish_success "no journal matching pre-release" || exit 1
    _taf_project_assert_mutation_count release-create 1 "no-journal recovery avoids duplicates" || exit 1
  )
}

_taf_project_case_publish_release_identity() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-release-identity
  mkdir -p "$dir"
  (
    _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
    _taf_project_prepare_publish_project "$dir/work" publish-release-identity || exit 1
    capture_command "$TAF_BIN" publish --release --yes --create-repo
    _taf_project_require_publish_success "release identity fixture" || exit 1
    before=$(cat "$FAKE_PUBLISH_STATE/mutations.log")
    for defect in prerelease draft title notes incomplete; do
      cp "$FAKE_PUBLISH_STATE/release-title" "$dir/title"
      cp "$FAKE_PUBLISH_STATE/release-notes" "$dir/notes"
      case "$defect" in
        prerelease) printf true > "$FAKE_PUBLISH_STATE/release-prerelease" ;;
        draft) : > "$FAKE_PUBLISH_STATE/release-draft" ;;
        title) printf 'different title' > "$FAKE_PUBLISH_STATE/release-title" ;;
        notes) printf 'different notes' > "$FAKE_PUBLISH_STATE/release-notes" ;;
        incomplete) printf null > "$FAKE_PUBLISH_STATE/release-prerelease" ;;
      esac
      capture_command "$TAF_BIN" publish --release --yes --create-repo
      _taf_project_require_publish_failure "release $defect is rejected" || exit 1
      category=conflict
      [ "$defect" != incomplete ] || category=unavailable
      assert_contains "$TAFFISH_CAPTURE_OUTPUT" "[publish:$category]" "release $defect category" || exit 1
      assert_eq "$before" "$(cat "$FAKE_PUBLISH_STATE/mutations.log")" "release $defect no overwrite" || exit 1
      printf false > "$FAKE_PUBLISH_STATE/release-prerelease"
      rm -f "$FAKE_PUBLISH_STATE/release-draft"
      cp "$dir/title" "$FAKE_PUBLISH_STATE/release-title"
      cp "$dir/notes" "$FAKE_PUBLISH_STATE/release-notes"
    done
  )
}

_taf_project_case_publish_tag_only_and_channel_options() {
  for language in en zh; do
    capture_command env TAFFISH_LANGUAGE="$language" "$TAF_BIN" publish --help
    _taf_project_require_publish_success "publish $language help" || return 1
    for flag in --latest --pre --no-latest --release --dry-run --yes; do
      assert_contains "$TAFFISH_CAPTURE_OUTPUT" "$flag" "publish $language help flag" || return 1
    done
  done
  for policy in latest pre no-latest; do
    (
      dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-tag-only-$policy
      mkdir -p "$dir"
      _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
      _taf_project_prepare_publish_project "$dir/work" "publish-tag-only-$policy" || exit 1
      # A tag-only publish neither needs release.md nor creates a Release.
      rm release.md
      capture_command "$TAF_BIN" publish --yes --create-repo "--$policy"
      _taf_project_require_publish_success "tag-only $policy" || exit 1
      assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'tag-only' "explicit tag-only summary" || exit 1
      [ ! -e "$FAKE_PUBLISH_STATE/release-tag" ] || exit 1
      _taf_project_assert_mutation_count release-create 0 "tag-only release count" || exit 1
      for second in latest pre no-latest; do
        [ "$policy" != "$second" ] || continue
        before=$(cat "$FAKE_PUBLISH_STATE/mutations.log")
        capture_command "$TAF_BIN" publish --yes "--$policy" "--$second"
        _taf_project_require_publish_failure "incompatible channel options" || exit 1
        assert_contains "$TAFFISH_CAPTURE_OUTPUT" '--' "channel conflict diagnostic" || exit 1
        assert_eq "$before" "$(cat "$FAKE_PUBLISH_STATE/mutations.log")" "CLI rejection is read-only" || exit 1
      done
    ) || return 1
  done
}

_taf_project_case_publish_stage_output() {
  (
    dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-stage-output
    mkdir -p "$dir"
    _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
    _taf_project_prepare_publish_project "$dir/work" publish-stage-output || exit 1
    "$TAF_BIN" publish --dry-run --release --create-repo >"$dir/preview.out" 2>"$dir/preview.err" || exit 1
    assert_contains "$(cat "$dir/preview.err")" "Checking repository" "early publish status" || exit 1
    assert_not_contains "$(cat "$dir/preview.err")" "Applying publish step" "dry-run does not claim writes" || exit 1
    [ ! -s "$FAKE_PUBLISH_STATE/mutations.log" ] || exit 1

    "$TAF_BIN" publish --yes --build --release --create-repo >"$dir/publish.out" 2>"$dir/publish.err" || {
      cat "$dir/publish.err" >&2
      _taf_project_publish_diagnostics
      exit 1
    }
    assert_contains "$(cat "$dir/publish.out")" "outcome : created" "publish outcome" || exit 1
    assert_not_contains "$(cat "$dir/publish.out")" "[TAF] Checking repository" "status is not stdout" || exit 1
    _taf_project_assert_mutation_count repository-create 1 "one repository" || exit 1
    _taf_project_assert_mutation_count release-create 1 "one release" || exit 1
    before=$(cat "$FAKE_PUBLISH_STATE/mutations.log")
    "$TAF_BIN" publish --yes --build --release --create-repo >"$dir/noop.out" 2>"$dir/noop.err" || exit 1
    assert_eq "$before" "$(cat "$FAKE_PUBLISH_STATE/mutations.log")" "notices cannot cause writes" || exit 1
    assert_not_contains "$(cat "$dir/noop.err")" "Applying publish step" "matching state is not a mutation" || exit 1
  )
}

run_taf_project_conformance() {
  run_case "taf-project/inline-source-boundaries" \
    python3 "$TAFFISH_TEST_REPO_ROOT/test/taffish/argument-contract.py" project-boundaries
  run_case "taf-project/publish-stage-output" _taf_project_case_publish_stage_output
  run_case "taf-project/new-check-compile-from-nested" _taf_project_case_new_check_compile_from_nested
  run_case "taf-project/smoke-placeholder-boundary" \
    _taf_project_case_smoke_placeholder_boundary
  run_case "taf-project/build-wrapper-run-compile-help" _taf_project_case_build_wrapper_run_compile_help
  run_case "taf-project/build-uses-frozen-snapshot" _taf_project_case_build_uses_frozen_snapshot
  run_case "taf-project/wrapper-pipeline-concurrency" \
    _taf_project_case_wrapper_pipeline_concurrency
  run_case "taf-project/wrapper-history-concurrency" \
    _taf_project_case_wrapper_history_concurrency
  run_case "taf-project/unicode-build-and-history" \
    _taf_project_case_unicode_build_and_history
  run_case "taf-project/run-stdin-process-boundary" \
    _taf_project_case_run_stdin_process_boundary
  run_case "taf-project/build-is-idempotent-and-exact" _taf_project_case_build_is_idempotent_and_exact
  run_case "taf-project/new-docker-native-actions" _taf_project_case_new_docker_workflow_contract
  run_case "taf-project/publish-resumes-early-remote-boundaries" _taf_project_case_publish_resumes_early_remote_boundaries
  run_case "taf-project/publish-resumes-remote-tag" _taf_project_case_publish_resumes_remote_tag
  run_case "taf-project/publish-build-resumes-without-rebuild" _taf_project_case_publish_build_resumes_without_rebuild
  run_case "taf-project/publish-resumes-release-and-noops" _taf_project_case_publish_resumes_release_and_noops
  run_case "taf-project/publish-dry-run-and-conflict" _taf_project_case_publish_dry_run_and_conflict
  run_case "taf-project/publish-local-tag-locale-independent" \
    _taf_project_case_publish_local_tag_locale_independent
  run_case "taf-project/publish-channel-policy" _taf_project_case_publish_channel_policy
  run_case "taf-project/publish-channel-resume-and-journal" _taf_project_case_publish_channel_resume_and_journal
  run_case "taf-project/publish-release-identity" _taf_project_case_publish_release_identity
  run_case "taf-project/publish-tag-only-and-channel-options" _taf_project_case_publish_tag_only_and_channel_options
}
