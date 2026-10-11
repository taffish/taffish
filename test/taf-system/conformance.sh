# External conformance tests for taf doctor and its MCP projection.
# This file is sourced by test/run-tests.sh.

_taf_system_json_check() {
  script=$1
  python3 -c "$script"
}

_taf_system_case_doctor_read_only_and_output() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-system-read-only
  (
    export HOME=$dir/os-home
    export TAFFISH_USER_HOME=$dir/user-home
    export TAFFISH_SYSTEM_HOME=$dir/system-home
    mkdir -p "$HOME"
    printf '# unchanged bashrc\n' > "$HOME/.bashrc"
    printf '" unchanged vimrc\n' > "$HOME/.vimrc"

    output=$($TAF_BIN doctor --user --shell bash) || exit 1
    assert_contains "$output" "Diagnostics:" "doctor concise diagnostics" || exit 1
    assert_contains "$output" "shell-completion" "doctor reports completion issue" || exit 1
    assert_not_contains "$output" "evidence:" "doctor concise output hides evidence" || exit 1
    [ ! -e "$TAFFISH_USER_HOME" ] || {
      printf 'read-only doctor unexpectedly created user home\n' >&2
      exit 1
    }
    assert_eq '# unchanged bashrc' "$(cat "$HOME/.bashrc")" \
      "doctor keeps bashrc" || exit 1
    assert_eq '" unchanged vimrc' "$(cat "$HOME/.vimrc")" \
      "doctor keeps vimrc" || exit 1

    verbose=$($TAF_BIN doctor --user --shell bash --verbose) || exit 1
    assert_contains "$verbose" "evidence:" "doctor verbose evidence" || exit 1
    assert_contains "$verbose" "remediation :" "doctor verbose remediation" || exit 1

    json=$($TAF_BIN doctor --user --shell bash --json) || exit 1
    printf '%s' "$json" | _taf_system_json_check '
import json, sys
data = json.load(sys.stdin)
assert data["schema_version"] == "taffish.doctor/v1"
assert data["scope"] == "user"
assert data["init_p"] is False
assert isinstance(data["diagnostics"], list) and data["diagnostics"]
required = {"id", "status", "scope", "summary", "evidence", "remediation", "docs_url"}
assert all(required <= set(item) for item in data["diagnostics"])
assert {item["id"] for item in data["diagnostics"]} >= {
    "home", "config", "index", "command_path", "shell_completion",
    "vim_runtime", "apptainer_sif_cache", "container_backends"
}
' || exit 1

    if $TAF_BIN doctor --shell tcsh >/dev/null 2>&1; then
      printf 'doctor accepted an unsupported shell\n' >&2
      exit 1
    fi
  )
}

_taf_system_case_doctor_init_completion_and_vim() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-system-init
  (
    export HOME=$dir/os-home
    export TAFFISH_USER_HOME=$dir/user-home
    export TAFFISH_SYSTEM_HOME=$dir/system-home
    mkdir -p "$HOME"
    printf '# unchanged before init\n' > "$HOME/.bashrc"
    printf '" unchanged before init\n' > "$HOME/.vimrc"

    $TAF_BIN doctor --init --user --shell bash >/dev/null || exit 1
    for required in \
      apps index index/snapshots images/sif bin cache/repos \
      share/completions/bash share/vim/syntax share/vim/ftdetect logs
    do
      [ -d "$TAFFISH_USER_HOME/$required" ] || {
        printf 'doctor --init did not create %s\n' "$required" >&2
        exit 1
      }
    done
    assert_eq '# unchanged before init' "$(cat "$HOME/.bashrc")" \
      "doctor init keeps bashrc" || exit 1
    assert_eq '" unchanged before init' "$(cat "$HOME/.vimrc")" \
      "doctor init keeps vimrc" || exit 1

    printf '# taf completion\n' > "$TAFFISH_USER_HOME/share/completions/bash/taf"
    printf '# taffish completion\n' > "$TAFFISH_USER_HOME/share/completions/bash/taffish"
    unknown_json=$($TAF_BIN doctor --user --shell bash --json) || exit 1
    printf '%s' "$unknown_json" | _taf_system_json_check '
import json, sys
data = json.load(sys.stdin)
items = {item["id"]: item for item in data["diagnostics"]}
assert items["shell_completion"]["status"] == "unknown"
' || exit 1

    completion_root=$(CDPATH= cd -- \
      "$TAFFISH_USER_HOME/share/completions" && pwd)
    cat > "$HOME/.bashrc" <<EOF_BASHRC
source $completion_root/bash/taf
source $completion_root/bash/taffish
EOF_BASHRC
    mkdir -p "$HOME/.vim/syntax" "$HOME/.vim/ftdetect"
    printf '" taf syntax\n' > "$TAFFISH_USER_HOME/share/vim/syntax/taf.vim"
    printf '" taf ftdetect\n' > "$TAFFISH_USER_HOME/share/vim/ftdetect/taf.vim"
    printf '" taf syntax\n' > "$HOME/.vim/syntax/taf.vim"
    printf '" taf ftdetect\n' > "$HOME/.vim/ftdetect/taf.vim"

    active_json=$($TAF_BIN doctor --user --shell bash --json) || exit 1
    printf '%s' "$active_json" | _taf_system_json_check '
import json, sys
data = json.load(sys.stdin)
items = {item["id"]: item for item in data["diagnostics"]}
assert items["shell_completion"]["status"] == "ok"
assert items["vim_runtime"]["status"] in {"ok", "not_applicable"}
' || exit 1
  )
}

_taf_system_case_doctor_sif_and_backend_policies() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-system-policies
  (
    export HOME=$dir/os-home
    export TAFFISH_USER_HOME=$dir/user-home
    export TAFFISH_SYSTEM_HOME=$dir/system-home
    fake_bin=$dir/fake-bin
    mkdir -p "$HOME" "$TAFFISH_USER_HOME/images/sif" \
      "$TAFFISH_SYSTEM_HOME/images/sif" "$fake_bin"
    chmod 0700 "$TAFFISH_USER_HOME/images/sif"

    cat > "$fake_bin/docker" <<'EOF_DOCKER'
#!/bin/sh
printf 'fake-docker\n'
exit 0
EOF_DOCKER
    cat > "$fake_bin/podman" <<'EOF_PODMAN'
#!/bin/sh
printf 'fake-podman-unavailable\n' >&2
exit 7
EOF_PODMAN
    cat > "$fake_bin/apptainer" <<'EOF_APPTAINER'
#!/bin/sh
sleep 5
EOF_APPTAINER
    chmod +x "$fake_bin/docker" "$fake_bin/podman" "$fake_bin/apptainer"
    export PATH=$fake_bin:$PATH

    chmod 1777 "$TAFFISH_SYSTEM_HOME/images/sif"
    shared_json=$($TAF_BIN doctor --system --shell bash --json) || exit 1
    printf '%s' "$shared_json" | _taf_system_json_check '
import json, sys
data = json.load(sys.stdin)
items = {item["id"]: item for item in data["diagnostics"]}
assert items["apptainer_sif_cache"]["status"] == "ok"
assert "sticky" in items["apptainer_sif_cache"]["summary"].lower()
backends = {item["name"]: item for item in items["container_backends"]["evidence"]["backends"]}
assert backends["docker"]["status"] == "ok"
assert backends["podman"]["status"] == "unavailable"
assert backends["apptainer"]["status"] == "timeout"
' || exit 1

    chmod 0777 "$TAFFISH_SYSTEM_HOME/images/sif"
    unsafe_json=$($TAF_BIN doctor --system --shell bash --json) || exit 1
    printf '%s' "$unsafe_json" | _taf_system_json_check '
import json, sys
data = json.load(sys.stdin)
items = {item["id"]: item for item in data["diagnostics"]}
assert items["apptainer_sif_cache"]["status"] == "error"
' || exit 1

    chmod 0555 "$TAFFISH_SYSTEM_HOME/images/sif"
    readonly_json=$($TAF_BIN doctor --system --shell bash --json) || exit 1
    printf '%s' "$readonly_json" | _taf_system_json_check '
import json, sys
data = json.load(sys.stdin)
items = {item["id"]: item for item in data["diagnostics"]}
assert items["apptainer_sif_cache"]["status"] == "ok"
assert "read-only" in items["apptainer_sif_cache"]["summary"].lower()
' || exit 1
    chmod 0700 "$TAFFISH_SYSTEM_HOME/images/sif"
  )
}

_taf_system_case_mcp_environment_is_read_only() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-system-mcp
  (
    export HOME=$dir/os-home
    export TAFFISH_USER_HOME=$dir/user-home
    export TAFFISH_SYSTEM_HOME=$dir/system-home
    mkdir -p "$HOME"

    tools=$(printf '%s\n' \
      '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' |
      $TAFFISH_MCP_BIN 2>/dev/null) || exit 1
    printf '%s' "$tools" | _taf_system_json_check '
import json, sys
data = json.load(sys.stdin)
tools = {item["name"]: item for item in data["result"]["tools"]}
tool = tools["taffish_check_environment"]
props = tool["inputSchema"]["properties"]
assert not ({"init", "initP", "fix", "force", "repair"} & set(props))
assert "read-only" in tool["description"].lower()
' || exit 1

    user_json=$(printf '%s' "$TAFFISH_USER_HOME" | sed 's/\\/\\\\/g; s/"/\\"/g')
    system_json=$(printf '%s' "$TAFFISH_SYSTEM_HOME" | sed 's/\\/\\\\/g; s/"/\\"/g')
    response=$(printf '%s\n' \
      "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"taffish_check_environment\",\"arguments\":{\"scope\":\"user\",\"userHome\":\"$user_json\",\"systemHome\":\"$system_json\"}}}" |
      $TAFFISH_MCP_BIN 2>/dev/null) || exit 1
    printf '%s' "$response" | _taf_system_json_check '
import json, sys
data = json.load(sys.stdin)
result = data["result"]
assert result.get("isError") in {False, None}
structured = result["structuredContent"]
assert structured["init_p"] is False
assert isinstance(structured["diagnostics"], list) and structured["diagnostics"]
' || exit 1
    [ ! -e "$TAFFISH_USER_HOME" ] || {
      printf 'MCP environment check unexpectedly created user home\n' >&2
      exit 1
    }
  )
}

_taf_system_mcp_session_requests() {
  cat <<'EOF_MCP_SESSION'
{"jsonrpc":"2.0","id":101,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"external-conformance","version":"0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}
{"jsonrpc":"2.0","id":102,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":103,"method":"resources/list","params":{}}
{"jsonrpc":"2.0","id":104,"method":"prompts/list","params":{}}
{"jsonrpc":"2.0","id":105,"method":"tools/call","params":{"name":"taffish_get_version","arguments":{}}}
{"jsonrpc":"2.0","id":106,"method":"tools/call","params":{"name":"taffish_get_config","arguments":{}}}
{"jsonrpc":"2.0","id":107,"method":"tools/call","params":{"name":"taffish_get_help","arguments":{"topic":"safety"}}}
EOF_MCP_SESSION
}

_taf_system_case_mcp_long_stdio_session() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-system-mcp-session
  mkdir -p "$dir/user-home" "$dir/system-home"

  _taf_system_mcp_session_requests |
    env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$dir/user-home" \
      TAFFISH_SYSTEM_HOME="$dir/system-home" \
      "$TAFFISH_MCP_BIN" >"$dir/responses.jsonl" 2>"$dir/stderr.log" || {
        printf 'MCP long stdio session process failed\n' >&2
        sed 's/^/  /' "$dir/stderr.log" >&2
        return 1
      }

  python3 - "$dir/responses.jsonl" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    lines = [line.rstrip("\n") for line in handle if line.strip()]

responses = []
for number, line in enumerate(lines, 1):
    try:
        responses.append(json.loads(line))
    except json.JSONDecodeError as error:
        raise AssertionError(f"response line {number} is not JSON: {line!r}") from error

expected_ids = {101, 102, 103, 104, 105, 106, 107}
actual_ids = {response.get("id") for response in responses}
assert actual_ids == expected_ids, (actual_ids, expected_ids, responses)
assert len(responses) == len(expected_ids), responses
by_id = {response["id"]: response for response in responses}
assert all(response.get("jsonrpc") == "2.0" for response in responses)
assert all("error" not in response for response in responses), responses

assert "protocolVersion" in by_id[101]["result"]
tools = by_id[102]["result"]["tools"]
tool_names = {tool["name"] for tool in tools}
assert {"taffish_get_version", "taffish_get_config", "taffish_get_help"} <= tool_names
assert isinstance(by_id[103]["result"]["resources"], list)
assert isinstance(by_id[104]["result"]["prompts"], list)

for response_id in (105, 106, 107):
    result = by_id[response_id]["result"]
    assert result.get("isError") in {False, None}, result
    assert "structuredContent" in result, result

assert "taffish_mcp" in by_id[105]["result"]["structuredContent"]
assert by_id[106]["result"]["structuredContent"]["schema_version"] == "taffish.config/v1"
assert "language" in by_id[106]["result"]["structuredContent"]
assert by_id[107]["result"]["structuredContent"]["topic"] == "safety"
PY
}

_taf_system_case_error_stream_and_history_identity() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-system-stream-history
  user_home=$dir/user-home
  mkdir -p "$user_home"

  set +e
  "$TAF_BIN" definitely-not-a-command >"$dir/stdout.log" 2>"$dir/stderr.log"
  status=$?
  set -e
  [ "$status" -ne 0 ] || harness_fail "unknown taf command unexpectedly succeeded"
  [ ! -s "$dir/stdout.log" ] || {
    printf 'taf user error leaked to stdout:\n' >&2
    sed 's/^/  /' "$dir/stdout.log" >&2
    return 1
  }
  stderr=$(cat "$dir/stderr.log")
  assert_contains "$stderr" "[TAF-ERROR]" \
    "taf user error is written to stderr" || return 1

  pids=
  for worker in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 \
                17 18 19 20 21 22 23 24
  do
    env TAFFISH_USER_HOME="$user_home" "$TAF_BIN" history --record-exec \
      --status success --command "taf-history-$worker" --exit-code 0 \
      -- "$worker" >"$dir/record-$worker.out" 2>"$dir/record-$worker.err" &
    pids="$pids $!"
  done
  failed=0
  for pid in $pids
  do
    wait "$pid" || failed=1
  done
  [ "$failed" -eq 0 ] || harness_fail "one or more history record workers failed"

  python3 - "$user_home/logs/history.jsonl" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    lines = [line.rstrip("\n") for line in handle if line.strip()]
assert len(lines) == 24, (len(lines), lines)
records = [json.loads(line) for line in lines]
ids = [record.get("id") for record in records]
commands = [record.get("command") for record in records]
assert all(ids), ids
assert len(set(ids)) == len(ids), ids
assert set(commands) == {f"taf-history-{worker}" for worker in range(1, 25)}, commands
PY
}

_taf_system_case_mcp_unicode_compile() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-system-mcp-unicode
  mkdir -p "$dir/user-home" "$dir/system-home"

  python3 - <<'PY' |
import json

requests = [
    {
        "jsonrpc": "2.0",
        "id": 201,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "unicode-conformance", "version": "0"},
        },
    },
    {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}},
    {
        "jsonrpc": "2.0",
        "id": 202,
        "method": "tools/call",
        "params": {
            "name": "taffish_compile_source",
            "arguments": {"source": "<shell>\nprintf '%s\\n' '你好，MCP'"},
        },
    },
]
for request in requests:
    print(json.dumps(request, ensure_ascii=False, separators=(",", ":")))
PY
    env LC_ALL="$TAFFISH_TEST_UTF8_LOCALE" LANG="$TAFFISH_TEST_UTF8_LOCALE" \
      TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$dir/user-home" TAFFISH_SYSTEM_HOME="$dir/system-home" \
      "$TAFFISH_MCP_BIN" >"$dir/responses.jsonl" 2>"$dir/stderr.log" || {
        printf 'MCP Unicode compile session failed\n' >&2
        sed 's/^/  /' "$dir/stderr.log" >&2
        return 1
      }

  python3 - "$dir/responses.jsonl" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    responses = [json.loads(line) for line in handle if line.strip()]
by_id = {response.get("id"): response for response in responses}
assert set(by_id) == {201, 202}, responses
result = by_id[202]["result"]
assert result.get("isError") in {False, None}, result
structured = result["structuredContent"]
assert structured.get("ok") is True, structured
assert "你好，MCP" in structured.get("shell", ""), structured
PY
}

run_taf_system_conformance() {
  run_case "taf-system/doctor-read-only-and-output" \
    _taf_system_case_doctor_read_only_and_output
  run_case "taf-system/doctor-init-completion-vim" \
    _taf_system_case_doctor_init_completion_and_vim
  run_case "taf-system/doctor-sif-and-backend-policies" \
    _taf_system_case_doctor_sif_and_backend_policies
  run_case "taf-system/mcp-environment-read-only" \
    _taf_system_case_mcp_environment_is_read_only
  run_case "taf-system/mcp-long-stdio-session" \
    _taf_system_case_mcp_long_stdio_session
  run_case "taf-system/error-stream-and-history-identity" \
    _taf_system_case_error_stream_and_history_identity
  run_case "taf-system/mcp-unicode-compile" \
    _taf_system_case_mcp_unicode_compile
  run_case "taf-system/display-layout" \
    python3 "$TAFFISH_TEST_REPO_ROOT/test/taf-system/display.py" layout
  run_case "taf-system/display-progress-streams" \
    python3 "$TAFFISH_TEST_REPO_ROOT/test/taf-system/display.py" progress
  run_case "taf-system/command-progress-update" \
    python3 "$TAFFISH_TEST_REPO_ROOT/test/taf-system/command-progress.py" update
  run_case "taf-system/command-progress-hub" \
    python3 "$TAFFISH_TEST_REPO_ROOT/test/taf-system/command-progress.py" hub
}
