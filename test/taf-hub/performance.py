#!/usr/bin/env python3
"""Offline scale regression: actual installed layouts, no network or app execution."""
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import time

api = runpy.run_path(str(Path(__file__).with_name("version-order.py")),
                     init_globals={"FIXTURE_PREFIX": "hub-performance-"})
ROOT, HOME, ENV, TAF, LATEST = (api[k] for k in ("ROOT", "HOME", "ENV", "TAF", "LATEST"))


def snapshot_hash(root):
    entries = []
    for path in root.rglob("*"):
        name = path.relative_to(root).as_posix()
        if name == ".taf-build.json":
            continue
        if path.is_dir():
            text = f"D:{len(name)}:{name}\n"
        else:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            text = f"F:{len(name)}:{name}:{digest}\n"
        entries.append((name, text))
    return hashlib.sha256("".join(text for _, text in sorted(entries)).encode()).hexdigest()


def create_many(count):
    index, package = api["fixture"]()
    api["install"](LATEST)
    seed = HOME / "apps/order-demo" / LATEST
    payload = [(p.relative_to(seed).as_posix(), p.read_text(), p.stat().st_mode)
               for p in seed.rglob("*") if p.is_file()]
    launchers = [(p.name, p.read_text(), p.stat().st_mode)
                 for p in (HOME / "bin").iterdir() if p.is_file()]
    packages = {}
    for i in range(count):
        name = f"perf-{i:04d}"
        root = HOME / "apps" / name / LATEST
        for relative, text, mode in payload:
            path = root / relative.replace("order-demo", name)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text.replace("order-demo", name), encoding="utf-8")
            path.chmod(mode & 0o777)
        for relative, text, mode in launchers:
            path = HOME / "bin" / relative.replace("order-demo", name)
            path.write_text(text.replace("order-demo", name), encoding="utf-8")
            path.chmod(mode & 0o777)
        record = json.loads((root / "install.json").read_text())
        command = Path(record["command_file"])
        snapshot = command.parent / ("." + record["artifact_name"])
        manifest = snapshot / ".taf-build.json"
        data = json.loads(manifest.read_text())
        data["source_sha256"] = snapshot_hash(snapshot)
        data["wrapper_sha256"] = hashlib.sha256(command.read_bytes()).hexdigest()
        manifest.write_text(json.dumps(data), encoding="utf-8")
        packages[name] = json.loads(json.dumps(package).replace("order-demo", name))
    index["packages"] = packages
    api["save"](index)


def probe(*args, code=0):
    start = time.monotonic()
    result = subprocess.run([TAF, *args], env=ENV, text=True, capture_output=True, timeout=90)
    elapsed = time.monotonic() - start
    assert result.returncode == code, (args, result.returncode, result.stdout, result.stderr)
    return result, elapsed


def mcp_plan(count):
    requests = [
        {"jsonrpc": "2.0", "id": 0, "method": "initialize",
         "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                    "clientInfo": {"name": "scale-test", "version": "1"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
         "params": {"name": "taffish_plan_install_all", "arguments": {}}},
    ]
    result = subprocess.run([os.environ["TAFFISH_MCP_BIN"]], env=ENV, text=True,
                            input="".join(json.dumps(r) + "\n" for r in requests),
                            capture_output=True, timeout=90)
    assert result.returncode == 0 and not result.stderr, result
    replies = {r["id"]: r for r in map(json.loads, result.stdout.splitlines())}
    reply = replies[1]["result"]
    assert not reply.get("isError"), reply
    body = reply["structuredContent"]
    assert body["ok"] and body["dry_run_p"], body
    assert body["summary"]["total"] == count and body["summary"]["current"] == count, body["summary"]


def scale(count):
    create_many(count)
    before = api["inventory"]()
    # No changes are needed. --yes must remain a no-op, not a faster dry-run shortcut.
    result, elapsed = probe("install", "--all", "--yes")
    limit = float(os.environ.get("TAFFISH_TEST_PERFORMANCE_MAX_SECONDS", "30"))
    if count > 300:
        limit *= count / 300
    assert elapsed < limit, ("local planning exceeded time budget", count, elapsed, limit)
    assert "cloning" not in result.stdout.lower(), result.stdout
    for line in result.stderr.splitlines():
        assert line.startswith(("[TAF] Checking local installations:",
                                "[TAF] Local installation checks complete.")), line
    if elapsed >= 1.5:
        assert result.stderr, "slow human planning emitted no progress"
    result, json_time = probe("install", "--all", "--json")
    assert not result.stderr, result.stderr
    data = json.loads(result.stdout)
    assert data["schema_version"] == "taffish.package-plan/v1", data
    assert data["summary"]["total"] == count and data["summary"]["current"] == count, data["summary"]
    assert all(item["validation"]["state"] == "verified" for item in data["items"]), data["items"][:1]
    if count == 300:
        mcp_plan(count)
    doctor, doctor_time = probe("doctor", "hub", "--json")
    assert not doctor.stderr, doctor.stderr
    report = json.loads(doctor.stdout)
    assert report["schema_version"] == "taffish.doctor/v1", report
    installs = [d for d in report["diagnostics"] if d["id"] == "hub_installation"]
    assert len(installs) == count + 1  # Includes the original seed installation.
    assert all(d["inspection"]["state"] == "verified" for d in installs)
    assert doctor_time < limit, ("doctor exceeded time budget", count, doctor_time, limit)
    repairs, repair_time = probe("install", "--all-installed", "--repair", "--json")
    repair_plan = json.loads(repairs.stdout)
    assert not repairs.stderr and repair_plan["selection"] == "installed-all-versions"
    assert repair_plan["summary"]["total"] == count + 1, repair_plan["summary"]
    # The seed was removed from the index, not from the installation directory.
    seed_item = next(i for i in repair_plan["items"] if i["package_name"] == "order-demo")
    assert seed_item["action"] == "blocked" and seed_item["reason"] == "index-target-invalid", seed_item
    assert repair_time < limit, ("installed repair exceeded time budget", count, repair_time, limit)
    selected, selected_time = probe("doctor", "hub", "perf-0000", "--json")
    assert len([d for d in json.loads(selected.stdout)["diagnostics"]
                if d["id"] == "hub_installation"]) == 1
    assert before == api["inventory"](), "planning/no-op installation modified app files"
    print(f"[perf] apps={count} install-noop={elapsed:.3f}s json-plan={json_time:.3f}s "
          f"doctor={doctor_time:.3f}s doctor-target={selected_time:.3f}s "
          f"installed-repair={repair_time:.3f}s budget={limit:.1f}s")
    # A subsequent command must see new corruption, never cached verification.
    item = data["items"][0]
    root = HOME / "apps" / item["package_name"] / LATEST
    metadata = json.loads((root / "install.json").read_text())
    Path(metadata["command_file"]).write_text("changed", encoding="utf-8")
    damaged = api["inventory"]()
    failure, _ = probe("install", "--all", "--yes", code=1)
    assert "wrapper-digest" in failure.stderr, failure.stderr
    assert damaged == api["inventory"](), "diagnostic failure changed installations"


if __name__ == "__main__":
    scale(int(sys.argv[1]))
