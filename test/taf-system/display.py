#!/usr/bin/env python3
"""Offline display/stream contracts against real CLI candidates, not benchmarks."""
import errno
import fcntl
import json
import os
from pathlib import Path
import pty
import re
import runpy
import select
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time


TIMEOUT = float(os.environ.get("TAFFISH_TEST_DISPLAY_TIMEOUT", "180"))
APP_COUNT = 300
ERASE = b"\r\x1b[K"
COMPLETE = b"[TAF] Local installation checks complete."
PROGRESS = (b"[TAF] Scanning local installation records...",
            b"[TAF] Checking local installations:",
            b"[TAF] Checking command shortcuts...", COMPLETE,
            b"[TAF] Local installation checks stopped.")
LABELS = {
    "en": ("scope", "user home", "system home"),
    "zh": ("\u4f5c\u7528\u57df", "\u7528\u6237\u76ee\u5f55", "\u7cfb\u7edf\u76ee\u5f55"),
}


def environment(user_home, system_home, language="en"):
    env = dict(os.environ, TAFFISH_USER_HOME=str(user_home),
               TAFFISH_SYSTEM_HOME=str(system_home), TAFFISH_CONFIG="",
               TAFFISH_LANGUAGE=language, TERM="xterm-256color")
    # Work identically under the harness's C locale and UTF-8 shells.
    env["LC_ALL"] = env["LANG"] = os.environ.get("TAFFISH_TEST_UTF8_LOCALE", "C")
    return env


def capture(command, env, logs, name, *, terminal=False, closed=False,
            request=None, code=0):
    """Keep stdout separate; preserve PTY CR/ANSI bytes rather than universal newlines."""
    assert not (terminal and closed)
    logs.mkdir(parents=True, exist_ok=True)
    stdout_path = logs / (name + ".stdout")
    stderr_path = logs / (name + ".stderr")
    if closed:
        command = ["/bin/sh", "-c", 'exec 2>&-; exec "$@"', "display-test", *command]
    master = slave = None
    process = None
    errors = bytearray()
    start = time.monotonic()
    try:
        if terminal:
            master, slave = pty.openpty()
            attributes = termios.tcgetattr(slave)
            attributes[1] &= ~termios.OPOST
            termios.tcsetattr(slave, termios.TCSANOW, attributes)
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        with stdout_path.open("wb") as output:
            process = subprocess.Popen(
                command, env=env, stdout=output,
                stdin=subprocess.PIPE if request is not None else subprocess.DEVNULL,
                stderr=slave if terminal else subprocess.PIPE, start_new_session=True)
            if slave is not None:
                os.close(slave)
                slave = None
            if terminal:
                if request is not None:
                    process.stdin.write(request)
                    process.stdin.close()
                while True:
                    remaining = TIMEOUT - (time.monotonic() - start)
                    if remaining <= 0:
                        raise subprocess.TimeoutExpired(command, TIMEOUT)
                    ready, _, _ = select.select([master], [], [], min(0.2, remaining))
                    if ready:
                        try:
                            chunk = os.read(master, 65536)
                        except OSError as error:
                            if error.errno != errno.EIO:
                                raise
                            chunk = b""  # Linux PTY end-of-file.
                        if not chunk:
                            break
                        errors.extend(chunk)
                process.wait(timeout=max(0.01, TIMEOUT - (time.monotonic() - start)))
            else:
                _, stderr = process.communicate(request, timeout=TIMEOUT)
                errors.extend(stderr)
        assert process.returncode == code, (name, process.returncode, code,
                                             str(stdout_path), bytes(errors[-4000:]))
    finally:
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        for descriptor in (slave, master):
            if descriptor is not None:
                os.close(descriptor)
        stderr_path.write_bytes(errors)
    print(f"[display] {name}: exit={code}, elapsed={time.monotonic() - start:.3f}s")
    return stdout_path.read_bytes(), bytes(errors)


def fixture_columns(text):
    """Independent oracle ONLY for ASCII, the fixed fixture Han chars and U+0301."""
    width = 0
    for char in text:
        if " " <= char <= "~":
            width += 1
        elif char in "\u4f5c\u7528\u57df\u6237\u76ee\u5f55\u7cfb\u7edf":
            width += 2
        elif char != "\u0301":
            raise AssertionError(("unexpected character in fixture oracle", repr(char)))
    return width


def aligned_fields(output, labels, values, colon_column):
    lines = output.decode("utf-8").splitlines()
    for label, value in zip(labels, values):
        candidates = [line for line in lines
                      if re.match(r"^  " + re.escape(label) + r" +: ", line)]
        assert len(candidates) == 1, (label, lines[:12])
        prefix, _, suffix = candidates[0].partition(":")
        assert fixture_columns(prefix) == colon_column, candidates[0]
        assert suffix == " " + value, candidates[0]
        assert fixture_columns(prefix + ": ") == colon_column + 2, candidates[0]


def make_index(home):
    path = home / "index/current.json"
    path.parent.mkdir(parents=True)
    path.write_text(json.dumps({"schema_version": "taffish.index/v1",
                                "packages": {}, "commands": {}}), encoding="utf-8")


def assert_quiet(stdout, stderr):
    assert not stderr, stderr
    assert b"\x1b" not in stdout and b"\r" not in stdout, stdout[:200]
    assert not any(marker in stdout for marker in PROGRESS), stdout[:500]


def layout(taf, logs):
    # The harness root can exceed the 80-column layout budget by itself.
    # Resolve /tmp aliases explicitly, keeping these isolated fixture paths short.
    with tempfile.TemporaryDirectory(prefix="td-", dir="/tmp") as temporary:
        root = Path(temporary).resolve()
        user, system = root / "u", root / "s"
        make_index(user)
        system.mkdir()
        values = ("user", str(user) + "/", str(system) + "/")
        assert len(values[1]) < 55 and len(values[2]) < 55, values
        for language, column in (("en", 14), ("zh", 11)):
            out, err = capture([taf, "doctor", "index"], environment(user, system, language),
                               logs, "short-" + language)
            assert_quiet(out, err)
            localized = values if language == "en" else ("\u7528\u6237", *values[1:])
            aligned_fields(out, LABELS[language], localized, column)

        long_home = root / ("long-user-home-" * 8)
        make_index(long_home)
        for language in ("en", "zh"):
            out, err = capture([taf, "doctor", "index"], environment(long_home, system, language),
                               logs, "long-path-" + language)
            assert_quiet(out, err)
            expected = "  " + LABELS[language][1] + ":\n    " + str(long_home) + "/\n"
            assert expected in out.decode("utf-8"), out[:1000]

        catalog = user / "share/locales/fr/messages.json"
        catalog.parent.mkdir(parents=True)
        keys = ("doctor.label.scope", "doctor.label.user-home", "doctor.label.system-home")
        mixed = ("Cafe\u0301", "\u7528\u6237 home", "System path")
        catalog.write_text(json.dumps(dict(zip(keys, mixed))), encoding="utf-8")
        out, err = capture([taf, "doctor", "index"], environment(user, system, "fr"),
                           logs, "external-mixed-combining")
        assert_quiet(out, err)
        aligned_fields(out, mixed, values, 14)

        fallback = ("A deliberately very long external scope label", "First line\nSecond line",
                    "System\u200dlabel")
        catalog.write_text(json.dumps(dict(zip(keys, fallback))), encoding="utf-8")
        out, err = capture([taf, "doctor", "index"], environment(user, system, "fr"),
                           logs, "external-fallback")
        assert_quiet(out, err)
        text = out.decode("utf-8")
        assert "  " + fallback[0] + ":\n    user\n" in text, text
        assert "  First line\n  Second line:\n    " + values[1] + "\n" in text, text
        assert "  " + fallback[2] + ":\n    " + values[2] + "\n" in text, text


def progress_contract(stderr, terminal):
    if terminal:
        assert stderr.startswith(ERASE) and stderr.count(ERASE) >= 2, stderr
        frames = stderr.split(ERASE)[1:]
        assert all(b"\n" not in frame for frame in frames[:-1]), stderr
        assert frames[-1] == COMPLETE + b"\n", stderr
        assert b"\x1b" not in stderr.replace(ERASE, b""), stderr
    else:
        assert b"\x1b" not in stderr and b"\r" not in stderr, stderr
        frames = stderr.splitlines()
        assert len(frames) >= 2 and frames[-1] == COMPLETE, stderr
        assert stderr.endswith(b"\n"), stderr
    assert all(any(frame.startswith(marker) for marker in PROGRESS) for frame in frames), stderr


def doctor_body(data, *, cli_json=False):
    # MCP projects the core result, not the CLI's schema-versioned JSON wrapper.
    if cli_json:
        data = json.loads(data)
        assert data["schema_version"] == "taffish.doctor/v1", data
    assert data["check"] == "hub" and data["exit_code"] == 0 and data["init_p"] is False, data
    installs = [item for item in data["diagnostics"] if item["id"] == "hub_installation"]
    assert len(installs) == APP_COUNT + 1, len(installs)  # Original seed remains installed.
    assert all(item["inspection"]["state"] == "verified" for item in installs), installs[:1]


def progress(taf, logs):
    # Reuse real installed wrappers/manifests, never add fake sleeps or skip a fast run.
    perf = runpy.run_path(str(Path(__file__).parents[1] / "taf-hub/performance.py"))
    env = perf["ENV"]
    path = env["PATH"]
    env.update(environment(perf["HOME"], perf["ROOT"] / "system-home"))
    env["PATH"] = path
    perf["create_many"](APP_COUNT)
    before = perf["api"]["inventory"]()
    doctor = [taf, "doctor", "hub"]
    for terminal in (True, False):
        out, err = capture(doctor, env, logs, "progress-" + ("pty" if terminal else "pipe"),
                           terminal=terminal)
        progress_contract(err, terminal)
        assert not any(marker in out for marker in PROGRESS), out[:500]
    out, err = capture(doctor, dict(env, TERM="dumb"), logs, "progress-dumb-pty", terminal=True)
    progress_contract(err, False)

    for terminal in (False, True):
        out, err = capture([*doctor, "--json"], env, logs,
                           "json-" + ("pty" if terminal else "pipe"), terminal=terminal)
        assert_quiet(out, err)
        doctor_body(out, cli_json=True)
    out, err = capture([taf, "install", "--all", "--json"], env, logs, "json-install-plan")
    assert_quiet(out, err)
    plan = json.loads(out)
    assert plan["schema_version"] == "taffish.package-plan/v1", plan
    assert plan["summary"]["total"] == plan["summary"]["current"] == APP_COUNT, plan["summary"]

    requests = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "display-test", "version": "1"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {
            "name": "taffish_check_environment", "arguments": {"check": "hub"}}},
        {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {
            "name": "taffish_plan_install_all", "arguments": {}}},
    ]
    request = "".join(json.dumps(item) + "\n" for item in requests).encode("utf-8")
    for terminal in (False, True):
        out, err = capture([os.environ["TAFFISH_MCP_BIN"]], env, logs,
                           "mcp-" + ("pty" if terminal else "pipe"),
                           terminal=terminal, request=request)
        assert_quiet(out, err)
        replies = [json.loads(line) for line in out.splitlines()]
        assert len(replies) == 3 and {item["id"] for item in replies} == {1, 2, 3}, replies
        assert all(item.get("jsonrpc") == "2.0" and "error" not in item for item in replies), replies
        replies = {item["id"]: item["result"] for item in replies}
        assert not replies[2].get("isError") and not replies[3].get("isError"), replies
        doctor_body(replies[2]["structuredContent"])
        plan = replies[3]["structuredContent"]
        assert plan["ok"] and plan["dry_run_p"], plan
        assert plan["summary"]["total"] == plan["summary"]["current"] == APP_COUNT, plan["summary"]

    out, err = capture(doctor, env, logs, "closed-stderr-human", closed=True)
    assert not err and b"debugger" not in out.lower(), out[:500]
    assert out == (logs / "progress-pipe.stdout").read_bytes(), "closed stderr changed doctor output"
    out, err = capture([*doctor, "--json"], env, logs, "closed-stderr-json", closed=True)
    assert_quiet(out, err)
    doctor_body(out, cli_json=True)
    assert before == perf["api"]["inventory"](), "display/stream checks changed installations"

    record = json.loads((perf["HOME"] / "apps/perf-0000" / perf["LATEST"] / "install.json").read_text())
    Path(record["command_file"]).write_text("#!/bin/sh\nexit 23\n", encoding="utf-8")
    damaged = perf["api"]["inventory"]()
    out, err = capture(doctor, env, logs, "invalid-install-pty", terminal=True, code=1)
    # The scan completes even when its diagnosis is invalid; the business exit is 1.
    progress_contract(err, True)
    assert b"wrapper-digest" in out, out[:1000]
    closed_out, closed_err = capture(doctor, env, logs, "invalid-install-closed", closed=True, code=1)
    assert not closed_err and closed_out == out, "closed stderr changed failure result"
    assert damaged == perf["api"]["inventory"](), "failed diagnosis changed installations"
    print(f"[display] {APP_COUNT}-app fixture; timeout={TIMEOUT}s is a hang guard, not a performance gate")


if __name__ == "__main__":
    case = sys.argv[1]
    logs = Path(os.environ["TAFFISH_TEST_TMP_ROOT"]) / ("display-" + case)
    {"layout": layout, "progress": progress}[case](os.environ["TAF_BIN"], logs)
