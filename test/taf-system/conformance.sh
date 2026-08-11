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
    assert_not_contains "$output" "evidence    :" "doctor concise output hides evidence" || exit 1
    [ ! -e "$TAFFISH_USER_HOME" ] || {
      printf 'read-only doctor unexpectedly created user home\n' >&2
      exit 1
    }
    assert_eq '# unchanged bashrc' "$(cat "$HOME/.bashrc")" \
      "doctor keeps bashrc" || exit 1
    assert_eq '" unchanged vimrc' "$(cat "$HOME/.vimrc")" \
      "doctor keeps vimrc" || exit 1

    verbose=$($TAF_BIN doctor --user --shell bash --verbose) || exit 1
    assert_contains "$verbose" "evidence    :" "doctor verbose evidence" || exit 1
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

run_taf_system_conformance() {
  run_case "taf-system/doctor-read-only-and-output" \
    _taf_system_case_doctor_read_only_and_output
  run_case "taf-system/doctor-init-completion-vim" \
    _taf_system_case_doctor_init_completion_and_vim
  run_case "taf-system/doctor-sif-and-backend-policies" \
    _taf_system_case_doctor_sif_and_backend_policies
  run_case "taf-system/mcp-environment-read-only" \
    _taf_system_case_mcp_environment_is_read_only
}
