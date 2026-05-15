# External conformance tests for the taffish binary.
# This file is sourced by test/run-tests.sh.

_taffish_final_run_args() {
  printf '%s\n' "$1" | sed -n 's/^# FINAL RUN ARGS: //p' | head -n 1
}

_taffish_case_file_args_and_defaults() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-file-args
  mkdir -p "$dir"
  file=$dir/main.taf
  cat > "$file" <<'TAF'
ARGS
<(--/-n)name>
  world
<(--/-c)count>
  1
RUN
<shell>
printf '%s:%s\n' "::name::" "::count::"
TAF

  shell=$($TAFFISH_BIN "$file") || return 1
  output=$(printf '%s\n' "$shell" | sh) || return 1
  assert_eq "world:1" "$output" "default args output" || return 1

  shell=$($TAFFISH_BIN "$file" --name codex --count 3) || return 1
  output=$(printf '%s\n' "$shell" | sh) || return 1
  assert_eq "codex:3" "$output" "explicit args output" || return 1
}

_taffish_case_stdin_args() {
  code='ARGS
<!(--/-n)name>
RUN
<shell>
printf '\''stdin:%s\n'\'' "::name::"'
  shell=$(printf '%s\n' "$code" | "$TAFFISH_BIN" -- --name stream) || return 1
  output=$(printf '%s\n' "$shell" | sh) || return 1
  assert_eq "stdin:stream" "$output" "stdin source output" || return 1
}

_taffish_case_required_arg_error() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-required
  mkdir -p "$dir"
  file=$dir/required.taf
  cat > "$file" <<'TAF'
ARGS
<!(--/-i)input>
RUN
<shell>
cat "::input::"
TAF

  set +e
  output=$($TAFFISH_BIN "$file" 2>&1)
  status=$?
  set -e
  [ "$status" -ne 0 ] || harness_fail "required arg compile unexpectedly succeeded"
  assert_contains "$output" "input" "required arg error names input" || return 1
}

_taffish_case_block_query_default() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-block-query
  mkdir -p "$dir"
  file=$dir/block-query.taf
  cat > "$file" <<'TAF'
ARGS
<(--/-n)name>
  Ada
<message>
  hello, @name
RUN
<shell>
printf '%s\n' "::message::"
TAF

  shell=$($TAFFISH_BIN "$file") || return 1
  output=$(printf '%s\n' "$shell" | sh) || return 1
  assert_eq "hello, Ada" "$output" "block arg query default" || return 1

  shell=$($TAFFISH_BIN "$file" --name Grace) || return 1
  output=$(printf '%s\n' "$shell" | sh) || return 1
  assert_eq "hello, Grace" "$output" "block arg query override" || return 1
}

_taffish_case_legacy_container_args_compile() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-container-legacy
  mkdir -p "$dir"
  file=$dir/container-legacy.taf
  cat > "$file" <<'TAF'
<docker:alpine:latest$--pull=never --network host>
echo legacy
TAF

  shell=$($TAFFISH_BIN "$file") || return 1
  assert_contains "$shell" "--pull=never --network host" "legacy container args" || return 1
  assert_contains "$shell" "docker run" "legacy explicit docker backend" || return 1
}

_taffish_case_structured_container_args_docker_compile() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-container-structured-docker
  mkdir -p "$dir"
  file=$dir/container-structured-docker.taf
  cat > "$file" <<'TAF'
<docker:alpine:latest$@[all: --pull=never][docker: --gpus all][podman: --device nvidia.com/gpu=all][apptainer: --nv]>
echo docker structured
TAF

  shell=$($TAFFISH_BIN "$file") || return 1
  final_args=$(_taffish_final_run_args "$shell")
  assert_contains "$final_args" "--pull=never" "structured all args for docker" || return 1
  assert_contains "$final_args" "--gpus all" "structured docker args" || return 1
  assert_not_contains "$final_args" "--device nvidia.com/gpu=all" "podman args excluded from docker" || return 1
  assert_not_contains "$final_args" " --nv" "apptainer args excluded from docker" || return 1
}

_taffish_case_structured_container_args_combo_compile() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-container-structured-combo
  mkdir -p "$dir"
  file=$dir/container-structured-combo.taf
  cat > "$file" <<'TAF'
<podman:alpine:latest$@[container: --network host][docker/podman: --security-opt=label=disable][apptainer: --nv]>
echo combo structured
TAF

  shell=$($TAFFISH_BIN "$file") || return 1
  final_args=$(_taffish_final_run_args "$shell")
  assert_contains "$final_args" "--network host" "structured container alias args" || return 1
  assert_contains "$final_args" "--security-opt=label=disable" "structured docker/podman combo args" || return 1
  assert_not_contains "$final_args" " --nv" "apptainer args excluded from podman" || return 1
}

_taffish_case_structured_container_args_escape_compile() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-container-structured-escape
  mkdir -p "$dir"
  file=$dir/container-structured-escape.taf
  cat > "$file" <<'TAF'
<docker:alpine:latest$@[docker: --label note=a\]b]>
echo escaped bracket
TAF

  shell=$($TAFFISH_BIN "$file") || return 1
  assert_contains "$shell" "--label note=a]b" "escaped right bracket in structured args" || return 1
}

_taffish_case_container_env_run_args_compile() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-container-env
  mkdir -p "$dir"
  file=$dir/container-env.taf
  cat > "$file" <<'TAF'
<docker:alpine:latest$@[docker: --pull=never]>
echo env args
TAF

  shell=$(TAFFISH_DOCKER_RUN_ARGS="--env TAFFISH_EXTERNAL_TEST=1" "$TAFFISH_BIN" "$file") || return 1
  assert_contains "$shell" "--pull=never" "structured args with env" || return 1
  assert_contains "$shell" "--env TAFFISH_EXTERNAL_TEST=1" "env container run args" || return 1
}

_taffish_case_structured_generic_backend_selection() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-container-generic-selection
  mkdir -p "$dir"
  shim_dir=$dir/bin
  mkdir -p "$shim_dir"
  for backend in docker podman apptainer; do
    cat > "$shim_dir/$backend" <<'SH'
#!/bin/sh
exit 0
SH
    chmod +x "$shim_dir/$backend"
  done

  file=$dir/container-generic-selection.taf
  cat > "$file" <<'TAF'
<container:alpine:latest$@[all: --pull=never][docker: --gpus all][podman: --device nvidia.com/gpu=all][apptainer: --nv]>
echo generic structured
TAF

  docker_shell=$(PATH="$shim_dir:$PATH" TAFFISH_CONTAINER_BACKEND=docker "$TAFFISH_BIN" "$file") || return 1
  docker_args=$(_taffish_final_run_args "$docker_shell")
  assert_contains "$docker_args" "--pull=never" "generic docker gets all args" || return 1
  assert_contains "$docker_args" "--gpus all" "generic docker gets docker args" || return 1
  assert_not_contains "$docker_args" "--device nvidia.com/gpu=all" "generic docker excludes podman args" || return 1
  assert_not_contains "$docker_args" " --nv" "generic docker excludes apptainer args" || return 1

  podman_shell=$(PATH="$shim_dir:$PATH" TAFFISH_CONTAINER_BACKEND=podman "$TAFFISH_BIN" "$file") || return 1
  podman_args=$(_taffish_final_run_args "$podman_shell")
  assert_contains "$podman_args" "--pull=never" "generic podman gets all args" || return 1
  assert_contains "$podman_args" "--device nvidia.com/gpu=all" "generic podman gets podman args" || return 1
  assert_not_contains "$podman_args" "--gpus all" "generic podman excludes docker args" || return 1
  assert_not_contains "$podman_args" " --nv" "generic podman excludes apptainer args" || return 1

  apptainer_shell=$(PATH="$shim_dir:$PATH" TAFFISH_CONTAINER_BACKEND=apptainer "$TAFFISH_BIN" "$file") || return 1
  apptainer_args=$(_taffish_final_run_args "$apptainer_shell")
  assert_contains "$apptainer_args" "--pull=never" "generic apptainer gets all args" || return 1
  assert_contains "$apptainer_args" " --nv" "generic apptainer gets apptainer args" || return 1
  assert_not_contains "$apptainer_args" "--gpus all" "generic apptainer excludes docker args" || return 1
  assert_not_contains "$apptainer_args" "--device nvidia.com/gpu=all" "generic apptainer excludes podman args" || return 1
}

_taffish_case_invalid_structured_container_args_error() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-container-invalid
  mkdir -p "$dir"
  file=$dir/container-invalid.taf
  cat > "$file" <<'TAF'
<docker:alpine:latest$@[gpu: --magic]>
echo invalid
TAF

  set +e
  output=$($TAFFISH_BIN "$file" 2>&1)
  status=$?
  set -e
  [ "$status" -ne 0 ] || harness_fail "invalid structured args unexpectedly compiled"
  assert_contains "$output" "gpu" "invalid structured target error" || return 1
}

run_taffish_conformance() {
  run_case "taffish/file-args-and-defaults" _taffish_case_file_args_and_defaults
  run_case "taffish/stdin-args" _taffish_case_stdin_args
  run_case "taffish/required-arg-error" _taffish_case_required_arg_error
  run_case "taffish/block-query-default" _taffish_case_block_query_default
  run_case "taffish/container-legacy-args-compile" _taffish_case_legacy_container_args_compile
  run_case "taffish/container-structured-docker-compile" _taffish_case_structured_container_args_docker_compile
  run_case "taffish/container-structured-combo-compile" _taffish_case_structured_container_args_combo_compile
  run_case "taffish/container-structured-escape-compile" _taffish_case_structured_container_args_escape_compile
  run_case "taffish/container-env-run-args-compile" _taffish_case_container_env_run_args_compile
  run_case "taffish/container-structured-generic-backend-selection" _taffish_case_structured_generic_backend_selection
  run_case "taffish/container-invalid-structured-args-error" _taffish_case_invalid_structured_container_args_error
}
