# Make backends discoverable for one compiler invocation. The generated shell
# is inspected by the caller, so executing a backend is a test failure.
compile_with_test_backends() (
  fixture_dir=$(mktemp -d "$1/compile-backends.XXXXXX") || exit 1
  shift
  for backend in docker podman apptainer; do
    cat > "$fixture_dir/$backend" <<'SH' || exit 1
#!/bin/sh
printf 'Compile-only test unexpectedly invoked %s\n' "${0##*/}" >> "${0%/*}/invoked"
exit 1
SH
    chmod +x "$fixture_dir/$backend" || exit 1
  done

  status=0
  PATH="$fixture_dir:$PATH" "$@" || status=$?
  if [ -f "$fixture_dir/invoked" ]; then
    cat "$fixture_dir/invoked" >&2
    exit 1
  fi
  exit "$status"
)
