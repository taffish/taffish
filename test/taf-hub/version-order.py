#!/usr/bin/env python3
"""Offline CLI/MCP regression for index targets, mixed versions and safe prune."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


OLD = "2.0.0-a.7.3-r1"
LATEST = "2.0.0-a.7.10-r1"
AHEAD = "2.0.0-a.7.20-r1"
CASE = sys.argv[1]
ROOT = Path(os.environ["TAFFISH_TEST_TMP_ROOT"]) / (globals().get("FIXTURE_PREFIX", "hub-version-") + CASE)
HOME = ROOT / "user-home"
ENV = dict(os.environ, TAFFISH_USER_HOME=str(HOME),
           TAFFISH_SYSTEM_HOME=str(ROOT / "system-home"))
ENV["PATH"] = str(HOME / "bin") + os.pathsep + ENV["PATH"]
TAF = os.environ["TAF_BIN"]
INDEX = HOME / "index/current.json"


def run(*args, ok=True, **kwargs):
    result = subprocess.run([TAF, *args], env=ENV, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            timeout=60, **kwargs)
    assert (result.returncode == 0) == ok, (args, result.returncode, result.stdout, result.stderr)
    return result.stdout


def plan(*args):
    result = json.loads(run(*args, "--json"))
    assert result["schema_version"] == "taffish.package-plan/v1", result
    return result


def item(*args):
    return next(x for x in plan(*args)["items"] if x["package_name"] == "order-demo")


def save(index):
    INDEX.parent.mkdir(parents=True, exist_ok=True)
    INDEX.write_text(json.dumps(index), encoding="utf-8")


def fixture(kind="flow"):
    records = {}
    for identity in (OLD, LATEST, AHEAD):
        version = identity.rsplit("-r", 1)[0]
        parent = ROOT / "source" / version
        parent.mkdir(parents=True)
        run("new", "order-demo", "--" + kind, "--version", version, cwd=parent)
        source = parent / "order-demo"
        (source / "src/main.taf").write_text(f"<taffish>\necho '{identity}'\n", encoding="utf-8")
        records[identity] = {
            "name": "order-demo", "kind": kind, "version": version, "release": 1,
            "version_id": identity, "tag": "v" + identity, "license": "Apache-2.0",
            "repository_url": "https://github.com/taffish/order-demo",
            "command": {"name": "taf-order-demo"},
            "paths": {"main": "src/main.taf", "help": "docs/help.md"},
            "source": {"local_path": str(source), "ref": "v" + identity},
        }
    package = {"latest": LATEST, "versions": records,
               "repository_url": "https://github.com/taffish/order-demo",
               "command": {"name": "taf-order-demo"}}
    index = {"schema_version": "taffish.index/v1", "commands": {},
             "packages": {"order-demo": package}}
    save(index)
    return index, package


def install(identity):
    run("install", "order-demo", identity)


def versions():
    return {x["version_id"] for x in json.loads(run("list", "--json"))["items"]}


def inventory():
    return {str(p.relative_to(HOME)): (p.stat().st_mode,
            hashlib.sha256(p.read_bytes()).hexdigest())
            for p in HOME.rglob("*") if p.is_file()}


def alias():
    return subprocess.check_output([str(HOME / "bin/taf-order-demo"), "--version"],
                                   env=ENV, text=True, timeout=15)


def mixed():
    fixture()
    assert item("install", "--all")["latest_version_id"] == LATEST
    install(OLD)
    assert LATEST in run("install", "order-demo", "--dry-run")
    before = inventory()
    for args in (("install", "--all"), ("outdated",), ("upgrade", "--all")):
        result = item(*args)
        assert result["latest_version_id"] == LATEST and result["status"] == "outdated", result
    assert inventory() == before, "planning changed installed files"
    run("install", "--all", "--yes")
    assert versions() == {OLD, LATEST}
    assert "-> taf-order-demo-v" + LATEST in alias()
    assert item("prune")["remove_versions"] == [OLD]
    run("prune", "--yes")
    assert versions() == {LATEST}
    assert subprocess.check_output([str(HOME / ("bin/taf-order-demo-v" + LATEST))],
                                   env=ENV, text=True, timeout=15).strip() == LATEST
    assert item("install", "--all")["action"] == "skip"
    assert item("upgrade")["action"] == "skip"
    assert item("prune")["action"] == "skip"


def authoritative():
    fixture()
    install(AHEAD)
    assert item("upgrade")["status"] == "ahead"
    assert item("prune")["action"] == "skip"
    install(OLD)
    install(LATEST)
    assert item("install", "--all")["status"] == "current"
    result = item("prune")
    assert result["latest_version_id"] == LATEST and result["remove_versions"] == [OLD], result
    run("prune", "--yes")
    assert versions() == {LATEST, AHEAD}
    assert "-> taf-order-demo-v" + AHEAD in alias(), "alias must remain local, not index-selected"
    INDEX.unlink()
    before = inventory()
    assert item("prune")["action"] == "skip"
    # Uninstall rebuilds the alias without consulting the index.
    run("uninstall", "order-demo", AHEAD)
    assert "-> taf-order-demo-v" + LATEST in alias()
    assert before != inventory()


def protections():
    index, package = fixture()
    install(OLD)
    before = inventory()
    run("prune", "--yes")
    assert before == inventory(), "latest absent: removed usable old version"
    install(LATEST)
    for latest in (None, "missing-r1"):
        package["latest"] = latest
        save(index)
        before = inventory()
        run("prune", "--yes")
        assert item("install", "--all")["status"] == "missing_index"
        assert inventory() == before
    package["latest"] = LATEST
    save(index)
    metadata_path = HOME / "apps/order-demo" / OLD / "install.json"
    metadata = json.loads(metadata_path.read_text())
    original = dict(metadata)
    for kind in ("local-project", "unknown", None):
        metadata["origin_kind"] = kind
        metadata_path.write_text(json.dumps(metadata))
        before = inventory()
        run("prune", "--yes")
        assert before == inventory(), ("deleted protected source", kind)
    metadata = dict(original, repository_url="https://example.test/private")
    metadata_path.write_text(json.dumps(metadata))
    before = inventory()
    run("prune", "--yes")
    assert before == inventory()
    metadata_path.write_text(json.dumps(original))
    new_meta = json.loads((HOME / "apps/order-demo" / LATEST / "install.json").read_text())
    Path(new_meta["command_file"]).write_text("broken")
    before = inventory()
    run("prune", "--yes")
    assert before == inventory(), "invalid target allowed prune"
    run("install", "--all", "--yes", "--prune-old", ok=False)
    assert before == inventory()


def failure_scope():
    index, package = fixture()
    install(OLD)
    record = package["versions"][LATEST]
    source = record["source"]["local_path"]
    record["source"]["local_path"] = str(ROOT / "missing-source")
    save(index)
    before = inventory()
    run("upgrade", "--yes", "--prune-old", ok=False)
    assert before == inventory(), "failed upgrade changed old install"
    record["source"]["local_path"] = source
    save(index)
    # Kind filtering must also constrain the prune-old pass.
    install(LATEST)
    before = inventory()
    run("install", "--all", "--tools", "--yes", "--prune-old")
    assert before == inventory(), "tools operation pruned a flow"
    run("upgrade", "--system", "--dry-run", ok=False)
    assert before == inventory(), "system plan changed user home"
    run("install", "--all", "--flows", "--yes", "--prune-old")
    assert versions() == {LATEST}


def kind_scope():
    excluded, requested, flag = (("flow", "tool", "--tools") if CASE == "kind-tools"
                                 else ("tool", "flow", "--flows"))
    index, package = fixture(excluded)
    install(OLD)
    package["versions"]["nightly-r1"] = dict(package["versions"][LATEST],
        version="nightly", version_id="nightly-r1", tag="vnightly-r1")
    package["latest"] = "nightly-r1"
    save(index)
    before = inventory()
    for command in ("outdated", "upgrade"):
        for selector in ((flag,), ("--kind", requested)):
            result = plan(command, *selector)
            assert result["items"] == [] and result["summary"]["total"] == 0, result
        for selector in (("--all",), ("--kind", excluded)):
            result = subprocess.run([TAF, command, *selector, "--json"], env=ENV,
                                    capture_output=True, text=True, timeout=60)
            assert result.returncode == 1 and "cannot safely order" in result.stderr, result
    assert plan("upgrade", flag, "--yes", "--prune-old")["items"] == []
    assert plan("install", "--all", flag)["items"] == []

    requests = [{"jsonrpc": "2.0", "id": 0, "method": "initialize",
                 "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                            "clientInfo": {"name": "kind-scope-test", "version": "1"}}},
                {"jsonrpc": "2.0", "method": "notifications/initialized"}]
    cases = [(name, kind) for name in ("taffish_check_outdated", "taffish_plan_upgrade")
             for kind in (requested, excluded, "all")]
    for i, (name, kind) in enumerate(cases, 1):
        requests.append({"jsonrpc": "2.0", "id": i, "method": "tools/call",
                         "params": {"name": name, "arguments": {"kind": kind}}})
    result = subprocess.run([os.environ["TAFFISH_MCP_BIN"]], env=ENV,
                            input="".join(json.dumps(x) + "\n" for x in requests),
                            text=True, capture_output=True, timeout=60)
    assert result.returncode == 0 and not result.stderr, result
    replies = {x["id"]: x for x in map(json.loads, result.stdout.splitlines())}
    for i, (name, kind) in enumerate(cases, 1):
        payload = replies[i]["result"]
        body = payload["structuredContent"]
        if kind == requested:
            assert not payload.get("isError") and body["ok"] is True, payload
            # Preserve the existing MCP plist encoding: an empty NIL is false.
            assert body["items"] is False and body["summary"]["total"] == 0, body
            if name == "taffish_plan_upgrade":
                assert body["dry_run_p"] is True, body
        else:
            assert payload["isError"] is True and body["ok"] is False, payload
            assert body["error"]["kind"] == "business-error", body
    assert inventory() == before, "kind-scoped planning changed installation"

    # Selected kinds must still produce their normal plan once sorting is valid.
    package["latest"] = LATEST
    save(index)
    before = inventory()
    for command in ("outdated", "upgrade"):
        assert item(command, "--kind", excluded)["status"] == "outdated"
        assert item(command, "--all")["latest_version_id"] == LATEST
    assert inventory() == before, "valid plan changed installation"


def mcp():
    fixture()
    install(OLD)
    before = inventory()
    names = ("taffish_check_outdated", "taffish_plan_install_all",
             "taffish_plan_upgrade", "taffish_plan_prune")
    requests = [{"jsonrpc": "2.0", "id": 0, "method": "initialize",
                 "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                            "clientInfo": {"name": "order-test", "version": "1"}}},
                {"jsonrpc": "2.0", "method": "notifications/initialized"}]
    for i, name in enumerate(names, 1):
        requests.append({"jsonrpc": "2.0", "id": i, "method": "tools/call",
                         "params": {"name": name, "arguments": {}}})
    result = subprocess.run([os.environ["TAFFISH_MCP_BIN"]], env=ENV,
                            input="".join(json.dumps(x) + "\n" for x in requests),
                            text=True, capture_output=True, timeout=60)
    assert result.returncode == 0, result.stderr
    replies = {x["id"]: x for x in map(json.loads, result.stdout.splitlines())}
    for i, name in enumerate(names, 1):
        payload = replies[i]["result"]
        assert not payload.get("isError"), payload
        body = payload["structuredContent"]
        assert body["ok"] is True, body
        selected = body["items"][0]
        assert selected["latest_version_id"] == LATEST, body
        if name == "taffish_plan_prune":
            assert selected["action"] == "skip", body
        else:
            assert selected["status"] == "outdated", body
            expected = "upgrade" if name == "taffish_plan_install_all" else "install_latest"
            assert selected["action"] == expected, body
        if name != "taffish_check_outdated":
            assert body["dry_run_p"] is True, body
    assert inventory() == before, "MCP planner modified installation"


CASES = {"mixed": mixed, "authoritative": authoritative, "protections": protections,
         "failure-scope": failure_scope, "mcp": mcp,
         "kind-tools": kind_scope, "kind-flows": kind_scope}
if __name__ == "__main__":
    CASES[CASE]()
