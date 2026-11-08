"""Exercise the generated wrapper and native CLI against the same history file."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time


wrapper = Path(sys.argv[1]).resolve()
root = Path(sys.argv[2]).resolve()
taf = os.environ["TAF_BIN"]
home = root / "history home"
history = home / "logs/history.jsonl"
history.parent.mkdir(parents=True)
native_env = dict(os.environ, TAFFISH_USER_HOME=str(home))
wrapper_env = dict(os.environ, TAF_HISTORY_MODE="sync", TAF_HISTORY_FILE=str(history),
                   TAFFISH=os.environ["TAFFISH_BIN"])


def native_command(name, marker):
    return [taf, "history", "--record-exec", "--status", "success",
            "--command", name, "--exit-code", "0", "--", marker]


def reap(processes):
    for proc in processes:
        if proc.poll() is None:
            proc.kill()
        proc.wait()


def check_locked_file():
    # A noncooperating writer would be detected even on a quiet single-core runner.
    original = b'{"id":"before-clear"}\n'
    history.write_bytes(original)
    lock_path = Path(str(history) + ".lock")
    with lock_path.open("a+b") as lock:
        lock_inode = os.fstat(lock.fileno())
        fcntl.flock(lock, fcntl.LOCK_EX)
        # The inherited descriptor keeps the kernel lock until this child is killed.
        holder = subprocess.Popen([sys.executable, "-c", "import signal; signal.pause()"],
                                  pass_fds=(lock.fileno(),))
    workers = []
    try:
        workers.append(subprocess.Popen([wrapper, "false"], env=wrapper_env))
        workers.append(subprocess.Popen(native_command("locked", "native"), env=native_env))
        workers.append(subprocess.Popen([taf, "history", "--clear"], env=native_env))
        app, native, clear = workers
        assert app.wait(timeout=60) == 1, "logging changed the tool's exit status"
        native.wait(timeout=60)
        assert clear.wait(timeout=60) != 0, "clear reported success with the lock held"
        assert history.read_bytes() == original, "contended operation changed history"
    finally:
        reap([holder, *workers])
    subprocess.run([taf, "history", "--clear"], env=native_env, check=True, timeout=60)
    assert not history.exists() or not history.read_bytes(), "clear retained old records"
    assert os.path.samestat(lock_inode, lock_path.stat()), "clear replaced the lock file"


def check_mixed_writers():
    wrappers = {}
    native_args = {}
    running = []
    try:
        for worker in range(32):
            # Worker-specific bytes on both sides of typical shell buffer boundaries.
            marker = f"样本-{worker}-" * (2048 if worker % 2 else 1)
            expected_exit = 1 if worker % 3 == 0 else 0
            args = ["false" if expected_exit else "true", marker, "", '"quoted"', "a\\b", "line\n"]
            cwd = root / f"worker-{worker}"
            cwd.mkdir()
            proc = subprocess.Popen([wrapper, *args], cwd=cwd, env=wrapper_env)
            running.append((proc, expected_exit))
            wrappers[proc.pid] = (args, cwd, expected_exit)
            if worker % 4 == 1:
                name = f"native-{worker}"
                native_args[name] = [marker]
                proc = subprocess.Popen(native_command(name, marker), env=native_env)
                running.append((proc, 0))
        for proc, expected_exit in running:
            assert proc.wait(timeout=120) == expected_exit, (proc.pid, proc.returncode)
    finally:
        reap(proc for proc, _ in running)

    seen = set()
    with history.open("rb") as handle:
        for number, line in enumerate(handle, 1):
            assert line.endswith(b"\n"), f"unterminated history line {number}"
            try:
                record = json.loads(line.decode("utf-8"))
            except json.JSONDecodeError as error:
                excerpt = error.doc[max(0, error.pos - 32):error.pos + 32]
                raise AssertionError(f"history line {number}, {len(line)} bytes, "
                                     f"{error}; near {excerpt!r}") from error
            except UnicodeDecodeError as error:
                raise AssertionError(f"history line {number}, {error}") from error
            rid = record["id"]
            assert rid and rid not in seen, f"duplicate or empty history id on line {number}"
            seen.add(rid)
            assert record["event"] == "exec", rid
            if record["command"] == wrapper.name:
                args, cwd, code = wrappers.pop(int(rid.rsplit("-", 1)[1]))
                assert record["args"] == args, f"arguments belong to a different writer: {rid}"
                assert Path(record["cwd"]).resolve() == cwd, rid
                assert record["status"] == ("failure" if code else "success"), rid
                assert record["exit_code"] == code and record["stage"] == "run", rid
                assert record["history_backend"] == "shell-wrapper", rid
            else:
                assert record["args"] == native_args.pop(record["command"]), rid
                assert record["status"] == "success" and record["exit_code"] == 0, rid
    assert not wrappers and not native_args, ("missing workers", list(wrappers), list(native_args))


def check_async_and_off():
    directory = root / "日志[1]*"
    directory.mkdir()
    off_history = directory / "off.jsonl"
    env = dict(wrapper_env, TAF_HISTORY_FILE=str(off_history))
    subprocess.run([wrapper, "true", "disabled"], env=dict(env, TAF_HISTORY_MODE="off"),
                   check=True, timeout=60)

    # The fixture expands *ARGV* as shell source. Keep the tool body in its
    # own file so that its redirection is performed by the tool itself.
    (root / "stdio-exit.sh").write_text("echo output\necho diagnostic >&2\nexit 23\n", encoding="utf-8")
    cases = [
        (["echo", "background"], 0, b"background\n", b""),
        (["sh", "./stdio-exit.sh"], 23, b"output\n", b"diagnostic\n"),
    ]
    for args, exit_code, stdout, stderr in cases:
        destination = directory / f"async\\{exit_code}.jsonl"
        env = dict(wrapper_env, TAF_HISTORY_FILE=str(destination), TAF_HISTORY_MODE="async")
        with Path(str(destination) + ".lock").open("a+b") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            # These fixtures emit only a few bytes on each pipe, so we can observe
            # main-process exit separately from EOF while the caller owns the lock.
            with subprocess.Popen([wrapper, *args], cwd=root, env=env, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE) as proc:
                try:
                    assert proc.wait(timeout=60) == exit_code, args
                    captured = proc.communicate(timeout=60)
                    assert captured == (stdout, stderr), (args, captured)
                finally:
                    reap([proc])
            assert not destination.exists(), "history was written while the caller held the lock"
        deadline = time.monotonic() + 60
        while not destination.exists() or not destination.read_bytes().endswith(b"\n"):
            assert time.monotonic() < deadline, f"background history did not finish for {args!r}"
            time.sleep(0.05)
        records = [json.loads(line) for line in destination.read_bytes().splitlines()]
        assert len(records) == 1, records
        record = records[0]
        assert record["args"] == args, record
        assert record["exit_code"] == exit_code and record["stage"] == "run", record
        assert record["status"] == ("failure" if exit_code else "success"), record
    assert not off_history.exists(), "disabled history wrote an event"


check_locked_file()
check_mixed_writers()
check_async_and_off()
