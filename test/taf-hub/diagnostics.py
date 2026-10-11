#!/usr/bin/env python3
"""Offline compatibility and actionable doctor tests using real executables."""
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import sys

fixture_api = runpy.run_path(str(Path(__file__).with_name("version-order.py")),
                             init_globals={"FIXTURE_PREFIX": "hub-diagnostics-"})
ROOT, HOME, ENV = (fixture_api[key] for key in ("ROOT", "HOME", "ENV"))
TAF, INDEX, OLD, LATEST = (fixture_api[key] for key in ("TAF", "INDEX", "OLD", "LATEST"))
fixture, install, inventory, save = (fixture_api[key] for key in ("fixture", "install", "inventory", "save"))


def probe(*args, code=0, env=None, cwd=None):
    result = subprocess.run([TAF, *args], env=env or ENV, cwd=cwd, text=True,
                            capture_output=True, timeout=120)
    assert result.returncode == code, (args, result.returncode, result.stdout, result.stderr)
    if "--json" in args:
        assert not result.stderr, result.stderr
    return result


def doctor(*args, code=0, env=None):
    result = probe("doctor", *args, "--json", code=code, env=env)
    assert not result.stderr, result.stderr
    data = json.loads(result.stdout)
    assert data["schema_version"] == "taffish.doctor/v1", data
    assert data["exit_code"] == code, data
    return data


def app_record(identity=LATEST, name="order-demo"):
    return json.loads((HOME / "apps" / name / identity / "install.json").read_text())


def manifest(identity=LATEST, name="order-demo"):
    record = app_record(identity, name)
    return Path(record["command_file"]).parent / ("." + record["artifact_name"]) / ".taf-build.json"


def issues(data):
    return [i for d in data["diagnostics"] for i in (d.get("inspection", {}).get("issues") or [])]


def inspections(data):
    return {d["inspection"]["package_name"]: d["inspection"]
            for d in data["diagnostics"] if d["id"] == "hub_installation"}


def mcp_check(arguments, env):
    requests = [{"jsonrpc": "2.0", "id": 1, "method": "initialize",
                 "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                            "clientInfo": {"name": "diagnostic-check", "version": "1"}}},
                {"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                 "params": {"name": "taffish_check_environment", "arguments": arguments}}]
    result = subprocess.run([os.environ["TAFFISH_MCP_BIN"]], env=env,
                            input="".join(json.dumps(r) + "\n" for r in requests).encode("utf-8"),
                            capture_output=True, timeout=120)
    assert result.returncode == 0 and not result.stderr, result.stderr
    assert not any(marker in result.stdout for marker in
                   (b"\x1b", b"\r", b"[TAF]", b"Diagnostics (", "诊断（".encode("utf-8"))), result.stdout
    replies = [json.loads(line) for line in result.stdout.splitlines()]
    assert len(replies) == 2 and {r["id"] for r in replies} == {1, 2}, replies
    assert all(r.get("jsonrpc") == "2.0" and "error" not in r for r in replies), replies
    reply = next(r["result"] for r in replies if r["id"] == 2)
    assert reply["isError"] is False, reply
    return reply["structuredContent"]


def assert_mcp_doctor_complete(actual, cli, env):
    # For this fixture, diagnostic nulls are Lisp NIL: CLI emits null, MCP false.
    # Translate only the expected projection; never drop fields from the actual.
    def mcp_nil(value):
        if value is None:
            return False
        if isinstance(value, dict):
            return {key: mcp_nil(item) for key, item in value.items()}
        if isinstance(value, list):
            return [mcp_nil(item) for item in value]
        return value

    expected = mcp_nil(cli)
    assert expected.pop("schema_version") == "taffish.doctor/v1", cli
    for key in ("directories", "executables", "paths"):
        assert expected[key] == [], (key, expected[key])
        expected[key] = False
    expected["taffish_container_backend"] = env.get("TAFFISH_CONTAINER_BACKEND", False)
    # Canonical JSON preserves bool/null/number types as well as every nested
    # evidence, inspection, issue, path and remediation field and array entry.
    assert json.dumps(actual, sort_keys=True) == json.dumps(expected, sort_keys=True), (
        "MCP doctor differs from the complete CLI projection", actual, expected)


def add_package(index, name):
    parent = ROOT / name
    parent.mkdir()
    probe("new", name, "--flow", "--version", "2.0.0-a.7.10", cwd=parent)
    record = dict(index["packages"]["order-demo"]["versions"][LATEST])
    record.update(name=name, repository_url="https://github.com/taffish/" + name,
                  command={"name": "taf-" + name}, source={"local_path": str(parent / name)})
    index["packages"][name] = {"latest": LATEST, "versions": {LATEST: record},
                              "repository_url": record["repository_url"], "command": record["command"]}
    save(index)


def legacy_batch():
    index, _ = fixture()
    install(LATEST)
    manifest().unlink()
    before = inventory()
    add_package(index, "fresh-demo")
    result = probe("install", "--all", "--yes")
    assert "manifest-missing" in result.stdout and "order-demo" in result.stdout, result.stdout
    assert (HOME / "apps/fresh-demo" / LATEST / "install.json").is_file()
    after = inventory()
    assert all(after[key] == value for key, value in before.items() if not key.startswith("index/"))
    assert not manifest().exists()
    before = inventory()
    data = doctor("hub", "order-demo")
    assert inspections(data)["order-demo"]["state"] == "unverified", data
    assert "manifest-missing" in {i["code"] for i in issues(data)}
    assert before == inventory()
    for args in (("install", "--all"), ("outdated",), ("upgrade",)):
        data = json.loads(probe(*args, "--json").stdout)
        selected = next(i for i in data["items"] if i["package_name"] == "order-demo")
        assert selected["status"] == "current" and selected["validation"]["state"] == "unverified", selected


def legacy_prune():
    fixture()
    install(OLD)
    manifest(OLD).unlink()
    probe("upgrade", "--yes", "--prune-old")
    assert (HOME / "apps/order-demo" / OLD / "install.json").is_file()
    before = inventory()
    probe("prune", "--yes")
    assert before == inventory()
    manifest().unlink()
    before = inventory()
    probe("install", "--all", "--yes", "--prune-old")
    assert before == inventory(), "prune trusted an unverified retained version"


def corruption():
    index, _ = fixture()
    install(LATEST)
    record = app_record()
    snapshot = manifest().parent
    for path in (Path(record["command_file"]), Path(record["launcher_file"]),
                 snapshot / "src/main.taf", snapshot / "docs/help.md"):
        content, mode = path.read_bytes(), path.stat().st_mode
        path.unlink()
        try:
            data = doctor("hub", "order-demo", code=1)
            assert inspections(data)["order-demo"]["state"] == "invalid", data
            assert any(i["code"] == "file-missing" and Path(i["path"]).resolve() == path.resolve()
                       for i in issues(data)), data
        finally:
            path.write_bytes(content)
            path.chmod(mode)
    saved = ROOT / "saved-snapshot"
    snapshot.rename(saved)
    try:
        assert inspections(doctor("hub", "order-demo", code=1))["order-demo"]["state"] == "invalid"
    finally:
        saved.rename(snapshot)
    add_package(index, "second-demo")
    probe("install", "second-demo")
    add_package(index, "never-installed")
    for name in ("order-demo", "second-demo"):
        Path(app_record(name=name)["command_file"]).write_text("#!/bin/sh\nexit 0\n")
    before = inventory()
    error = probe("install", "--all", "--yes", code=1)
    assert all(name in error.stderr for name in ("order-demo", "second-demo")), error.stderr
    assert "wrapper-digest" in error.stderr and "--repair --user" in error.stderr, error.stderr
    assert "--user --verbose" in error.stderr and "--json" in error.stderr, error.stderr
    assert "--force" not in error.stderr, error.stderr
    assert not (HOME / "apps/never-installed").exists()
    assert before == inventory(), "blocking diagnosis changed the installation"
    data = json.loads(probe("outdated", "--json").stdout)
    assert all(i["validation"]["state"] == "invalid" for i in data["items"])
    data = doctor("hub", code=1)
    assert {"order-demo", "second-demo"} <= set(inspections(data))
    bad = HOME / "apps/bad-meta/1-r1/install.json"
    bad.parent.mkdir(parents=True)
    bad.write_text("{")
    data = doctor("hub", code=1)
    assert inspections(data)["bad-meta"]["state"] == "invalid", data
    missing = manifest().parent / "src/main.taf"
    manifest().unlink()
    missing.unlink()
    data = doctor("hub", "order-demo", code=1)
    assert inspections(data)["order-demo"]["state"] == "invalid", data


def index_checks():
    index, package = fixture()
    doctor("index")
    before = inventory()
    package["latest"] = "absent-r1"
    save(index)
    data = doctor("index", code=1)
    assert "index-latest" in {i["code"] for i in issues(data)}
    package["latest"] = LATEST
    package["versions"][LATEST]["version_id"] = OLD
    save(index)
    assert "index-record" in {i["code"] for i in issues(doctor("index", code=1))}
    INDEX.write_text("{")
    assert "index-json" in {i["code"] for i in issues(doctor("index", code=1))}
    INDEX.write_text(json.dumps({"schema_version": "future/v2"}))
    assert "index-schema" in {i["code"] for i in issues(doctor("index", code=1))}
    INDEX.unlink()
    data = doctor("index")
    assert data["diagnostic_status"] == "warning"
    assert before.keys() - inventory().keys() == {"index/current.json"}
    for args in (("index", "--init"), ("hub", "--shell", "auto"), ("index", "x"), ("hub", "--repair")):
        probe("doctor", *args, code=1)
    doctor("hub", "missing-app", code=1)


def readonly_localization():
    fixture()
    install(LATEST)
    # Trap all commands a read-only specialized diagnosis must not execute.
    traps = ROOT / "traps"
    traps.mkdir()
    marker = ROOT / "executed"
    for name in ("git", "curl", "gh", "docker", "podman", "apptainer"):
        path = traps / name
        path.write_text(f"#!/bin/sh\ntouch '{marker}'\nexit 97\n")
        path.chmod(0o755)
    altered = dict(ENV, PATH=str(traps) + os.pathsep + ENV["PATH"])
    record = app_record()
    launcher = Path(record["launcher_file"])
    launcher.write_text(f"#!/bin/sh\ntouch '{marker}'\nexit 97\n")
    original_manifest = manifest().read_text()
    value = json.loads(original_manifest)
    value["schema"] = "future/v9"
    manifest().write_text(json.dumps(value))
    before = inventory()
    assert "manifest-schema" in {i["code"] for i in issues(doctor("hub", "order-demo", code=1, env=altered))}
    assert inventory() == before and not marker.exists()
    manifest().write_text(original_manifest)
    manifest().unlink()
    before = inventory()
    en = dict(altered, TAFFISH_LANGUAGE="en")
    zh = dict(altered, TAFFISH_LANGUAGE="zh")
    assert doctor("hub", env=en) == doctor("hub", env=zh), "machine schema changed with language"
    for env, expected in ((en, "unverified"), (zh, "未验证")):
        text = probe("doctor", "hub", env=env).stdout
        assert expected in text and "manifest-missing" in text and "order-demo" in text, text
        assert "--repair --user" in text and "--user --verbose" in text and "--json" in text, text
        assert "--force" not in text, text
    assert before == inventory() and not marker.exists()
    system = doctor("hub", "--system", env=altered)
    assert not inspections(system) and not Path(ENV["TAFFISH_SYSTEM_HOME"]).exists()
    # A private source does not become corrupt just because it is not indexed.
    metadata_file = HOME / "apps/order-demo" / LATEST / "install.json"
    record["origin_kind"] = "local-project"
    metadata_file.write_text(json.dumps(record))
    INDEX.unlink()
    text = probe("doctor", "hub", env=en).stdout
    assert "local project" in text and "private" in text.lower(), text
    assert "--repair" not in text and "--force" not in text, text
    data = doctor("hub", "taf-order-demo-v" + LATEST)
    assert inspections(data)["order-demo"]["source_status"] == "local_project", data


def permissions_and_links():
    fixture()
    install(LATEST)
    file = manifest()
    if os.geteuid() != 0:
        mode = file.stat().st_mode
        file.chmod(0)
        try:
            data = doctor("hub", code=1)
            assert inspections(data)["order-demo"]["state"] == "unknown", data
            assert "read-error" in {i["code"] for i in issues(data)}
        finally:
            file.chmod(mode)
        ancestor = HOME / "apps/order-demo"
        mode = ancestor.stat().st_mode
        ancestor.chmod(0)
        try:
            data = doctor("hub", code=1)
            assert "read-error" in {i["code"] for i in issues(data)}, data
            data = doctor("hub", "taf-order-demo-v" + LATEST, code=1)
            assert "read-error" in {i["code"] for i in issues(data)}, data
        finally:
            ancestor.chmod(mode)
    # Never recurse through an escaping directory symlink.
    outside = ROOT / "outside"
    outside.mkdir()
    (outside / "secret").write_text("must not hash or execute")
    link = file.parent / "src/escape"
    link.symlink_to(outside, target_is_directory=True)
    before = inventory()
    data = doctor("hub", code=1)
    assert "unsafe-path" in {i["code"] for i in issues(data)}, data
    assert before == inventory()
    link.unlink()
    # Metadata and package links are checked before reading their contents.
    metadata = HOME / "apps/order-demo" / LATEST / "install.json"
    original = metadata.read_bytes()
    metadata.unlink()
    metadata.symlink_to(outside / "secret")
    data = doctor("hub", code=1)
    assert "unsafe-path" in {i["code"] for i in issues(data)}, data
    metadata.unlink()
    metadata.write_bytes(original)
    (HOME / "apps/escaped-package").symlink_to(outside, target_is_directory=True)
    data = doctor("hub", code=1)
    assert "unsafe-path" in {i["code"] for i in issues(data)}, data
    assert inspections(data)["order-demo"]["state"] == "verified", data


def mcp_diagnostics():
    fixture()
    install(LATEST)
    manifest().unlink()
    before = inventory()
    requests = [{"jsonrpc": "2.0", "id": 1, "method": "initialize",
                 "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                            "clientInfo": {"name": "doctor-test", "version": "1"}}}]
    for i, args in enumerate(({"check": "hub", "targets": ["order-demo"]},
                              {"check": "index"}, {"check": "index", "targets": ["bad"]}), 2):
        requests.append({"jsonrpc": "2.0", "id": i, "method": "tools/call",
                         "params": {"name": "taffish_check_environment", "arguments": args}})
    result = subprocess.run([os.environ["TAFFISH_MCP_BIN"]], env=ENV, text=True,
                            input="".join(json.dumps(x) + "\n" for x in requests),
                            capture_output=True, timeout=120)
    assert result.returncode == 0, result.stderr
    replies = {x["id"]: x for x in map(json.loads, result.stdout.splitlines())}
    data = replies[2]["result"]["structuredContent"]
    assert not replies[2]["result"].get("isError"), replies[2]
    assert data["check"] == "hub" and data["exit_code"] == 0, data
    assert inspections(data)["order-demo"]["state"] == "unverified"
    assert replies[3]["result"]["structuredContent"]["check"] == "index"
    assert replies[4]["result"]["isError"] is True
    assert before == inventory()


def metadata_paths():
    fixture()
    install(OLD)
    install(LATEST)
    metadata = HOME / "apps/order-demo" / OLD / "install.json"
    original = metadata.read_bytes()
    sentinel = ROOT / "unrelated/keep"
    sentinel.parent.mkdir()
    sentinel.write_text("keep")
    for key in ("install_root", "source_dir", "bin_dir", "command_file",
                "launcher_file", "command_launcher_file"):
        record = json.loads(original)
        record[key] = str(sentinel.parent)
        metadata.write_text(json.dumps(record))
        before = inventory()
        data = doctor("hub", code=1)
        assert "metadata-path" in {i["code"] for i in issues(data)}, (key, data)
        for args in (("prune",), ("prune", "--yes"),
                     ("install", "--all", "--yes", "--prune-old")):
            result = json.loads(probe(*args, "--json").stdout)
            assert result["schema_version"] == "taffish.package-plan/v1"
            assert sentinel.read_text() == "keep" and inventory() == before, key
        probe("uninstall", "order-demo", OLD, code=1)
        assert sentinel.exists() and inventory() == before
    metadata.write_bytes(original)
    # The selected latest is blocked too, before any batch installation.
    metadata = HOME / "apps/order-demo" / LATEST / "install.json"
    record = app_record()
    record["install_root"] = str(sentinel.parent)
    metadata.write_text(json.dumps(record))
    before = inventory()
    probe("install", "--all", "--yes", code=1)
    assert inventory() == before and sentinel.exists()


def metadata_schema():
    fixture()
    install(OLD)
    install(LATEST)
    metadata = HOME / "apps/order-demo" / LATEST / "install.json"
    record = app_record()
    for schema in ("future/v99", 7, None, False):
        record["schema_version"] = schema
        metadata.write_text(json.dumps(record))
        before = inventory()
        data = doctor("hub", code=1)
        assert "metadata-schema" in {i["code"] for i in issues(data)}, data
        probe("install", "--all", "--yes", code=1)
        probe("prune", "--yes")
        probe("uninstall", "order-demo", LATEST, code=1)
        assert before == inventory()
        text = probe("doctor", "hub", code=1).stdout
        assert "metadata-schema" in text and "unknown formats" in text, text
        assert "--user --verbose" in text and "--repair" not in text and "--force" not in text, text
    del record["schema_version"]
    metadata.write_text(json.dumps(record))
    before = inventory()
    assert "metadata-schema-missing" in {i["code"] for i in issues(doctor("hub"))}
    probe("install", "--all", "--yes")
    probe("prune", "--yes")
    assert inventory() == before
    wrapper = Path(record["command_file"])
    saved = wrapper.read_bytes()
    wrapper.write_bytes(saved + b"\n# changed\n")
    data = doctor("hub", code=1)
    assert "wrapper-digest" in {i["code"] for i in issues(data)}, data
    wrapper.write_bytes(saved)
    # Explicit removal of safe legacy records remains supported.
    probe("uninstall", "order-demo", LATEST)
    assert not metadata.exists()


def root_types():
    fixture()
    apps = HOME / "apps"
    doctor("hub")  # Absent apps is a valid empty installation.
    apps.write_text("wrong type")
    data = doctor("hub", code=1)
    assert any(i["code"] == "file-missing" and Path(i["path"]) == apps for i in issues(data)), data
    apps.unlink()
    outside = ROOT / "outside"
    outside.mkdir()
    for target in (outside, ROOT / "absent"):
        apps.symlink_to(target, target_is_directory=True)
        try:
            data = doctor("hub", code=1)
            assert "unsafe-path" in {i["code"] for i in issues(data)}, data
        finally:
            apps.unlink()
    if os.geteuid() != 0:
        apps.mkdir()
        apps.chmod(0)
        try:
            assert "read-error" in {i["code"] for i in issues(doctor("hub", code=1))}
        finally:
            apps.chmod(0o755)


def alias_entries():
    fixture()
    install(OLD)
    install(LATEST)
    assert not any(d["id"] == "hub_command" for d in doctor("hub")["diagnostics"])
    doctor("hub", "taf-order-demo-v" + OLD)  # Old artifacts do not own the shared alias.
    alias = Path(app_record()["command_launcher_file"])
    original = alias.read_bytes()
    for state in ("missing", "wrong-target"):
        if state == "missing":
            alias.unlink()
        else:
            alias.write_text("#!/bin/sh\nexit 93\n")
            alias.chmod(0o755)
        before = inventory()
        for language in ("en", "zh"):
            data = doctor("hub", env=dict(ENV, TAFFISH_LANGUAGE=language))
            assert all(d["inspection"]["state"] == "verified" for d in data["diagnostics"]
                       if d["id"] == "hub_installation"), data
            warning = next(d for d in data["diagnostics"] if d["id"] == "hub_command")
            assert warning["status"] == "warning" and warning["inspection"]["state"] == "unverified"
            if state == "missing":
                mcp = mcp_check({"check": "hub"}, dict(ENV, TAFFISH_LANGUAGE=language))
                assert mcp["exit_code"] == data["exit_code"] == 0
                states = lambda value: sorted((d["id"], d["inspection"]["state"])
                                              for d in value["diagnostics"])
                assert states(mcp) == states(data), mcp
                assert sorted(i["code"] for i in issues(mcp)) == sorted(i["code"] for i in issues(data))
        assert before == inventory(), "diagnosis rewrote alias"
    alias.write_bytes(original)
    assert not any(d["id"] == "hub_command" for d in doctor("hub")["diagnostics"])


def applied_json():
    fixture()
    result = json.loads(probe("install", "--all", "--yes", "--json").stdout)
    assert result["dry_run"] is False and result["prune_result"] is None
    assert result["items"][0]["install_result"]["dry_run_p"] is False, result
    assert (HOME / "apps/order-demo" / LATEST / "install.json").exists()
    install(OLD)
    result = json.loads(probe("prune", "--yes", "--json").stdout)
    removed = result["items"][0]["removed"][0]
    assert removed["install_root_deleted_p"] is True, result
    assert not (HOME / "apps/order-demo" / OLD).exists()
    for command in ("upgrade", "install"):
        probe("uninstall", "order-demo", LATEST)
        install(OLD)
        result = json.loads(probe(command, "--all", "--yes", "--prune-old", "--json").stdout)
        assert result["items"][0]["install_result"]["dry_run_p"] is False, result
        assert result["prune_result"]["items"][0]["removed"][0]["install_root_deleted_p"] is True
        assert not (HOME / "apps/order-demo" / OLD).exists()
        assert (HOME / "apps/order-demo" / LATEST / "install.json").exists()


def tree_state(root):
    """Include directories and link identities, not just regular-file contents."""
    result = {}
    for path in root.rglob("*"):
        mode = path.lstat().st_mode
        if path.is_symlink():
            value = ("link", mode, os.readlink(path))
        elif path.is_dir():
            value = ("directory", mode)
        else:
            value = ("file", mode, hashlib.sha256(path.read_bytes()).hexdigest())
        result[path.relative_to(root).as_posix()] = value
    return result


def assert_summary_counts(text, packages, identities, issue_count, scope="user"):
    headers = [line for line in text.splitlines()
               if line.startswith(("Diagnostics (", "诊断（"))]
    assert len(headers) == 1, text
    assert scope in headers[0], headers[0]
    assert list(map(int, re.findall(r"\d+", headers[0]))) == [packages, identities, issue_count], headers[0]


def assert_summary_group(text, code, count):
    lines = text.splitlines()
    matches = [i for i, line in enumerate(lines) if line.strip().startswith(code + " [")]
    assert len(matches) == 1, (code, text)
    counts = re.findall(r"\d+", lines[matches[0] + 1])
    assert counts and int(counts[0]) == count, (code, text)


def summary_scale(count):
    index, package = fixture()
    install(LATEST)
    manifest().unlink()
    seed = HOME / "apps/order-demo" / LATEST
    payload = [(p.relative_to(seed).as_posix(), p.read_text(), p.stat().st_mode)
               for p in seed.rglob("*") if p.is_file()]
    launchers = [(p.name, p.read_text(), p.stat().st_mode)
                 for p in (HOME / "bin").iterdir() if p.is_file()]
    names = {"order-demo"}
    for i in range(count - 1):
        name = f"bulk-{i:03d}"
        names.add(name)
        for relative, text, mode in payload:
            path = HOME / "apps" / name / LATEST / relative.replace("order-demo", name)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text.replace("order-demo", name), encoding="utf-8")
            path.chmod(mode & 0o777)
        for relative, text, mode in launchers:
            path = HOME / "bin" / relative.replace("order-demo", name)
            path.write_text(text.replace("order-demo", name), encoding="utf-8")
            path.chmod(mode & 0o777)
        index["packages"][name] = json.loads(json.dumps(package).replace("order-demo", name))
    save(index)
    before = tree_state(ROOT)
    reports = []
    for language in ("en", "zh"):
        env = dict(ENV, TAFFISH_LANGUAGE=language)
        text = probe("doctor", "hub", env=env).stdout
        assert_summary_counts(text, count, count, count)
        assert_summary_group(text, "manifest-missing", count)
        assert len(text.splitlines()) <= 24, text
        assert set(re.findall(r"bulk-\d{3}", text)) == {"bulk-000", "bulk-001", "bulk-002"}, text
        assert "order-demo" not in text and "--force" not in text, text
        assert text.count("--repair") == 1 and "--user --verbose" in text and "--json" in text, text
        detail = probe("doctor", "hub", "--verbose", env=env).stdout
        data = doctor("hub", env=env)
        reports.append(data)
        rows = [d["inspection"] for d in data["diagnostics"] if d["id"] == "hub_installation"]
        assert len(rows) == count and {r["package_name"] for r in rows} == names, data
        assert len(issues(data)) == count and all(r["state"] == "unverified" for r in rows), data
        for row in rows:
            assert row["version_id"] == LATEST and len(row["issues"]) == 1, row
            assert row["package_name"] in detail and row["issues"][0]["path"] in detail, row
            assert row["issues"][0]["code"] == "manifest-missing", row
        if count == 211:
            machine = mcp_check({"check": "hub"}, env)
            assert_mcp_doctor_complete(machine, data, env)
            assert before == tree_state(ROOT), "MCP summary check changed the existing 211-app fixture"
        maintenance = probe("install", "--all", "--yes", env=env).stdout
        assert_summary_counts(maintenance, count, count, count)
        assert_summary_group(maintenance, "manifest-missing", count)
        assert len(maintenance.splitlines()) <= 35, maintenance
        assert len(set(re.findall(r"bulk-\d{3}", maintenance))) <= 3, maintenance
        plan = json.loads(probe("install", "--all", "--json", env=env).stdout)
        assert len(plan["items"]) == count and plan["summary"]["skip"] == count, plan
        assert all(item["validation"]["state"] == "unverified" for item in plan["items"]), plan
        assert before == tree_state(ROOT), "summary/detail/JSON or no-op install changed fixture"
    assert reports[0] == reports[1], "summary localization changed complete machine evidence"


def summary_mixed():
    index, _ = fixture()
    install(OLD)
    install(LATEST)
    manifest().unlink()
    Path(app_record(OLD)["command_file"]).write_text("corrupt", encoding="utf-8")
    for name in ("private-demo", "future-demo", "unsafe-demo"):
        add_package(index, name)
        probe("install", name)
    private_file = HOME / "apps/private-demo" / LATEST / "install.json"
    private = app_record(name="private-demo")
    private["origin_kind"] = "local-project"
    private_file.write_text(json.dumps(private), encoding="utf-8")
    manifest(name="private-demo").unlink()
    Path(private["command_launcher_file"]).unlink()
    future_file = HOME / "apps/future-demo" / LATEST / "install.json"
    future = app_record(name="future-demo")
    future["schema_version"] = "future/v99"
    future_file.write_text(json.dumps(future), encoding="utf-8")
    sentinel = ROOT / "outside/keep"
    sentinel.parent.mkdir()
    sentinel.write_text("unchanged", encoding="utf-8")
    unsafe_file = HOME / "apps/unsafe-demo" / LATEST / "install.json"
    unsafe = app_record(name="unsafe-demo")
    unsafe["install_root"] = str(sentinel.parent)
    unsafe_file.write_text(json.dumps(unsafe), encoding="utf-8")
    add_package(index, "never-installed")
    before = tree_state(ROOT)
    reports = []
    for language in ("en", "zh"):
        env = dict(ENV, TAFFISH_LANGUAGE=language)
        data = doctor("hub", code=1, env=env)
        reports.append(data)
        all_issues = issues(data)
        assert len(all_issues) == 7, all_issues
        expected_codes = {"manifest-missing", "wrapper-digest", "metadata-schema", "metadata-path", "alias-missing"}
        assert {issue["code"] for issue in all_issues} == expected_codes, all_issues
        text = probe("doctor", "hub", code=1, env=env).stdout
        assert_summary_counts(text, 4, 5, 7)
        assert len(text.splitlines()) <= 40, text
        assert all(code in text for code in expected_codes), text
        detail = probe("doctor", "hub", "--verbose", code=1, env=env).stdout
        assert all(issue["path"] in detail for issue in all_issues), detail
        for args in (("install", "--all", "--yes"), ("upgrade", "--yes")):
            error = probe(*args, code=1, env=env).stderr
            assert "metadata-schema" in error and "metadata-path" in error, error
            assert "--user --verbose" in error and "--force" not in error, error
            assert "--repair" not in error, error
            assert before == tree_state(ROOT), "blocked plan modified files or created directories"
        assert not (HOME / "apps/never-installed").exists() and sentinel.read_text() == "unchanged"
    assert reports[0] == reports[1]


CASES = {"summary-211": lambda: summary_scale(211), "summary-300": lambda: summary_scale(300),
         "summary-mixed": summary_mixed,
         "metadata-paths": metadata_paths, "metadata-schema": metadata_schema,
         "root-types": root_types, "alias-entries": alias_entries, "applied-json": applied_json,
         "legacy-batch": legacy_batch, "legacy-prune": legacy_prune, "corruption": corruption,
         "index": index_checks, "readonly": readonly_localization,
         "permissions-links": permissions_and_links, "mcp": mcp_diagnostics}
CASES[sys.argv[1]]()
