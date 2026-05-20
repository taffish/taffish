# External conformance tests for real taf Hub/package maintenance workflows.
# This file is sourced by test/run-tests.sh.

_taf_hub_json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

_taf_hub_write_index() {
  index_path=$1
  multi_r1=$(_taf_hub_json_escape "$2")
  multi_r2=$(_taf_hub_json_escape "$3")
  flow_src=$(_taf_hub_json_escape "$4")
  mkdir -p "$(dirname "$index_path")"
  cat > "$index_path" <<EOF_INDEX
{
  "schema_version": "taffish.index/v1",
  "generated_at": "2026-05-20T00:00:00Z",
  "packages": {
    "multi-demo": {
      "name": "multi-demo",
      "latest": "0.1.0-r2",
      "repository_url": "https://github.com/taffish/multi-demo",
      "command": {"name": "taf-multi-demo"},
      "versions": {
        "0.1.0-r1": {
          "name": "multi-demo",
          "kind": "tool",
          "version": "0.1.0",
          "release": 1,
          "version_id": "0.1.0-r1",
          "tag": "v0.1.0-r1",
          "license": "Apache-2.0",
          "repository_url": "https://github.com/taffish/multi-demo",
          "repository_slug": "taffish/multi-demo",
          "command": {"name": "taf-multi-demo"},
          "runtime": {"pipe": true, "command_mode": true},
          "paths": {"main": "src/main.taf", "help": "docs/help.md"},
          "container": null,
          "source": {"repository": "taffish/multi-demo", "ref": "v0.1.0-r1", "local_path": "$multi_r1"}
        },
        "0.1.0-r2": {
          "name": "multi-demo",
          "kind": "tool",
          "version": "0.1.0",
          "release": 2,
          "version_id": "0.1.0-r2",
          "tag": "v0.1.0-r2",
          "license": "Apache-2.0",
          "repository_url": "https://github.com/taffish/multi-demo",
          "repository_slug": "taffish/multi-demo",
          "command": {"name": "taf-multi-demo"},
          "runtime": {"pipe": true, "command_mode": true},
          "paths": {"main": "src/main.taf", "help": "docs/help.md"},
          "container": null,
          "source": {"repository": "taffish/multi-demo", "ref": "v0.1.0-r2", "local_path": "$multi_r2"}
        }
      }
    },
    "batch-flow": {
      "name": "batch-flow",
      "latest": "1.0.0-r1",
      "repository_url": "https://github.com/taffish/batch-flow",
      "command": {"name": "taf-batch-flow"},
      "versions": {
        "1.0.0-r1": {
          "name": "batch-flow",
          "kind": "flow",
          "version": "1.0.0",
          "release": 1,
          "version_id": "1.0.0-r1",
          "tag": "v1.0.0-r1",
          "license": "Apache-2.0",
          "repository_url": "https://github.com/taffish/batch-flow",
          "repository_slug": "taffish/batch-flow",
          "command": {"name": "taf-batch-flow"},
          "runtime": {"pipe": false, "command_mode": true},
          "paths": {"main": "src/main.taf", "help": "docs/help.md"},
          "container": null,
          "source": {"repository": "taffish/batch-flow", "ref": "v1.0.0-r1", "local_path": "$flow_src"}
        }
      }
    }
  },
  "commands": {
    "taf-multi-demo": {"package": "multi-demo", "version": "0.1.0-r2"},
    "taf-batch-flow": {"package": "batch-flow", "version": "1.0.0-r1"}
  }
}
EOF_INDEX
}

_taf_hub_prepare_project() {
  parent=$1
  name=$2
  kind_flag=$3
  version=$4
  release=$5
  message=$6

  mkdir -p "$parent"
  (
    cd "$parent" || exit 1
    "$TAF_BIN" new "$name" "$kind_flag" --version "$version" --release "$release" >/dev/null || exit 1
    cd "$name" || exit 1
    cat > src/main.taf <<EOF_TAF
<taffish>
echo '$message'
EOF_TAF
  )
}

_taf_hub_prepare_index_fixture() {
  fixture_root=$1
  src_root=$fixture_root/source
  index_path=$TAFFISH_USER_HOME/index/current.json

  _taf_hub_prepare_project "$src_root/r1" multi-demo --tool 0.1.0 1 "multi r1"
  _taf_hub_prepare_project "$src_root/r2" multi-demo --tool 0.1.0 2 "multi r2"
  _taf_hub_prepare_project "$src_root/flow" batch-flow --flow 1.0.0 1 "batch flow"

  _taf_hub_write_index \
    "$index_path" \
    "$src_root/r1/multi-demo" \
    "$src_root/r2/multi-demo" \
    "$src_root/flow/batch-flow"
}

_taf_hub_case_install_all_filters_kind() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-hub-install-all
  (
  export TAFFISH_USER_HOME=$dir/user-home
  export TAFFISH_SYSTEM_HOME=$dir/system-home
  export PATH=$TAFFISH_USER_HOME/bin:$PATH
  mkdir -p "$TAFFISH_USER_HOME" "$TAFFISH_SYSTEM_HOME"
  _taf_hub_prepare_index_fixture "$dir" || exit 1

  dry_run=$($TAF_BIN install --all --flows --json) || return 1
  assert_contains "$dry_run" '"operation": "install_all"' "install-all json operation" || exit 1
  assert_contains "$dry_run" '"package_name": "batch-flow"' "install-all flow plan includes flow" || exit 1
  assert_not_contains "$dry_run" '"package_name": "multi-demo"' "install-all flow plan excludes tool" || exit 1

  $TAF_BIN install --all --flows --yes >/dev/null || exit 1
  list_output=$($TAF_BIN list) || exit 1
  assert_contains "$list_output" "batch-flow" "install-all flow installs flow" || exit 1
  assert_not_contains "$list_output" "multi-demo" "install-all flow does not install tool" || exit 1
  )
}

_taf_hub_case_outdated_upgrade_and_prune() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-hub-upgrade
  (
  export TAFFISH_USER_HOME=$dir/user-home
  export TAFFISH_SYSTEM_HOME=$dir/system-home
  export PATH=$TAFFISH_USER_HOME/bin:$PATH
  mkdir -p "$TAFFISH_USER_HOME" "$TAFFISH_SYSTEM_HOME"
  _taf_hub_prepare_index_fixture "$dir" || exit 1

  $TAF_BIN install taf-multi-demo-v0.1.0-r1 >/dev/null || exit 1
  outdated=$($TAF_BIN outdated --json) || exit 1
  assert_contains "$outdated" '"operation": "outdated"' "outdated json operation" || exit 1
  assert_contains "$outdated" '"package_name": "multi-demo"' "outdated finds package" || exit 1
  assert_contains "$outdated" '"installed_version_id": "0.1.0-r1"' "outdated installed version" || exit 1
  assert_contains "$outdated" '"latest_version_id": "0.1.0-r2"' "outdated latest version" || exit 1
  assert_contains "$outdated" '"status": "outdated"' "outdated status" || exit 1

  plan=$($TAF_BIN upgrade taf-multi-demo --json) || exit 1
  assert_contains "$plan" '"dry_run": true' "upgrade defaults to dry-run" || exit 1
  assert_contains "$plan" '"action": "install_latest"' "upgrade plans install latest" || exit 1

  $TAF_BIN upgrade taf-multi-demo --yes --prune-old >/dev/null || exit 1
  list_json=$($TAF_BIN list --json) || exit 1
  assert_contains "$list_json" '"version_id": "0.1.0-r2"' "upgrade installs r2" || exit 1
  assert_not_contains "$list_json" '"version_id": "0.1.0-r1"' "upgrade prune-old removes r1" || exit 1

  run_output=$(taf-multi-demo) || exit 1
  assert_eq "multi r2" "$run_output" "unversioned alias runs latest installed version" || exit 1
  )
}

_taf_hub_case_prune_keeps_newest() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-hub-prune
  (
  export TAFFISH_USER_HOME=$dir/user-home
  export TAFFISH_SYSTEM_HOME=$dir/system-home
  export PATH=$TAFFISH_USER_HOME/bin:$PATH
  mkdir -p "$TAFFISH_USER_HOME" "$TAFFISH_SYSTEM_HOME"
  _taf_hub_prepare_index_fixture "$dir" || exit 1

  $TAF_BIN install taf-multi-demo-v0.1.0-r1 taf-multi-demo-v0.1.0-r2 >/dev/null || exit 1
  prune_plan=$($TAF_BIN prune --json) || exit 1
  assert_contains "$prune_plan" '"operation": "prune"' "prune json operation" || exit 1
  assert_contains "$prune_plan" '"action": "remove_old"' "prune plans removing old versions" || exit 1
  assert_contains "$prune_plan" '"remove_versions"' "prune exposes remove_versions" || exit 1
  assert_contains "$prune_plan" '"0.1.0-r1"' "prune identifies r1" || exit 1

  $TAF_BIN prune --yes >/dev/null || exit 1
  list_json=$($TAF_BIN list --json) || exit 1
  assert_contains "$list_json" '"version_id": "0.1.0-r2"' "prune keeps r2" || exit 1
  assert_not_contains "$list_json" '"version_id": "0.1.0-r1"' "prune removes r1" || exit 1
  )
}

_taf_hub_case_text_hides_current_items() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-hub-text-output
  (
  export TAFFISH_USER_HOME=$dir/user-home
  export TAFFISH_SYSTEM_HOME=$dir/system-home
  export PATH=$TAFFISH_USER_HOME/bin:$PATH
  mkdir -p "$TAFFISH_USER_HOME" "$TAFFISH_SYSTEM_HOME"
  _taf_hub_prepare_index_fixture "$dir" || exit 1

  $TAF_BIN install taf-multi-demo-v0.1.0-r2 >/dev/null || exit 1

  outdated_output=$($TAF_BIN outdated) || exit 1
  assert_contains "$outdated_output" "no changes" "outdated hides current app details" || exit 1
  assert_not_contains "$outdated_output" "multi-demo" "outdated does not list current app" || exit 1

  install_all_output=$($TAF_BIN install --all --tools) || exit 1
  assert_contains "$install_all_output" "no changes" "install-all hides already installed tool details" || exit 1
  assert_not_contains "$install_all_output" "multi-demo" "install-all does not list current tool" || exit 1

  upgrade_output=$($TAF_BIN upgrade) || exit 1
  assert_contains "$upgrade_output" "no changes" "upgrade hides current app details" || exit 1
  assert_not_contains "$upgrade_output" "multi-demo" "upgrade does not list current app" || exit 1
  )
}

run_taf_hub_conformance() {
  run_case "taf-hub/install-all-filters-kind" _taf_hub_case_install_all_filters_kind
  run_case "taf-hub/outdated-upgrade-prune-old" _taf_hub_case_outdated_upgrade_and_prune
  run_case "taf-hub/prune-keeps-newest" _taf_hub_case_prune_keeps_newest
  run_case "taf-hub/text-hides-current-items" _taf_hub_case_text_hides_current_items
}
