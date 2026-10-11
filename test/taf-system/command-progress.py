#!/usr/bin/env python3
"""Offline command-status contracts against delivered binaries; no live services."""
import errno
import json
import os
from pathlib import Path
import pty
import runpy
import select
import subprocess
import sys
import time


HERE = Path(__file__).parent
DISPLAY = runpy.run_path(str(HERE / "display.py"))
REPAIR = runpy.run_path(str(HERE.parent / "taf-hub/repair.py"))
TAF = os.environ["TAF_BIN"]
ERASE = b"\r\x1b[K"


def updates():
    root = Path(os.environ["TAFFISH_TEST_TMP_ROOT"]) / "command-progress-update"
    root.mkdir()
    bin_dir = root / "bin"
    bin_dir.mkdir()
    fixture = root / "index.json"
    fixture.write_text(json.dumps({"schema_version": "taffish.index/v1", "packages": {}, "commands": {}}))
    curl = bin_dir / "curl"
    curl.write_text(f"#!{sys.executable}\n" + '''import os, sys, time
from pathlib import Path
root = Path(os.environ["PROGRESS_FIXTURE"])
with (root / "calls").open("a") as log:
    log.write("curl\\n")
(root / "waiting").touch()
deadline = time.monotonic() + 20
while not (root / "continue").exists():
    if time.monotonic() > deadline:
        sys.exit(99)
    time.sleep(0.02)
if os.environ.get("PROGRESS_FAIL"):
    print("fixture connection reset", file=sys.stderr)
    sys.exit(35)
sys.stdout.write((root / "index.json").read_text())
''')
    curl.chmod(0o755)
    env = DISPLAY["environment"](root / "home", root / "system")
    env.update(PROGRESS_FIXTURE=str(root), PATH=str(bin_dir) + os.pathsep + env["PATH"], COLUMNS="80")
    command = [TAF, "update", "--url", "https://example.invalid/index.json"]
    logs = root / "logs"
    logs.mkdir()
    # The fake downloader cannot finish until we see stderr. This detects delayed
    # output without relying on an arbitrary startup-time performance threshold.
    for terminal, language in ((False, "en"), (True, "zh")):
        env["TAFFISH_LANGUAGE"] = language
        marker = "Downloading index" if language == "en" else "正在下载索引"
        release = root / "continue"
        release.unlink(missing_ok=True)
        master, slave = pty.openpty() if terminal else (None, None)
        stderr = bytearray()
        with (logs / (language + ".stdout")).open("wb") as out:
            proc = subprocess.Popen(command, env=env, stdin=subprocess.DEVNULL, stdout=out,
                                    stderr=slave if terminal else subprocess.PIPE)
            if slave is not None:
                os.close(slave)
            fd = master if terminal else proc.stderr.fileno()
            try:
                deadline = time.monotonic() + 30
                while marker.encode() not in stderr:
                    assert time.monotonic() < deadline, ("missing early notice", stderr)
                    ready, _, _ = select.select([fd], [], [], 0.2)
                    if ready:
                        data = os.read(fd, 65536)
                        assert data, ("EOF before status", stderr, proc.poll())
                        stderr.extend(data)
                assert proc.poll() is None, "status was buffered until after the download"
                release.touch()
                while True:
                    assert time.monotonic() < deadline, "update did not finish"
                    ready, _, _ = select.select([fd], [], [], 0.2)
                    if not ready:
                        continue
                    try:
                        data = os.read(fd, 65536)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        data = b""
                    if not data:
                        break
                    stderr.extend(data)
                assert proc.wait(timeout=5) == 0, stderr
            finally:
                release.touch()
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
                if master is not None:
                    os.close(master)
                if proc.stderr is not None:
                    proc.stderr.close()
                (logs / (language + ".stderr")).write_bytes(stderr)
        assert (ERASE in stderr) is terminal, stderr
        assert stderr.endswith(b"\n"), stderr
        current = root / "home/index/current.json"
        assert json.loads(current.read_text()) == json.loads(fixture.read_text())

    env["TAFFISH_LANGUAGE"] = "en"
    before = (root / "home/index/current.json").read_bytes()
    env["PROGRESS_FAIL"] = "1"
    out, err = DISPLAY["capture"](command, env, logs, "failure", terminal=True, code=1)
    assert b"Downloading index" in err and b"[TAF-ERROR]" in err, err
    assert b"\n[TAF-ERROR]" in err, "error overwrote active status"
    assert not out
    assert before == (root / "home/index/current.json").read_bytes()
    del env["PROGRESS_FAIL"]
    out, err = DISPLAY["capture"](command, env, logs, "closed-stderr", closed=True)
    assert not err and b"[TAF] updated TAFFISH index" in out, out
    env["TERM"] = "dumb"
    _, err = DISPLAY["capture"](command, env, logs, "dumb", terminal=True)
    assert b"\x1b" not in err and b"Downloading index" in err, err
    # Sparse external catalogs override one message; others keep normal fallback.
    catalog = root / "home/share/locales/fr/messages.json"
    catalog.parent.mkdir(parents=True)
    catalog.write_text(json.dumps({"taf.progress.download": "Chargement index"}))
    env["TAFFISH_LANGUAGE"] = "fr"
    _, err = DISPLAY["capture"](command, env, logs, "external")
    assert b"Chargement index" in err, err
    assert (root / "calls").read_text().splitlines() == ["curl"] * 6
    requests = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "protocolVersion": "2025-03-26", "capabilities": {},
            "clientInfo": {"name": "progress-test", "version": "1"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {
            "name": "taffish_update_index", "arguments": {"url": str(fixture)}}},
    ]
    out, err = DISPLAY["capture"]([os.environ["TAFFISH_MCP_BIN"]], env, logs, "mcp-update",
                                  request=("\n".join(map(json.dumps, requests)) + "\n").encode())
    assert not err, err
    replies = {item["id"]: item for item in map(json.loads, out.splitlines())}
    assert not replies[2]["result"].get("isError"), replies
    result = replies[2]["result"]["structuredContent"]
    assert result["scope"] == "user" and result["bytes"] == fixture.stat().st_size, result
    assert Path(result["current_file"]).read_bytes() == fixture.read_bytes(), result


def hub():
    f = REPAIR["Fixture"]("command-progress")
    alpha, beta, old, latest = (REPAIR[k] for k in ("ALPHA", "BETA", "OLD", "LATEST"))
    f.env.update(TERM="xterm-256color", COLUMNS="80")
    for name in (alpha, beta):
        f.add(name, (old, latest))
        f.index["packages"][name]["latest"] = old
    f.save()

    def cli(args, name, **kwargs):
        return DISPLAY["capture"]([TAF, *args], f.env, f.logs, name, **kwargs)

    out, err = cli(["install", "--all", "--yes"], "install", terminal=True)
    for name in (alpha, beta):
        assert ("taf-" + name).encode() in err, err
        f.installed.append((name, old))
        f.verified(name, old)
    assert b"1/2" in err and b"2/2" in err and b"Getting source" in err, err
    assert b"Building command snapshot" in err, err
    assert b"\x1b" not in out, out
    before = f.state()
    out, err = cli(["install", "--all", "--yes"], "noop")
    assert b"Getting source" not in err and b"Building command" not in err, err
    f.unchanged(before)
    for name in (alpha, beta):
        f.index["packages"][name]["latest"] = latest
    f.save()
    before = f.state()
    out, err = cli(["upgrade", "--all", "--dry-run"], "upgrade-preview")
    assert b"Getting source" not in err and b"Removing installed" not in err, err
    f.unchanged(before)
    out, err = cli(["upgrade", "--all", "--yes"], "upgrade", terminal=True)
    assert b"1/2" in err and b"2/2" in err and b"Getting source" in err, err
    for name in (alpha, beta):
        f.installed.append((name, latest))
        f.verified(name, latest)
    out, err = cli(["prune", "--all", "--yes"], "prune", terminal=True)
    assert b"Removing installed version" in err and old.encode() in err, err
    for name in (alpha, beta):
        assert not f.install_root(name, old).exists()
        f.manifest(name).unlink()
    out, err = cli(["install", "--all", "--repair", "--yes"], "repair", terminal=True)
    assert err.count(b"Local installation checks complete.") == 1, err
    assert b"Rechecking the repair plan" in err and b"Backing up and switching" in err, err
    for name in (alpha, beta):
        f.verified(name)
    out, err = cli(["install", "--all", "--repair", "--yes", "--json"], "repair-json")
    assert not err, err
    assert json.loads(out)["summary"]["repair"] == 0, out
    out, err = cli(["uninstall", alpha, beta, "--dry-run"], "uninstall-preview")
    assert b"Removing installed version" not in err, err
    out, err = cli(["uninstall", alpha, beta], "uninstall", terminal=True)
    assert b"Removing installed version" in err and b"2/2" in err, err
    assert not f.install_root(alpha).exists() and not f.install_root(beta).exists()


if __name__ == "__main__":
    {"update": updates, "hub": hub}[sys.argv[1]]()
