#!/usr/bin/env python3
"""Exercise the root loader's target/ contract without using the checkout's target/."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
PROGRAMS = ("taf", "taffish", "taffish-mcp")


def check_loader(implementation, work):
    src = work / "source with spaces"
    target = src / "target"
    target.mkdir(parents=True)
    for name in ("taffish.asd", "load-taffish.lisp"):
        shutil.copy2(ROOT / name, src / name)
    for name in ("vendor/han", "taffish-i18n", "taffish-core", "taf-core",
                 "taffish-cli", "taf-cli", "taffish-mcp", "scripts"):
        shutil.copytree(ROOT / name, src / name)
    version = re.search(r'^\s*:version "([^"]+)"', (src / "taffish.asd").read_text(), re.M)[1]

    compiler = os.environ.get(implementation.upper()) or implementation
    flags = ["--no-init", "--batch", "--load"] if implementation == "ccl" else ["-norc", "-nodebug", "-shell"]
    command = [compiler, *flags, str(src / "load-taffish.lisp"), "--"]
    env = dict(os.environ, XDG_CACHE_HOME=str(work / "cache"))

    def run_loader(option, *, expect_failure=False):
        result = subprocess.run(command + [option], cwd=work, env=env, stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
        if (result.returncode != 0) != expect_failure:
            raise RuntimeError(f"{option}: unexpected exit {result.returncode}\n"
                               + result.stdout.decode(errors="replace"))
        return result.stdout

    def check_versions():
        for name in PROGRAMS:
            result = subprocess.check_output([str(target / name), "--version"], text=True, timeout=30)
            assert result.split() == [name, version], (name, result)

    def fingerprint(name):
        path = target / name
        metadata = path.stat()
        return (metadata.st_ino, metadata.st_mtime_ns, metadata.st_mode, hashlib.sha256(path.read_bytes()).digest())

    protected = ("taf-linux-amd64-0.11.0", "ARCHIVE-SHA256SUMS", "ARCHIVE-SHA256SUMS.asc")
    for name in (*PROGRAMS, *protected):
        (target / name).write_text(f"preexisting {name}\n")
    original = {name: fingerprint(name) for name in protected}
    run_loader("--compile")
    check_versions()

    # Require a real rebuild of the selected program while preserving its neighbors.
    untouched = {name: fingerprint(name) for name in ("taf", "taffish")}
    (target / "taffish-mcp").write_text("stale MCP executable\n")
    run_loader("--compile-mcp")
    check_versions()
    assert untouched == {name: fingerprint(name) for name in untouched}

    before_failure = {name: fingerprint(name) for name in PROGRAMS}
    fault = "TAFFISH-LOADER-REGRESSION-COMPILE-ERROR"
    # An error in the copied source must reach the shell, leaving all usable output intact.
    with (src / "taffish-i18n/package.lisp").open("a") as stream:
        stream.write(f'\n(eval-when (:compile-toplevel :load-toplevel) (error "{fault}"))\n')
    assert fault.encode() in run_loader("--compile", expect_failure=True)
    assert before_failure == {name: fingerprint(name) for name in PROGRAMS}
    assert original == {name: fingerprint(name) for name in protected}
    assert set(p.name for p in target.iterdir()) == set((*PROGRAMS, *protected))
    print(f"PASS {implementation}: root loader build, selected rebuild, failed build and preserved target files.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("implementation", choices=("ecl", "ccl"))
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="taffish-loader-test-") as tmp:
        check_loader(args.implementation, Path(tmp))
