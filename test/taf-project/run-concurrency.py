"""Exercise two overlapping taf run processes that share a temporary directory."""
import os
import stat
import subprocess
import sys
import time
from pathlib import Path


taf, root = sys.argv[1], Path(sys.argv[2]).resolve()
tmp = root / "shared tmp with ' and $"
tmp.mkdir()


def start(name):
    env = dict(os.environ, TMPDIR=str(tmp), RUN_NAME=name, RUN_MARKER=str(root / name),
               RUN_RELEASE=str(root / (name + ".release")))
    return subprocess.Popen([taf, "run"], cwd=root / "overlapping", env=env,
                            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def finish(proc, status=0):
    try:
        out, err = proc.communicate(timeout=30)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.communicate()
        raise
    assert proc.returncode == status, (proc.returncode, out, err)
    return out, err


first = start("first")
try:
    marker = root / "first"
    deadline = time.monotonic() + 30
    while not marker.is_file() or not marker.stat().st_size:
        assert first.poll() is None, first.communicate()
        assert time.monotonic() < deadline, "first runner did not reach its shell"
        time.sleep(0.02)
    first_script = Path(marker.read_text().rstrip("\n"))
    (root / "second.release").touch()
    assert finish(start("second"), 17) == (b"second\n", b"second diagnostic\n")
    second_script = Path((root / "second").read_text().rstrip("\n"))
    assert first_script.parent != second_script.parent, (first_script, second_script)
    assert first_script.parent.parent == second_script.parent.parent == tmp
    assert not second_script.parent.exists() and first_script.is_file()
    assert stat.S_IMODE(first_script.parent.stat().st_mode) & 0o077 == 0
finally:
    (root / "first.release").touch()
    first_output = finish(first)

assert first_output == (b"first\n", b"")
assert not first_script.parent.exists()
