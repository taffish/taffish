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

_taffish_case_minimal_and_auto_run() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-minimal-auto-run
  mkdir -p "$dir"

  plain_file=$dir/plain.taf
  cat > "$plain_file" <<'TAF'
echo plain-auto-run
TAF
  shell=$($TAFFISH_BIN "$plain_file") || return 1
  output=$(printf '%s\n' "$shell" | sh) || return 1
  assert_eq "plain-auto-run" "$output" "plain code auto RUN/<taffish>" || return 1

  shell_file=$dir/shell.taf
  cat > "$shell_file" <<'TAF'
<shell>
echo shell-auto-run
TAF
  shell=$($TAFFISH_BIN "$shell_file") || return 1
  output=$(printf '%s\n' "$shell" | sh) || return 1
  assert_eq "shell-auto-run" "$output" "subtag auto RUN" || return 1
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

_taffish_case_parameter_dsl_refs_and_escapes() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-parameter-dsl
  mkdir -p "$dir"
  file=$dir/parameter-dsl.taf
  cat > "$file" <<'TAF'
ARGS
<sample>
  demo
<prefix>
  out-@{sample}
<message>
  hello, ::sample::
<escaped-default>
  \@\{\}\\
RUN
<shell>
printf '%s\n' "prefix=::prefix::"
printf '%s\n' "message=::message::"
printf '%s\n' "escaped=[::escaped-default::]"
printf '%s\n' "verbose=::(--/-v)verbose?::"
printf '%s\n' "pos=::$1::->::$2::"
printf '%s\n' '\: \< \# \\ \@'
TAF

  shell=$($TAFFISH_BIN "$file" input.fa output.txt --verbose) || return 1
  output=$(printf '%s\n' "$shell" | sh) || return 1
  expected=$(cat <<'OUT'
prefix=out-demo
message=hello, demo
escaped=[@{}\]
verbose=T
pos=input.fa->output.txt
: < # \ \@
OUT
)
  assert_eq "$expected" "$output" "parameter DSL refs and escapes" || return 1
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

_taffish_case_slot_block_args_compile_and_run() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-slot-block-args
  mkdir -p "$dir"
  file=$dir/slot-block-args.taf
  cat > "$file" <<'TAF'
ARGS
<(@:)only-step>
RUN
<shell>
printf '<%s>\n' ::(@:)only-step::
TAF

  shell=$($TAFFISH_BIN "$file" @only-step: --xxx 123 "hello world") || return 1
  assert_not_contains "$shell" "ARG-TOKEN" "slot block args must not leak arg-token structs" || return 1
  assert_contains "$shell" "'hello world'" "slot block args quote spaces" || return 1

  output=$(printf '%s\n' "$shell" | sh) || return 1
  expected=$(cat <<'OUT'
<--xxx>
<123>
<hello world>
OUT
)
  assert_eq "$expected" "$output" "slot block args output" || return 1
}

_taffish_case_builtins_compile_and_run() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-builtins
  mkdir -p "$dir"
  file=$dir/builtins.taf
  cat > "$file" <<'TAF'
<shell>
printf '%s\n' "cmd=::*CMD*::"
printf '%s\n' "argv=::*ARGV*::"
printf '%s\n' "workdir=::*WORKDIR*::"
printf '%s\n' "loaddir=::*LOADDIR*::"
printf '%s\n' "cpus=::*CPUS*::"
TAF

  workdir=$dir/work
  mkdir -p "$workdir"
  workdir_real=$(cd "$workdir" && pwd -P) || return 1
  loaddir_real=$(cd "$dir" && pwd -P) || return 1
  shell=$(cd "$workdir" && "$TAFFISH_BIN" "$file" alpha beta) || return 1
  output=$(cd "$workdir" && printf '%s\n' "$shell" | sh) || return 1
  assert_contains "$output" "cmd=$TAFFISH_BIN" "builtin CMD" || return 1
  assert_contains "$output" "argv=alpha beta" "builtin ARGV" || return 1
  assert_contains "$output" "workdir=$workdir_real" "builtin WORKDIR" || return 1
  assert_contains "$output" "loaddir=$loaddir_real" "builtin LOADDIR" || return 1
  assert_contains "$output" "cpus=" "builtin CPUS present" || return 1
}

_taffish_case_taf_app_shell_arg_and_command_modes() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-taf-app-shell
  mkdir -p "$dir"
  file=$dir/taf-app-shell.taf
  cat > "$file" <<'TAF'
<taf-app:shell>
printf '<%s>\n' default ::*ARGV*::
TAF

  shell=$($TAFFISH_BIN "$file" --alpha 1) || return 1
  output=$(printf '%s\n' "$shell" | sh) || return 1
  expected=$(cat <<'OUT'
<default>
<--alpha>
<1>
OUT
)
  assert_eq "$expected" "$output" "taf-app shell arg mode" || return 1

  shell=$($TAFFISH_BIN "$file" echo command-mode) || return 1
  output=$(printf '%s\n' "$shell" | sh) || return 1
  assert_eq "command-mode" "$output" "taf-app shell command mode" || return 1
}

_taffish_case_taffish_embed_taf_app() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-embed-taf-app
  mkdir -p "$dir/bin"
  cat > "$dir/bin/taf-step-v0.1.0-r1" <<'SH'
#!/bin/sh
if [ "$1" = "--compile" ]; then
  shift
  printf '%s\n' '#!/bin/sh'
  printf 'printf '"'"'embedded:%s\\n'"'"' %s\n' "$*"
else
  exit 2
fi
SH
  chmod +x "$dir/bin/taf-step-v0.1.0-r1"

  file=$dir/flow.taf
  cat > "$file" <<'TAF'
<taffish>
echo before
[[taf: taf-step-v0.1.0-r1 alpha beta]]
echo \[[taf: taf-step-v0.1.0-r1 literal]]
TAF

  shell=$(PATH="$dir/bin:$PATH" "$TAFFISH_BIN" "$file") || return 1
  assert_contains "$shell" "taf-step-v0.1.0-r1 --compile alpha beta" "embedded taf-app compile call" || return 1
  output=$(PATH="$dir/bin:$PATH" sh -c "$shell") || return 1
  expected=$(cat <<'OUT'
before
embedded:alpha beta
[[taf: taf-step-v0.1.0-r1 literal]]
OUT
)
  assert_eq "$expected" "$output" "taffish embedded taf-app output" || return 1
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

_taffish_case_syntax_errors() {
  dir=$TAFFISH_TEST_TMP_ROOT/taffish-syntax-errors
  mkdir -p "$dir"

  unclosed_arg=$dir/unclosed-arg.taf
  cat > "$unclosed_arg" <<'TAF'
<shell>
echo ::name
TAF
  set +e
  output=$($TAFFISH_BIN "$unclosed_arg" 2>&1)
  status=$?
  set -e
  [ "$status" -ne 0 ] || harness_fail "unclosed arg unexpectedly compiled"
  assert_contains "$output" "TAFFISH-ERROR" "unclosed arg error prefix" || return 1

  unclosed_taf=$dir/unclosed-taf.taf
  cat > "$unclosed_taf" <<'TAF'
<taffish>
[[taf: taf-demo-v0.1.0-r1 alpha
TAF
  set +e
  output=$($TAFFISH_BIN "$unclosed_taf" 2>&1)
  status=$?
  set -e
  [ "$status" -ne 0 ] || harness_fail "unclosed embedded taf unexpectedly compiled"
  assert_contains "$output" "Missing right match" "unclosed embedded taf error" || return 1
}

run_taffish_conformance() {
  run_case "taffish/file-args-and-defaults" _taffish_case_file_args_and_defaults
  run_case "taffish/stdin-args" _taffish_case_stdin_args
  run_case "taffish/minimal-and-auto-run" _taffish_case_minimal_and_auto_run
  run_case "taffish/required-arg-error" _taffish_case_required_arg_error
  run_case "taffish/parameter-dsl-refs-and-escapes" _taffish_case_parameter_dsl_refs_and_escapes
  run_case "taffish/block-query-default" _taffish_case_block_query_default
  run_case "taffish/slot-block-args-compile-and-run" _taffish_case_slot_block_args_compile_and_run
  run_case "taffish/builtins-compile-and-run" _taffish_case_builtins_compile_and_run
  run_case "taffish/taf-app-shell-arg-and-command-modes" _taffish_case_taf_app_shell_arg_and_command_modes
  run_case "taffish/taffish-embed-taf-app" _taffish_case_taffish_embed_taf_app
  run_case "taffish/container-legacy-args-compile" _taffish_case_legacy_container_args_compile
  run_case "taffish/container-structured-docker-compile" _taffish_case_structured_container_args_docker_compile
  run_case "taffish/container-structured-combo-compile" _taffish_case_structured_container_args_combo_compile
  run_case "taffish/container-structured-escape-compile" _taffish_case_structured_container_args_escape_compile
  run_case "taffish/container-env-run-args-compile" _taffish_case_container_env_run_args_compile
  run_case "taffish/container-structured-generic-backend-selection" _taffish_case_structured_generic_backend_selection
  run_case "taffish/container-invalid-structured-args-error" _taffish_case_invalid_structured_container_args_error
  run_case "taffish/syntax-errors" _taffish_case_syntax_errors
}
