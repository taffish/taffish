"""Bounded black-box checks with a live controlling terminal, not stdin EOF."""

import fcntl
import json
import os
from pathlib import Path
import pty
import re
import selectors
import signal
import subprocess
import sys
import termios
import time


ROOT = Path(os.environ["TAFFISH_TEST_TMP_ROOT"]) / ("cli-boundary-" + sys.argv[1])
ROOT.mkdir()
BINS = {"taf": os.environ["TAF_BIN"], "taffish": os.environ["TAFFISH_BIN"],
        "taffish-mcp": os.environ["TAFFISH_MCP_BIN"]}
PREFIX = {name: "[" + name.upper() + "-ERROR]" for name in BINS}
RAW = re.compile(r"^Unhandled |^Backtrace|^Error:|debugger invoked|"
                 r"restarts \(invokable|unhandled condition in --disable-debugger|"
                 r"^\s*\d+\]\s*$|^[0-9A-Fa-f]+\s+\"\?\?\?\"", re.M)


def run(app, args=(), data=None, env=None, close=(), full=(), read_only=(), broken=False,
        terminal=False, interrupt=False):
    master, slave = pty.openpty()
    pipe_write = None
    if broken:
        pipe_read, pipe_write = os.pipe()
        os.close(pipe_read)

    def setup():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
        for fd in close:
            os.close(fd)
        if read_only:
            # Keep the descriptor slots occupied: a closed slot can be reused
            # by runtime startup (for example, when it opens /dev/tty).
            fd = os.open(os.devnull, os.O_RDONLY)
            for target in read_only:
                os.dup2(fd, target)
            if fd not in read_only:
                os.close(fd)
        if full:
            fd = os.open("/dev/full", os.O_WRONLY)
            for target in full:
                os.dup2(fd, target)
            if fd not in full:
                os.close(fd)

    output = slave if terminal else (pipe_write if broken else subprocess.PIPE)
    process = subprocess.Popen(
        [BINS[app], *args], cwd=ROOT, env=dict(os.environ, **(env or {})),
        stdin=subprocess.PIPE if data is not None else slave,
        stdout=output, stderr=slave if terminal else subprocess.PIPE,
        preexec_fn=setup, close_fds=True)
    os.close(slave)
    if pipe_write is not None:
        os.close(pipe_write)
    if data is not None:
        try:
            process.stdin.write(data)
        except BrokenPipeError:
            pass
        finally:
            try:
                process.stdin.close()
            except BrokenPipeError:
                pass
    selector = selectors.DefaultSelector()
    chunks = {"stdout": bytearray(), "stderr": bytearray(), "terminal": bytearray()}
    for stream, name in ((process.stdout, "stdout"), (process.stderr, "stderr"),
                         (master, "terminal")):
        if stream is not None:
            fd = stream if isinstance(stream, int) else stream.fileno()
            os.set_blocking(fd, False)
            selector.register(fd, selectors.EVENT_READ, name)
    start = time.monotonic()
    exited = None
    sent = False
    try:
        while True:
            for key, _ in selector.select(0.03):
                try:
                    chunk = os.read(key.fd, 65536)
                except BlockingIOError:
                    continue
                except OSError:
                    chunk = b""
                if chunk:
                    chunks[key.data].extend(chunk)
                    assert len(chunks[key.data]) < 1_000_000, "excessive output"
                else:
                    selector.unregister(key.fd)
            now = time.monotonic()
            if interrupt and not sent and now - start > 0.5 and process.poll() is None:
                process.send_signal(signal.SIGINT)
                sent = True
            if process.poll() is not None:
                exited = exited or now
                if not selector.get_map() or now - exited > 0.15:
                    break
            if now - start >= 8:
                raise TimeoutError("process did not exit; possible debugger wait")
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        selector.close()
        os.close(master)
        for stream in (process.stdout, process.stderr):
            if stream is not None:
                stream.close()
    texts = {name: value.decode("utf-8", errors="replace") for name, value in chunks.items()}
    print(app, list(args), "exit", process.returncode, texts, flush=True)
    assert not RAW.search("\n".join(texts.values())), "raw runtime/debugger diagnostic"
    assert not interrupt or sent, "process exited before receiving SIGINT"
    return process.returncode, texts


def failure(app, args=(), **kwargs):
    code, streams = run(app, args, **kwargs)
    assert code == 1, ("expected failure exit 1", code)
    assert not streams["stdout"], "error polluted stdout"
    return streams


def rpc(method, params=None, request_id=1):
    obj = {"jsonrpc": "2.0", "id": request_id, "method": method}
    if params is not None:
        obj["params"] = params
    return json.dumps(obj).encode() + b"\n"


def startup():
    homes = ["~taffish-boundary-missing-user-" + str(os.getpid()) + "/",
             str(ROOT / "[unclosed")]
    for app in BINS:
        failures = 0
        for home in homes:
            for terminal in (False, True):
                code, streams = run(app, ["--help"], env={"TAFFISH_USER_HOME": home},
                                    terminal=terminal)
                if code == 0:
                    # SBCL and LispWorks reject different pathname spellings.
                    assert "Usage:" in streams["terminal" if terminal else "stdout"]
                else:
                    failures += 1
                    assert code == 1 and not streams["stdout"]
                    assert PREFIX[app] in streams["terminal" if terminal else "stderr"]
                    if app == "taffish-mcp" and not terminal:
                        # Keep stdout observable if reporting this same error fails.
                        failure(app, ["--help"], env={"TAFFISH_USER_HOME": home},
                                read_only=(2,))
        assert failures >= 2, "did not exercise a startup pathname failure"


def diagnostics():
    source = ROOT / "required.taf"
    source.write_text("<args>\n::!(--name)n::\n<shell>\necho ::n::\n", encoding="utf-8")
    for app, args in (("taf", ["unknown-boundary-command"]), ("taffish", [str(source)])):
        streams = failure(app, args)
        assert PREFIX[app] in streams["stderr"]
    syntax = ROOT / "syntax.taf"
    syntax.write_text("<args>\n::unclosed\n", encoding="utf-8")
    streams = failure("taffish", [str(syntax)])
    assert "line" in streams["stderr"] and "^" in streams["stderr"]


def unwritable_stderr():
    for app in BINS:
        for destinations in ({"read_only": (1, 2)},
                             {"read_only": (2,), "broken": True},
                             {"close": (2,), "broken": True}):
            # A broken pipe stays broken even if the runtime reopens stderr.
            # Do not infer an output failure merely from closing fd 1 and 2.
            streams = failure(app, ["--help"], **destinations)
            if "read_only" in destinations:
                assert not streams["stderr"] and not streams["terminal"]
            else:
                assert not streams["stderr"] or PREFIX[app] in streams["stderr"]
                assert not streams["terminal"] or PREFIX[app] in streams["terminal"]
    failure("taf", ["unknown-boundary-command"], close=(2,))
    # A valid ping requires a reply. Writing it to a pipe with no reader
    # forces a transport error regardless of the runtime's input decoder.
    stderr_faults = [{"read_only": (2,)}, {"close": (2,)}]
    if sys.platform.startswith("linux"):
        stderr_faults.append({"full": (2,)})
    for fault in stderr_faults:
        streams = failure("taffish-mcp", data=rpc("ping"), broken=True, **fault)
        if "close" in fault:
            assert not streams["stderr"] or PREFIX["taffish-mcp"] in streams["stderr"]
            assert not streams["terminal"] or PREFIX["taffish-mcp"] in streams["terminal"]
        else:
            assert not streams["stderr"] and not streams["terminal"]
    if sys.platform.startswith("linux"):
        source = ROOT / "invalid.taf"
        source.write_bytes(b"\xff\n")
        for destinations in ({"close": (2,)}, {"full": (2,)}):
            failure("taf", ["unknown-boundary-command"], **destinations)
            failure("taffish", [str(source)], **destinations)


def broken_stdout():
    for app in BINS:
        streams = failure(app, ["--help"], broken=True)
        assert PREFIX[app] in streams["stderr"]
    streams = failure("taffish-mcp", data=rpc("ping"), broken=True)
    assert PREFIX["taffish-mcp"] in streams["stderr"]


def interrupt():
    for app in ("taffish", "taffish-mcp"):
        code, streams = run(app, interrupt=True)
        assert code == 1 and not streams["terminal"]
        # Preserve LispWorks delivery's existing SIGINT exit notification.
        if streams["stdout"]:
            assert streams["stdout"] == BINS[app] + " : Interrupted - quitting"
            assert not streams["stderr"]
        else:
            assert PREFIX[app] in streams["stderr"]


def mcp_recovery():
    cases = [b"{bad}\n", rpc("unknown/method"),
             rpc("tools/call", {"name": "taffish_compile_source", "arguments": {
                 "source": "<args>\n::unclosed\n"}})]
    for data in cases:
        code, streams = run("taffish-mcp", data=data + rpc("ping", request_id=2))
        assert code == 0 and not streams["stderr"] and not streams["terminal"]
        first, second = [json.loads(line) for line in streams["stdout"].splitlines()]
        assert "error" in first or first.get("result", {}).get("isError") is True
        assert second == {"jsonrpc": "2.0", "id": 2, "result": {}}


CASES = {"startup": startup, "diagnostics": diagnostics,
         "unwritable-stderr": unwritable_stderr, "broken-stdout": broken_stdout,
         "interrupt": interrupt, "mcp-recovery": mcp_recovery}
CASES[sys.argv[1]]()
