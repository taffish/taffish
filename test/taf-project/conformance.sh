# External conformance tests for real taf project workflows.
# This file is sourced by test/run-tests.sh.

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

  REAL_GIT=$(command -v git) || return 1
  export REAL_GIT
  export FAKE_PUBLISH_STATE=$fake_state

  cat > "$fake_bin/git" <<'SH'
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
    elif [ "$mode" = "--tags" ] && [ -f "$state/remote-tag" ]; then
      commit=$(cat "$state/remote-tag")
      tag=$(cat "$state/remote-tag-name")
      printf '%s\trefs/tags/%s\n' "$commit" "$tag"
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
    exec "$REAL_GIT" -C "$root" "$@"
    ;;
esac
SH

  cat > "$fake_bin/gh" <<'SH'
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
    printf '{"tagName":"%s","name":"%s","body":"%s","isDraft":false,"isPrerelease":false,"targetCommitish":"main"}\n' \
      "$tag" "$title" "$body"
    ;;
  "release create")
    tag=$3
    shift 3
    title=
    notes_file=
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --title) shift; title=$1 ;;
        --notes-file) shift; notes_file=$1 ;;
      esac
      shift
    done
    printf '%s' "$tag" > "$state/release-tag"
    printf '%s' "$title" > "$state/release-title"
    cat "$notes_file" > "$state/release-notes"
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

  chmod +x "$fake_bin/git" "$fake_bin/gh"
  PATH=$fake_bin:$PATH
  export PATH
  export GIT_AUTHOR_NAME='TAFFISH Test'
  export GIT_AUTHOR_EMAIL='taffish-test@example.invalid'
  export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
  export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
}

_taf_project_prepare_publish_project() {
  parent=$1
  name=$2
  mkdir -p "$parent"
  cd "$parent" || return 1
  "$TAF_BIN" new "$name" --flow >/dev/null || return 1
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

    set +e
    first_output=$("$TAF_BIN" publish --yes --release --create-repo 2>&1)
    first_status=$?
    set -e
    [ "$first_status" -ne 0 ] || {
      printf 'publish unexpectedly succeeded while remote tag confirmation was unavailable\n' >&2
      exit 1
    }
    assert_contains "$first_output" "rerun the same taf publish command" \
      "remote tag recovery guidance" || exit 1
    [ ! -f "$FAKE_PUBLISH_STATE/release-tag" ] || {
      printf 'release was created before remote tag confirmation\n' >&2
      exit 1
    }

    rm -f "$FAKE_PUBLISH_STATE/outage-git"
    second_output=$("$TAF_BIN" publish --yes --release --create-repo) || exit 1
    assert_contains "$second_output" "outcome : resumed" \
      "remote tag resumed outcome" || exit 1
    [ "$(grep -c '^remote-tag-push$' "$FAKE_PUBLISH_STATE/mutations.log")" -eq 1 ] || {
      printf 'remote tag push was repeated during recovery\n' >&2
      exit 1
    }
    [ -f "$FAKE_PUBLISH_STATE/release-tag" ] || {
      printf 'release was not created after remote tag recovery\n' >&2
      exit 1
    }
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

      set +e
      first_output=$("$TAF_BIN" publish --yes --release --create-repo 2>&1)
      first_status=$?
      set -e
      [ "$first_status" -ne 0 ] || {
        printf 'publish unexpectedly succeeded after %s interruption\n' "$boundary" >&2
        exit 1
      }
      assert_contains "$first_output" "rerun the same taf publish command" \
        "$boundary recovery guidance" || exit 1

      rm -f "$FAKE_PUBLISH_STATE/outage-git" "$FAKE_PUBLISH_STATE/outage-gh"
      second_output=$("$TAF_BIN" publish --yes --release --create-repo) || exit 1
      assert_contains "$second_output" "outcome : resumed" \
        "$boundary resumed outcome" || exit 1
      case "$boundary" in
        repository) mutation=repository-create ;;
        immutable) mutation=immutable-put ;;
        ruleset) mutation=ruleset-post ;;
        branch) mutation=branch-push ;;
      esac
      [ "$(grep -c "^$mutation\$" "$FAKE_PUBLISH_STATE/mutations.log")" -eq 1 ] || {
        printf '%s mutation was repeated during recovery\n' "$boundary" >&2
        exit 1
      }
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

    set +e
    first_output=$("$TAF_BIN" publish --yes --release --create-repo 2>&1)
    first_status=$?
    set -e
    [ "$first_status" -ne 0 ] || {
      printf 'publish unexpectedly succeeded while release confirmation was unavailable\n' >&2
      exit 1
    }
    assert_contains "$first_output" "rerun the same taf publish command" \
      "release recovery guidance" || exit 1

    rm -f "$FAKE_PUBLISH_STATE/outage-gh"
    second_output=$("$TAF_BIN" publish --yes --release --create-repo) || exit 1
    assert_contains "$second_output" "outcome : resumed" \
      "release resumed outcome" || exit 1
    mutations_before=$(wc -l < "$FAKE_PUBLISH_STATE/mutations.log")
    third_output=$("$TAF_BIN" publish --yes --release --create-repo) || exit 1
    mutations_after=$(wc -l < "$FAKE_PUBLISH_STATE/mutations.log")
    assert_contains "$third_output" "outcome : skipped" \
      "completed publish no-op outcome" || exit 1
    assert_eq "$mutations_before" "$mutations_after" \
      "completed publish has no repeated mutations" || exit 1
    [ "$(grep -c '^release-create$' "$FAKE_PUBLISH_STATE/mutations.log")" -eq 1 ] || {
      printf 'GitHub Release creation was repeated\n' >&2
      exit 1
    }
  )
}

_taf_project_case_publish_dry_run_and_conflict() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-publish-conflict
  mkdir -p "$dir"
  (
    _taf_project_setup_fake_publish_commands "$dir/fake" || exit 1
    _taf_project_prepare_publish_project "$dir/work" publish-conflict || exit 1

    dry_output=$("$TAF_BIN" publish --dry-run --release --create-repo) || exit 1
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

    "$TAF_BIN" publish --yes --release --create-repo >/dev/null || exit 1
    printf '%040d' 0 > "$FAKE_PUBLISH_STATE/remote-tag"
    mutations_before=$(wc -l < "$FAKE_PUBLISH_STATE/mutations.log")
    set +e
    conflict_output=$("$TAF_BIN" publish --yes --release --create-repo 2>&1)
    conflict_status=$?
    set -e
    [ "$conflict_status" -ne 0 ] || {
      printf 'publish accepted a conflicting remote tag\n' >&2
      exit 1
    }
    assert_contains "$conflict_output" "[publish:conflict]" \
      "publish conflict classification" || exit 1
    mutations_after=$(wc -l < "$FAKE_PUBLISH_STATE/mutations.log")
    assert_eq "$mutations_before" "$mutations_after" \
      "conflict performs no further mutations" || exit 1
  )
}

run_taf_project_conformance() {
  run_case "taf-project/new-check-compile-from-nested" _taf_project_case_new_check_compile_from_nested
  run_case "taf-project/build-wrapper-run-compile-help" _taf_project_case_build_wrapper_run_compile_help
  run_case "taf-project/build-uses-frozen-snapshot" _taf_project_case_build_uses_frozen_snapshot
  run_case "taf-project/new-docker-native-actions" _taf_project_case_new_docker_workflow_contract
  run_case "taf-project/publish-resumes-early-remote-boundaries" _taf_project_case_publish_resumes_early_remote_boundaries
  run_case "taf-project/publish-resumes-remote-tag" _taf_project_case_publish_resumes_remote_tag
  run_case "taf-project/publish-resumes-release-and-noops" _taf_project_case_publish_resumes_release_and_noops
  run_case "taf-project/publish-dry-run-and-conflict" _taf_project_case_publish_dry_run_and_conflict
}
