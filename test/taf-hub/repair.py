#!/usr/bin/env python3
"""Offline repair contracts. Only isolated homes and local committed Git fixtures.

Run through test/run-tests.sh --filter taf-hub/repair- with candidate binaries.
No repository publication, network transport, container or real installation is used.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile


OLD = "1.0.0-r1"
LATEST = "1.1.0-r1"
ALPHA = "repair-alpha"
BETA = "repair-beta"
TIMEOUT = 120


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def fingerprint(root, *, identity=True, directory_times=False):
    """Do not follow links. Identity also catches rewriting identical live files."""
    result = {}

    def visit(path):
        if not os.path.lexists(path):
            return
        info = path.lstat()
        key = "." if path == root else path.relative_to(root).as_posix()
        if stat.S_ISLNK(info.st_mode):
            value = ("link", os.readlink(path))
        elif stat.S_ISDIR(info.st_mode):
            value = ("directory",)
        else:
            assert stat.S_ISREG(info.st_mode), ("unexpected fixture file type", path)
            value = ("file", hashlib.sha256(path.read_bytes()).hexdigest())
        result[key] = (info.st_mode, *value)
        if identity:
            # Directory mtime changes when transaction siblings are created/removed.
            timestamp = info.st_mtime_ns if directory_times or not stat.S_ISDIR(info.st_mode) else None
            result[key] += (info.st_ino, timestamp)
        if stat.S_ISDIR(info.st_mode):
            for child in sorted(path.iterdir()):
                visit(child)

    visit(root)
    return result


def validate_public_result(data, *, dry):
    assert data["schema_version"] == "taffish.repair-plan/v1", data
    assert data["operation"] == "repair" and data["scope"] == "user", data
    assert data["dry_run_p"] is dry, data
    assert isinstance(data["items"], list), data
    if dry:
        assert data.get("applied", []) == [], "preview reported an applied transaction"


def validate_plan(data, expected, *, dry=True, absent=0):
    """Expected identities/actions/reasons come from each fixed fixture, not the result."""
    validate_public_result(data, dry=dry)
    items = {item["package_name"]: item for item in data["items"]}
    assert len(items) == len(data["items"]) and set(items) == set(expected), data
    counts = {"total": len(expected), "repair": 0, "skip": 0, "blocked": 0,
              "skipped_not_installed": absent}
    for name, (version, action, reason) in expected.items():
        item = items[name]
        assert item["version_id"] == version, item
        assert item["action"] == action and item["reason"] == reason, item
        assert item["blocked_p"] is (action == "blocked"), item
        counts[action] += 1
    for key, expected_value in counts.items():
        assert type(data["summary"][key]) is int and data["summary"][key] == expected_value, data
    applied = data.get("applied", [])
    applied_count = 0 if dry else counts["repair"]
    assert isinstance(applied, list) and len(applied) == applied_count, data
    return items


def validate_repair_error(result, reason, *, transaction=False):
    assert result.returncode == 1, result
    assert f"[{reason}]" in result.stderr, result.stderr
    for parser_message in ("only supported with --all", "Unknown option", "unknown option",
                           "can't be used together", "Usage:"):
        assert parser_message not in result.stderr, result.stderr
    if transaction:
        assert "[repair-failed]" in result.stderr, result.stderr
        assert "Repair stopped after 0 completed targets" in result.stderr, result.stderr
    else:
        assert "Repair blocked before changes." in result.stderr, result.stderr


class Fixture:
    def __init__(self, case):
        self.root = (Path(os.environ["TAFFISH_TEST_TMP_ROOT"]) / ("hub-repair-" + case)).resolve()
        self.root.mkdir(parents=True)  # Never overwrite a previous run's evidence.
        self.home = self.root / "user-home"
        self.system = self.root / "system-home"
        self.logs = self.root / "logs"
        self.sentinel = self.root / "unrelated"
        for path in (self.home, self.system, self.logs, self.sentinel, self.root / "os-home"):
            path.mkdir()
        (self.sentinel / "keep").write_text("not a TAFFISH installation\n", encoding="utf-8")
        self.taf = os.environ["TAF_BIN"]
        self.git = shutil.which("git")
        assert self.git, "git is required for the real local commit/tag fixtures"
        self.env = dict(os.environ)
        for key in list(self.env):
            if key.startswith("GIT_") or key in ("TAFFISH_INDEX_URL", "TAFFISH_SOURCE_DIR",
                                                  "TAFFISH_ENV", "TAFFISH_NAME"):
                self.env.pop(key)
        self.env.update(
            HOME=str(self.root / "os-home"), XDG_CONFIG_HOME=str(self.root / "os-home/.config"),
            TAFFISH_USER_HOME=str(self.home), TAFFISH_SYSTEM_HOME=str(self.system),
            TAFFISH_SYSTEM_BIN_DIR=str(self.root / "system-bin"), TAFFISH_CONFIG="",
            TAFFISH_LANGUAGE="en", TAF_HISTORY_MODE="off", TAFFISH=os.environ["TAFFISH_BIN"],
            GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=str(self.root / "gitconfig"),
            GIT_ALLOW_PROTOCOL="file", GIT_TERMINAL_PROMPT="0", GH_PROMPT_DISABLED="1",
            GIT_AUTHOR_DATE="2026-01-01T00:00:00+00:00", GIT_COMMITTER_DATE="2026-01-01T00:00:00+00:00")
        self.env["PATH"] = os.pathsep.join((str(self.home / "bin"), str(Path(self.taf).parent), self.env["PATH"]))
        (self.root / "gitconfig").write_text("", encoding="utf-8")
        self.index_path = self.home / "index/current.json"
        self.index_path.parent.mkdir()
        self.index = {"schema_version": "taffish.index/v1", "packages": {}, "commands": {}}
        self.installed = []
        self.sequence = 0
        self.save()

    def command(self, args, *, cwd=None, code=0, request=None):
        self.sequence += 1
        stem = self.logs / f"{self.sequence:03d}"
        write_json(stem.with_suffix(".command.json"), list(map(str, args)))
        result = subprocess.run(args, env=self.env, cwd=cwd, input=request,
                                capture_output=True, text=True, encoding="utf-8", timeout=TIMEOUT)
        stem.with_suffix(".stdout").write_text(result.stdout, encoding="utf-8")
        stem.with_suffix(".stderr").write_text(result.stderr, encoding="utf-8")
        assert result.returncode == code, (args, result.returncode, code, str(stem), result.stderr[-3000:])
        return result

    def cli(self, *args, **kwargs):
        return self.command([self.taf, *args], **kwargs)

    def git_command(self, *args, cwd=None):
        return self.command([self.git, "-c", "user.name=Repair Fixture", "-c",
                             "user.email=repair@example.invalid", "-c", "commit.gpgSign=false",
                             "-c", "tag.gpgSign=false", "-c", "core.hooksPath=/dev/null", *args], cwd=cwd)

    def save(self):
        write_json(self.index_path, self.index)

    def add(self, name=ALPHA, versions=(LATEST,)):
        parent = self.root / "repositories"
        parent.mkdir(exist_ok=True)
        first_version = versions[0].rsplit("-r", 1)[0]
        repository_identity = f"https://example.invalid/taffish/{name}"
        self.cli("new", name, "--flow", "--version", first_version, "--release", "1",
                 "--repo", repository_identity, cwd=parent)
        repository = parent / name
        self.git_command("init", "--quiet", cwd=repository)
        records = {}
        previous_version = first_version
        for identity in versions:
            version = identity.rsplit("-r", 1)[0]
            config = repository / "taffish.toml"
            text = config.read_text(encoding="utf-8")
            needle = f'version = "{previous_version}"'
            assert text.count(needle) == 1, text
            config.write_text(text.replace(needle, f'version = "{version}"'), encoding="utf-8")
            (repository / "src/main.taf").write_text(self.source_text(name, identity), encoding="utf-8")
            self.git_command("add", "--all", cwd=repository)
            self.git_command("commit", "--quiet", "-m", "Fixture " + identity, cwd=repository)
            self.git_command("tag", "v" + identity, cwd=repository)
            commit = self.git_command("rev-parse", "HEAD", cwd=repository).stdout.strip()
            assert re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", commit), commit
            checkout = self.root / "sources" / name / identity
            checkout.parent.mkdir(parents=True, exist_ok=True)
            self.git_command("clone", "--quiet", "--no-local", "--no-checkout", str(repository), str(checkout))
            self.git_command("checkout", "--quiet", "--detach", commit, cwd=checkout)
            assert self.git_command("rev-parse", "v" + identity, cwd=checkout).stdout.strip() == commit
            assert not self.git_command("status", "--porcelain", cwd=checkout).stdout
            records[identity] = {
                "name": name, "kind": "flow", "version": version, "release": 1,
                "version_id": identity, "tag": "v" + identity, "license": "Apache-2.0",
                "repository_url": repository_identity, "command": {"name": "taf-" + name},
                "paths": {"main": "src/main.taf", "help": "docs/help.md"},
                "source": {"local_path": str(checkout), "repository_url": repository.as_uri(),
                           "ref": "v" + identity, "commit": commit}}
            previous_version = version
        self.index["packages"][name] = {
            "latest": versions[-1], "repository_url": repository_identity,
            "command": {"name": "taf-" + name}, "versions": records}
        self.save()

    @staticmethod
    def source_text(name, identity):
        return f"<taffish>\necho '{name} {identity}'\n"

    def record(self, name=ALPHA, identity=LATEST):
        return self.index["packages"][name]["versions"][identity]

    def install(self, name=ALPHA, identity=LATEST):
        self.cli("install", name, identity)
        self.installed.append((name, identity))
        self.verified(name, identity)

    def install_root(self, name=ALPHA, identity=LATEST):
        return self.home / "apps" / name / identity

    def metadata_path(self, name=ALPHA, identity=LATEST):
        return self.install_root(name, identity) / "install.json"

    def metadata(self, name=ALPHA, identity=LATEST):
        return json.loads(self.metadata_path(name, identity).read_text(encoding="utf-8"))

    def manifest(self, name=ALPHA, identity=LATEST):
        metadata = self.metadata(name, identity)
        return Path(metadata["command_file"]).parent / ("." + metadata["artifact_name"]) / ".taf-build.json"

    def state(self):
        return {str(path): fingerprint(path, directory_times=True)
                for path in (self.home, self.system, self.root / "system-bin", self.sentinel)}

    def live_state(self):
        # Failed apply may leave recovery materials, but cannot modify live payloads.
        paths = [self.install_root(name, identity) for name, identity in self.installed]
        for name, identity in self.installed:
            paths.extend((self.home / "bin" / ("taf-" + name),
                          self.home / "bin" / f"taf-{name}-v{identity}"))
        paths.extend((self.system, self.sentinel))
        return {str(path): fingerprint(path) for path in paths}

    def repair_json(self, *args, dry, expected=None, absent=0):
        assert "--all" in args or "--all-installed" in args, "install --json requires a batch selector"
        result = self.cli("install", "--repair", "--json", *args)
        assert not result.stderr, result.stderr
        data = json.loads(result.stdout)
        validate_public_result(data, dry=dry)
        if expected is not None:
            validate_plan(data, expected, dry=dry, absent=absent)
        return data

    def plan(self, *args, dry=True, expected=None, absent=0):
        return self.repair_json("--all", *args, dry=dry, expected=expected, absent=absent)

    def repair_targets(self, *targets, dry, expected):
        assert all(not arg.startswith("--") for arg in targets), targets
        result = self.cli("install", "--repair", *targets, *(("--dry-run",) if dry else ()))
        counts = {action: sum(item[1] == action for item in expected.values())
                  for action in ("repair", "skip", "blocked")}
        summary = (f"Repair plan: {len(expected)} installed targets; {counts['repair']} rebuild, "
                   f"{counts['skip']} unchanged, {counts['blocked']} blocked; 0 absent targets skipped.")
        assert summary in result.stdout, result.stdout
        assert ("Preview only." in result.stdout) is dry, result.stdout
        for name, (version, action, reason) in expected.items():
            if action != "skip":
                assert f"{name} {version}" in result.stdout and f"[{reason}]" in result.stdout, result.stdout
        return result

    def repair_failure(self, *targets, reason):
        result = self.cli("install", "--repair", *targets, code=1)
        validate_repair_error(result, reason)
        return result

    def transaction_failure(self, reason, *, checkout=False):
        before = set((self.home / ".repair").glob("*/journal.json"))
        trace = self.logs / "transaction-git.trace"
        assert not trace.exists()
        self.env["GIT_TRACE"] = str(trace)
        try:
            result = self.cli("install", "--repair", ALPHA, code=1)
        finally:
            self.env.pop("GIT_TRACE")
        validate_repair_error(result, reason, transaction=True)
        journals = set((self.home / ".repair").glob("*/journal.json")) - before
        assert len(journals) == 1, "failed repair never entered a real transaction"
        journal_path = journals.pop()
        journal = json.loads(journal_path.read_text(encoding="utf-8"))
        assert journal["schema"] == "taffish.repair/v1", journal
        assert journal["package"] == ALPHA and journal["version_id"] == LATEST, journal
        assert journal["source_commit"] == self.record()["source"]["commit"], journal
        assert journal["status"] == journal["phase"] == "failed-before-switch", journal
        assert f"[{reason}]" in journal["failure"], journal
        stage = Path(journal["stage-root"])
        assert stage.resolve() == journal_path.parent / "stage-root" and stage.is_dir(), journal
        assert journal["old_root_moved"] in (False, None) and journal["new_root_placed"] in (False, None), journal
        assert not Path(journal["backup-root"]).exists(), journal
        git_trace = trace.read_text(encoding="utf-8")
        assert "built-in: git clone " in git_trace, git_trace
        if checkout:
            assert (stage / "source/.git").is_dir(), "fixed-commit test never cloned the source"
            assert "checkout --detach " + self.record()["source"]["commit"] in git_trace, git_trace

    def unchanged(self, before):
        assert self.state() == before, "repair preflight/dry-run/healthy skip wrote to managed homes or sentinel"

    def blocked(self, reason, name=ALPHA):
        before = self.state()
        data = self.plan()
        item = next(item for item in data["items"] if item["package_name"] == name)
        assert item["action"] == "blocked" and item["blocked_p"] is True, item
        assert item["reason"] == reason, item
        self.unchanged(before)
        self.repair_targets(name, dry=True, expected={name: (LATEST, "blocked", reason)})
        self.unchanged(before)
        self.repair_failure(name, reason=reason)
        self.unchanged(before)

    def verified(self, name=ALPHA, identity=LATEST):
        artifact = f"taf-{name}-v{identity}"
        result = self.cli("doctor", "hub", artifact, "--json")
        data = json.loads(result.stdout)
        installs = [d["inspection"] for d in data["diagnostics"] if d["id"] == "hub_installation"]
        assert len(installs) == 1 and installs[0]["state"] == "verified", data
        metadata = self.metadata(name, identity)
        commit = self.record(name, identity)["source"]["commit"]
        assert metadata["source_commit"] == metadata["source_commit_actual"] == commit, metadata
        assert metadata["source_commit_verified"] is True, metadata
        root = self.install_root(name, identity)
        assert Path(metadata["install_root"]).resolve() == root
        for key in ("source_dir", "command_file"):
            assert Path(metadata[key]).resolve().is_relative_to(root), (key, metadata)
        manifest_path = self.manifest(name, identity)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        assert manifest["wrapper_sha256"] == hashlib.sha256(Path(metadata["command_file"]).read_bytes()).hexdigest()
        assert (manifest_path.parent / "src/main.taf").read_text(encoding="utf-8") == self.source_text(name, identity)
        launcher = self.home / "bin" / artifact
        assert Path(metadata["launcher_file"]) == launcher and launcher.is_file(), metadata
        result = self.command([str(launcher)])
        assert result.stdout.strip() == f"{name} {identity}", result.stdout


def seeded(case, *, versions=(LATEST,)):
    fixture = Fixture(case)
    fixture.add(versions=versions)
    for identity in versions:
        fixture.install(identity=identity)
    return fixture


def conflicts():
    f = seeded("conflicts")
    before = f.state()
    # Public core projections do not broaden the existing CLI flag contract.
    for mode in ((), ("--repair",)):
        for target in ((ALPHA,), (ALPHA, LATEST), (f"taf-{ALPHA}-v{LATEST}",)):
            for option in ("--json", "--yes"):
                rejected = f.cli("install", *mode, *target, option, code=1)
                assert "--json and --yes require --all or --all-installed --repair" in rejected.stderr, rejected.stderr
                f.unchanged(before)
    for arguments, left, right in (
            ((ALPHA, "--force"), "--repair", "--force"),
            (("--from", f.record()["source"]["local_path"]), "--repair", "--from"),
            (("--all", "--prune-old"), "--repair", "--prune-old"),
            (("--all", "--yes", "--dry-run"), "--dry-run", "--yes")):
        rejected = f.cli("install", "--repair", *arguments, code=1)
        assert f"{left} and {right} can't be used together." in rejected.stderr, rejected.stderr
        f.unchanged(before)


def healthy():
    f = seeded("healthy")
    before = f.state()
    expected = {ALPHA: (LATEST, "skip", "already-verified")}
    f.plan(expected=expected)
    f.unchanged(before)
    f.repair_targets(ALPHA, dry=True, expected=expected)
    f.unchanged(before)
    f.repair_targets(ALPHA, dry=False, expected=expected)
    f.unchanged(before)
    f.plan("--yes", dry=False, expected=expected)
    f.unchanged(before)


def legacy():
    f = seeded("legacy")
    f.manifest().unlink()
    metadata = f.metadata()
    for key in ("schema_version", "source_commit", "source_commit_actual", "source_commit_verified"):
        metadata.pop(key, None)
    write_json(f.metadata_path(), metadata)
    before = f.state()
    expected = {ALPHA: (LATEST, "repair", "rebuild-required")}
    plan = f.plan(expected=expected)
    assert plan["items"][0]["validation"]["state"] == "unverified", plan
    f.unchanged(before)
    f.repair_targets(ALPHA, dry=True, expected=expected)
    f.unchanged(before)
    assert not f.manifest().exists(), "dry-run invented a legacy manifest"
    f.repair_targets(ALPHA, dry=False, expected=expected)
    f.verified()
    repaired = f.state()
    f.repair_targets(ALPHA, dry=False, expected={ALPHA: (LATEST, "skip", "already-verified")})
    f.unchanged(repaired)


def corruption():
    f = seeded("corruption")
    Path(f.metadata()["command_file"]).write_text("#!/bin/sh\nexit 23\n", encoding="utf-8")
    (f.manifest().parent / "src/main.taf").write_text("damaged source\n", encoding="utf-8")
    before = f.state()
    plan = f.plan(expected={ALPHA: (LATEST, "repair", "rebuild-required")})
    assert plan["items"][0]["validation"]["state"] == "invalid", plan
    f.unchanged(before)
    applied = f.plan("--yes", dry=False, expected={ALPHA: (LATEST, "repair", "rebuild-required")})
    assert isinstance(applied.get("applied"), list) and len(applied["applied"]) == 1, applied
    f.verified()


def commit_conflict():
    f = seeded("commit-conflict")
    f.manifest().unlink()
    f.record()["source"]["commit"] = "1" * 40
    f.save()
    f.blocked("source-commit-conflict")


def fixed_commit():
    f = seeded("fixed-commit")
    f.manifest().unlink()
    original = copy.deepcopy(f.record()["source"])
    f.record()["source"].pop("commit")
    f.save()
    f.blocked("missing-fixed-commit")
    # Matching declarations are insufficient: this commit is absent from the real repo.
    f.record()["source"] = dict(original, commit="1" * 40)
    metadata = f.metadata()
    metadata["source_commit"] = "1" * 40
    metadata.pop("source_commit_actual", None)
    metadata.pop("source_commit_verified", None)
    write_json(f.metadata_path(), metadata)
    f.save()
    f.plan(expected={ALPHA: (LATEST, "repair", "rebuild-required")})
    before = f.live_state()
    f.transaction_failure("source-fetch-failed", checkout=True)
    assert f.live_state() == before, "fixed-commit failure changed the old installation"
    assert not f.manifest().exists(), "repair accepted a tag/HEAD in place of the pinned commit"


def source_unavailable():
    f = seeded("source-unavailable")
    f.manifest().unlink()
    before = f.state()
    f.plan(expected={ALPHA: (LATEST, "repair", "rebuild-required")})
    f.unchanged(before)
    source = Path(f.record()["source"]["local_path"])
    source.rename(source.with_name(source.name + "-unavailable"))
    # An existing but no-longer-available Git repository gets past path preflight
    # and must fail in real `git clone`, not in argument parsing or source guards.
    source.mkdir()
    repository = f.root / "repositories" / ALPHA
    repository.rename(repository.with_name(ALPHA + "-unavailable"))
    live = f.live_state()
    f.transaction_failure("source-fetch-failed")
    assert f.live_state() == live, "offline source/fetch failure changed the old installation"


def blocked_private():
    f = seeded("blocked-private")
    original = f.metadata()
    for kind in ("local-project", "unknown", None):
        write_json(f.metadata_path(), dict(original, origin_kind=kind))
        f.blocked("private-or-unknown-source")
    write_json(f.metadata_path(), dict(original, repository_url=(f.sentinel / "private.git").as_uri()))
    f.blocked("source-conflict")


def blocked_schema():
    f = seeded("blocked-schema")
    original = f.metadata()
    write_json(f.metadata_path(), dict(original, schema_version="taffish.install/future"))
    f.blocked("unknown-schema")
    write_json(f.metadata_path(), original)
    manifest = json.loads(f.manifest().read_text(encoding="utf-8"))
    manifest["schema"] = "taffish.build/future"
    write_json(f.manifest(), manifest)
    Path(original["command_file"]).unlink()  # Missing wrapper must not hide the future schema.
    f.blocked("unknown-schema")


def blocked_path():
    f = seeded("blocked-path")
    original = f.metadata()
    write_json(f.metadata_path(), dict(original, command_file=str(f.sentinel / "keep")))
    f.blocked("unsafe-path")
    write_json(f.metadata_path(), original)
    launcher = Path(original["launcher_file"])
    launcher.unlink()
    launcher.symlink_to(f.sentinel / "keep")
    f.blocked("unsafe-path")
    linked = seeded("blocked-bin-link")
    linked.manifest().unlink()
    original_bin = linked.home / "bin"
    external_bin = linked.sentinel / "bin"
    original_bin.rename(external_bin)
    original_bin.symlink_to(external_bin, target_is_directory=True)
    # Canonicalizing a write destination must not erase evidence of its symlink.
    linked.blocked("unsafe-path")


def entry_conflict():
    f = seeded("entry-conflict")
    metadata = f.metadata()
    for key, reason in (("command_launcher_file", "alias-unrecognized"),
                        ("launcher_file", "launcher-unrecognized")):
        path = Path(metadata[key])
        original = path.read_bytes()
        path.write_text("#!/bin/sh\n# unrelated owner\nexit 27\n", encoding="utf-8")
        f.blocked(reason)
        path.write_bytes(original)
    f.add(BETA)
    f.install(BETA)
    other = f.metadata(BETA)
    other["artifact_name"] = metadata["artifact_name"]
    other["command_name"] = metadata["command_name"]
    write_json(f.metadata_path(BETA), other)
    f.blocked("command-conflict")


def exact_old():
    f = seeded("exact-old", versions=(OLD, LATEST))
    f.manifest(identity=OLD).unlink()
    latest = fingerprint(f.install_root())
    alias = f.home / "bin" / ("taf-" + ALPHA)
    alias_bytes = alias.read_bytes()
    before = f.state()
    expected = {ALPHA: (OLD, "repair", "rebuild-required")}
    f.repair_targets(ALPHA, OLD, dry=True, expected=expected)
    f.unchanged(before)
    f.repair_targets(f"taf-{ALPHA}-v{OLD}", dry=False, expected=expected)
    f.verified(identity=OLD)
    assert fingerprint(f.install_root()) == latest, "repair of old version modified index.latest"
    assert alias.read_bytes() == alias_bytes, "old repair rewrote the latest alias target"
    assert f.command([str(alias)]).stdout.strip() == f"{ALPHA} {LATEST}"


def installed_plan(f, *args, dry=True):
    data = f.repair_json("--all-installed", *args, dry=dry)
    assert data["selection"] == "installed-all-versions", data
    items = {(i["package_name"], i["version_id"]): i for i in data["items"]}
    assert len(items) == len(data["items"]) == data["summary"]["total"], data
    for action in ("repair", "skip", "blocked"):
        assert data["summary"][action] == sum(i["action"] == action for i in items.values()), data
    assert data["summary"]["skipped_not_installed"] == 0, data
    return data, items


def installed_history():
    f = seeded("installed-history", versions=(OLD, LATEST))
    f.add(BETA)
    f.manifest(identity=OLD).unlink()
    before = f.state()
    latest_files = fingerprint(f.install_root())
    alias = f.home / "bin" / ("taf-" + ALPHA)
    alias_files = fingerprint(alias)
    legacy = f.plan(expected={ALPHA: (LATEST, "skip", "already-verified")}, absent=1)
    assert legacy["selection"] == "index-latest", legacy
    _, items = installed_plan(f)
    assert set(items) == {(ALPHA, OLD), (ALPHA, LATEST)}, items
    assert items[ALPHA, OLD]["action"] == "repair" and items[ALPHA, LATEST]["action"] == "skip"
    f.unchanged(before)
    applied, _ = installed_plan(f, "--yes", dry=False)
    assert len(applied["applied"]) == 1, applied
    f.verified(identity=OLD)
    assert fingerprint(f.install_root()) == latest_files
    assert fingerprint(alias) == alias_files
    assert not f.install_root(BETA).exists()
    after = f.state()
    plan, _ = installed_plan(f, "--yes", dry=False)
    assert plan["summary"]["repair"] == 0
    f.unchanged(after)


def installed_old_only():
    f = Fixture("installed-old-only")
    f.add(versions=(OLD, LATEST))
    f.add(BETA)
    f.install(identity=OLD)
    f.manifest(identity=OLD).unlink()
    f.record(identity=OLD)["dependencies"] = {BETA: LATEST}
    f.save()
    before = f.state()
    f.plan(expected={}, absent=2)
    _, items = installed_plan(f)
    assert set(items) == {(ALPHA, OLD)}
    f.unchanged(before)
    installed_plan(f, "--yes", dry=False)
    f.verified(identity=OLD)
    assert not f.install_root().exists() and not f.install_root(BETA).exists()
    assert f.command([str(f.home / "bin" / ("taf-" + ALPHA))]).stdout.strip() == f"{ALPHA} {OLD}"


def installed_blocked():
    f = seeded("installed-blocked", versions=(OLD, LATEST))
    f.add(BETA)
    f.install(BETA)
    f.manifest(identity=OLD).unlink()
    broken = f.metadata_path(BETA)
    original = broken.read_bytes()
    for content in (None, b"{invalid-json"):
        if content is None:
            broken.unlink()
        else:
            broken.write_bytes(content)
        before = f.state()
        plan, items = installed_plan(f)
        assert len(items) == 3 and items[BETA, LATEST]["action"] == "blocked", plan
        f.cli("install", "--all-installed", "--repair", "--yes", code=1)
        f.unchanged(before)
        broken.write_bytes(original)
    for mode, reason in (("unindexed", "index-target-invalid"),
                         ("private", "private-or-unknown-source"),
                         ("schema", "unknown-schema")):
        record = f.index["packages"][ALPHA]["versions"].pop(OLD)
        if mode != "unindexed":
            f.index["packages"][ALPHA]["versions"][OLD] = record
        metadata = f.metadata(identity=OLD)
        original_metadata = copy.deepcopy(metadata)
        if mode == "private":
            metadata["origin_kind"] = "local-project"
        if mode == "schema":
            metadata["schema_version"] = "taffish.install/v999"
        write_json(f.metadata_path(identity=OLD), metadata)
        f.save()
        before = f.state()
        _, items = installed_plan(f)
        assert items[ALPHA, OLD]["reason"] == reason, items
        evidence = items[ALPHA, OLD]["validation"]
        assert evidence is None or evidence["state"] != "verified", items
        f.cli("install", "--all-installed", "--repair", "--yes", code=1)
        f.unchanged(before)
        f.index["packages"][ALPHA]["versions"][OLD] = record
        write_json(f.metadata_path(identity=OLD), original_metadata)


def installed_filters():
    f = seeded("installed-filters", versions=(OLD, LATEST))
    before = f.state()
    _, items = installed_plan(f, "--tools")
    assert not items
    _, items = installed_plan(f, "--flows")
    assert len(items) == 2
    empty_system = f.cli("install", "--all-installed", "--repair", "--system", "--json")
    assert json.loads(empty_system.stdout)["scope"] == "system"
    f.unchanged(before)
    metadata = f.metadata(identity=OLD)
    metadata.pop("kind")
    write_json(f.metadata_path(identity=OLD), metadata)
    before = f.state()
    _, items = installed_plan(f, "--tools")
    assert items[ALPHA, OLD]["reason"] == "kind-unknown", items
    f.cli("install", "--all-installed", "--repair", "--tools", "--yes", code=1)
    f.unchanged(before)


def installed_output():
    f = seeded("installed-output", versions=(OLD, LATEST))
    f.manifest(identity=OLD).unlink()
    before = f.state()
    for language in ("en", "zh"):
        f.env["TAFFISH_LANGUAGE"] = language
        doctor = f.cli("doctor", "hub").stdout
        coverage = "Enumerated 1 apps, 2 version identities" if language == "en" else "已枚举 1 个应用、2 个版本身份"
        affected = "issues affect 1 apps, 1 identities" if language == "en" else "问题涉及 1 个应用、1 个版本身份"
        assert coverage in doctor and affected in doctor, doctor
        assert "taf install --all-installed --repair --user" in doctor, doctor
        latest = f.cli("install", "--all", "--repair").stdout
        assert "index.latest" in latest and "--all --repair --user --kind all --yes" in latest, latest
        text = f.cli("install", "--all-installed", "--repair", "--flows").stdout
        assert "--all-installed --repair --user --kind flow --yes" in text, text
        assert "--all --repair --yes" not in text and len(text.splitlines()) < 18, text
        _, items = installed_plan(f)
        assert len(items) == 2
    f.unchanged(before)


def installed_conflicts():
    f = seeded("installed-conflicts")
    before = f.state()
    for args in (("--all-installed",), ("--all-installed", "--yes")):
        assert "requires --repair" in f.cli("install", *args, code=1).stderr
    for extra in (("--all",), (ALPHA,), ("--force",), ("--from", "."),
                  ("--prune-old",), ("--dry-run", "--yes")):
        f.cli("install", "--all-installed", "--repair", *extra, code=1)
    f.unchanged(before)


def installed_paths():
    f = seeded("installed-paths", versions=(OLD, LATEST))
    metadata_path = f.metadata_path(identity=OLD)
    original = metadata_path.read_bytes()
    outside = f.sentinel / "unrelated-record.json"
    outside.write_bytes(original)
    metadata_path.unlink()
    metadata_path.symlink_to(outside)
    before = f.state()
    _, items = installed_plan(f)
    assert items[ALPHA, OLD]["action"] == "blocked", items
    f.cli("install", "--all-installed", "--repair", "--yes", code=1)
    f.unchanged(before)
    metadata_path.unlink()
    metadata_path.write_bytes(original)
    for changes in ({"name": BETA}, {"version_id": LATEST}, {"install_root": str(f.sentinel)}):
        metadata = json.loads(original)
        metadata.update(changes)
        write_json(metadata_path, metadata)
        before = f.state()
        _, items = installed_plan(f)
        assert items[ALPHA, OLD]["action"] == "blocked", items
        f.cli("install", "--all-installed", "--repair", "--yes", code=1)
        f.unchanged(before)


def multi():
    f = seeded("multi")
    f.add(BETA)
    f.install(BETA)
    before = f.state()
    for mode in ((), ("--repair",)):
        for option in ("--json", "--yes"):
            rejected = f.cli("install", *mode, ALPHA, BETA, option, code=1)
            assert "--json and --yes require --all or --all-installed --repair" in rejected.stderr, rejected.stderr
            f.unchanged(before)
    for name in (ALPHA, BETA):
        f.manifest(name).unlink()
    before = f.state()
    expected = {ALPHA: (LATEST, "repair", "rebuild-required"),
                BETA: (LATEST, "repair", "rebuild-required")}
    f.repair_targets(ALPHA, BETA, dry=True, expected=expected)
    f.unchanged(before)
    f.repair_targets(ALPHA, BETA, dry=False, expected=expected)
    f.verified(ALPHA)
    f.verified(BETA)
    repaired = f.state()
    f.repair_targets(BETA, ALPHA, dry=False,
                  expected={ALPHA: (LATEST, "skip", "already-verified"),
                            BETA: (LATEST, "skip", "already-verified")})
    f.unchanged(repaired)


def multi_blocked():
    f = seeded("multi-blocked")
    f.add(BETA)
    f.install(BETA)
    f.manifest().unlink()
    write_json(f.metadata_path(BETA), dict(f.metadata(BETA), origin_kind="local-project"))
    before = f.state()
    expected = {ALPHA: (LATEST, "repair", "rebuild-required"),
                BETA: (LATEST, "blocked", "private-or-unknown-source")}
    f.plan(expected=expected)
    f.unchanged(before)
    f.repair_targets(ALPHA, BETA, dry=True, expected=expected)
    f.unchanged(before)
    for args in ((ALPHA, BETA), (BETA, ALPHA), ("--all", "--yes")):
        f.repair_failure(*args, reason="private-or-unknown-source")
        f.unchanged(before)
        assert not f.manifest().exists(), "batch modified an earlier target before preflight completed"


def all_selection():
    empty = Fixture("all-empty")
    empty.add()
    empty_before = empty.state()
    empty.plan(expected={}, absent=1)  # Public items must be [] rather than null.
    empty.unchanged(empty_before)
    empty.plan("--yes", dry=False, expected={}, absent=1)
    empty.unchanged(empty_before)
    f = seeded("all-selection", versions=(OLD, LATEST))
    f.add(BETA, versions=(OLD, LATEST))
    f.install(BETA, OLD)
    for name in ("repair-absent", "repair-dependency"):
        f.add(name)
    f.record()["dependencies"] = {"repair-dependency": LATEST}
    f.save()
    for name, identity in ((ALPHA, OLD), (ALPHA, LATEST), (BETA, OLD)):
        f.manifest(name, identity).unlink()
    before = f.state()
    expected = {ALPHA: (LATEST, "repair", "rebuild-required")}
    f.plan(expected=expected, absent=3)  # beta latest, absent app, and dependency.
    f.unchanged(before)
    f.plan("--dry-run", expected=expected, absent=3)
    f.unchanged(before)
    preview = f.cli("install", "--repair", "--all")
    assert "Preview only." in preview.stdout, preview.stdout
    f.unchanged(before)
    assert not f.manifest().exists(), "unconfirmed --all executed a repair"
    protected = {str(root): fingerprint(root) for root in
                 (f.install_root(ALPHA, OLD), f.install_root(BETA, OLD))}
    f.plan("--yes", dry=False, expected=expected, absent=3)
    f.verified()
    for path, state in protected.items():
        assert fingerprint(Path(path)) == state, "--all repaired/upgraded a non-latest installed identity"
    assert not f.install_root(BETA, LATEST).exists()
    assert not (f.home / "apps/repair-absent").exists()
    assert not (f.home / "apps/repair-dependency").exists()
    assert set(p.name for p in (f.home / "apps").iterdir() if p.is_dir() and not p.name.startswith(".")) == {ALPHA, BETA}


def schema_property_names(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "properties":
                yield from value
            yield from schema_property_names(value)
    elif isinstance(node, list):
        for child in node:
            yield from schema_property_names(child)


def mcp():
    f = seeded("mcp")
    f.manifest().unlink()
    before = f.state()
    requests = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "repair-safety", "version": "1"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
        {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {
            "name": "taffish_install_app", "arguments": {"target": ALPHA, "repair": True, "dryRun": True}}},
        {"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {
            "name": "taffish_repair_app", "arguments": {"target": ALPHA}}},
    ]
    result = f.command([os.environ["TAFFISH_MCP_BIN"]],
                       request="".join(json.dumps(item) + "\n" for item in requests))
    assert not result.stderr, result.stderr
    replies = [json.loads(line) for line in result.stdout.splitlines()]
    assert len(replies) == 4 and {item["id"] for item in replies} == {1, 2, 3, 4}, replies
    replies = {item["id"]: item for item in replies}
    tools = replies[2]["result"]["tools"]
    assert any(tool["name"] == "taffish_install_app" for tool in tools)
    for tool in tools:
        assert "repair" not in tool["name"].lower(), tool
        assert not any("repair" in name.lower() for name in schema_property_names(tool["inputSchema"])), tool
        assert not {"allInstalled", "all_installed", "all-installed"}.intersection(
            schema_property_names(tool["inputSchema"])), tool
    if "result" in replies[3] and not replies[3]["result"].get("isError"):
        body = replies[3]["result"]["structuredContent"]
        assert body.get("operation") != "repair" and body.get("schema_version") != "taffish.repair-plan/v1", body
    assert "error" in replies[4] or replies[4]["result"].get("isError") is True, replies[4]
    f.unchanged(before)
    assert not f.manifest().exists(), "MCP repaired through an unadvertised argument/tool"


def self_test():
    # This checks the test oracles only; it is not repair candidate evidence.
    blocked_error = "[TAF-ERROR] [install] Repair blocked before changes.\n  blocked [unknown-schema]"
    transaction_error = ("[TAF-ERROR] [install] Repair stopped after 0 completed targets; "
                         "[repair-failed]: [source-fetch-failed]")
    for stderr, reason, transaction in ((blocked_error, "unknown-schema", False),
                                        (transaction_error, "source-fetch-failed", True)):
        validate_repair_error(subprocess.CompletedProcess([], 1, "", stderr), reason,
                              transaction=transaction)
        for wrong in ("[install] --json, --yes, and --prune-old are only supported with --all.",
                      "[TAF-ERROR] an unrelated failure", stderr + "\nUsage: taf install"):
            try:
                validate_repair_error(subprocess.CompletedProcess([], 1, "", wrong), reason,
                                      transaction=transaction)
            except AssertionError:
                pass
            else:
                raise AssertionError("repair oracle accepted a parser/unrelated failure")
    fixture = Fixture.__new__(Fixture)
    try:
        fixture.repair_json(ALPHA, dry=True)
    except AssertionError:
        pass
    else:
        raise AssertionError("repair_json allowed a non-all invocation")
    calls = []

    def fake_cli(*args):
        calls.append(args)
        return subprocess.CompletedProcess(args, 0, "[TAF] Repair plan: 1 installed targets; "
            "1 rebuild, 0 unchanged, 0 blocked; 0 absent targets skipped.\n"
            "  rebuild [rebuild-required]: repair-alpha 1.0.0-r1\nPreview only.\n", "")

    fixture.cli = fake_cli
    fixture.repair_targets(ALPHA, OLD, dry=True, expected={ALPHA: (OLD, "repair", "rebuild-required")})
    assert calls == [("install", "--repair", ALPHA, OLD, "--dry-run")], calls
    good = {"schema_version": "taffish.repair-plan/v1", "operation": "repair", "scope": "user",
            "dry_run_p": True, "summary": {"total": 1, "repair": 1, "skip": 0, "blocked": 0,
                                             "skipped_not_installed": 2},
            "items": [{"package_name": ALPHA, "version_id": LATEST, "action": "repair",
                       "reason": "rebuild-required", "blocked_p": False}]}
    expected = {ALPHA: (LATEST, "repair", "rebuild-required")}
    validate_plan(good, expected, absent=2)
    for change in (lambda d: d.update(dry_run_p="true"),
                   lambda d: d.update(items=None),
                   lambda d: d.update(items={}),
                   lambda d: d.update(applied=[{"package_name": ALPHA}]),
                   lambda d: d["summary"].update(skipped_not_installed=0),
                   lambda d: d["items"][0].update(action="skip"),
                   lambda d: d["items"][0].update(version_id=OLD)):
        bad = copy.deepcopy(good)
        change(bad)
        try:
            validate_plan(bad, expected, absent=2)
        except AssertionError:
            pass
        else:
            raise AssertionError("repair-plan oracle accepted a wrong fixture result")
    empty = {"schema_version": "taffish.repair-plan/v1", "operation": "repair", "scope": "user",
             "dry_run_p": True, "summary": {"total": 0, "repair": 0, "skip": 0, "blocked": 0,
                                              "skipped_not_installed": 1}, "items": []}
    validate_plan(empty, {}, absent=1)
    empty["dry_run_p"] = False
    validate_plan(empty, {}, dry=False, absent=1)
    applied = copy.deepcopy(good)
    applied.update(dry_run_p=False, applied=[{"package_name": ALPHA}])
    validate_plan(applied, expected, dry=False, absent=2)
    applied["applied"] = []
    try:
        validate_plan(applied, expected, dry=False, absent=2)
    except AssertionError:
        pass
    else:
        raise AssertionError("repair-plan oracle accepted an unapplied repair as successful")
    with tempfile.TemporaryDirectory(prefix="repair-oracle-") as temporary:
        root = Path(temporary)
        path = root / "keep"
        path.write_text("same", encoding="utf-8")
        before = fingerprint(root)
        replacement = root / "replacement"
        replacement.write_text("same", encoding="utf-8")
        replacement.replace(path)
        assert fingerprint(root) != before, "fingerprint missed replacement with identical bytes"
        before = fingerprint(root, directory_times=True)
        info = root.stat()
        os.utime(root, ns=(info.st_atime_ns, info.st_mtime_ns + 1000000000))
        assert fingerprint(root, directory_times=True) != before, "strict oracle missed directory writes"
        (root / "loop").symlink_to(root, target_is_directory=True)
        assert fingerprint(root)["loop"][1] == "link", "fingerprint followed a directory symlink"
    print("repair test oracles passed; candidate CLI tests not run")


CASES = {"conflicts": conflicts, "healthy": healthy, "legacy": legacy, "corruption": corruption,
         "commit-conflict": commit_conflict, "fixed-commit": fixed_commit, "source-unavailable": source_unavailable,
         "blocked-private": blocked_private, "blocked-schema": blocked_schema, "blocked-path": blocked_path,
         "entry-conflict": entry_conflict, "exact-old": exact_old, "multi": multi,
         "multi-blocked": multi_blocked, "all-selection": all_selection, "mcp": mcp,
         "installed-history": installed_history, "installed-old-only": installed_old_only,
         "installed-blocked": installed_blocked, "installed-filters": installed_filters,
         "installed-output": installed_output, "installed-conflicts": installed_conflicts,
         "installed-paths": installed_paths}

if __name__ == "__main__":
    case = sys.argv[1]
    if case == "self-test":
        self_test()
    else:
        CASES[case]()
        print("[repair] " + case + ": PASS (isolated local Git fixtures, no network)")
