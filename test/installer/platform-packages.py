"""Offline versioned-package tests using both generated installers and a disposable signing key."""
import errno
import hashlib
import io
import os
from pathlib import Path
import pty
import re
import random
import select
import shutil
import signal
import subprocess
import tarfile
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROGRAMS = ("taf", "taffish", "taffish-mcp")
PROVIDERS = {
    "github": ("install-taffish.sh", "https://raw.githubusercontent.com/taffish/taffish"),
    "gitee": ("install-taffish.gitee.sh", "https://gitee.com/taffish-org/taffish/raw"),
}
RUNTIME_FILES = {"darwin": "SBCL-NOTICES.txt", "linux": "LISPWORKS-RUNTIME.txt"}
PART_SIZE = 8 * 1024 * 1024


def digest(data):
    return hashlib.sha256(data).hexdigest()


def scripts(version, platform):
    return {name + "-" + platform + "-" + version:
            ('#!/bin/sh\n'
             '[ -z "${PROGRAM_LOG:-}" ] || printf \'%s\\n\' "$0 $*" >> "$PROGRAM_LOG"\n'
             f'[ "${{1:-}}" != --version ] || echo "{name} {version}"\n').encode()
            for name in PROGRAMS}


def checksums(files):
    return "".join(f"{digest(data)}  {name}\n" for name, data in files.items()).encode()


def archive_bytes(platform, files):
    stream = io.BytesIO()
    mode = "w:xz" if platform.startswith("darwin-") else "w:gz"
    with tarfile.open(fileobj=stream, mode=mode) as archive:
        for path, data in files.items():
            info = tarfile.TarInfo(path)
            info.mode = 0o755 if data.startswith(b"#!") else 0o644
            info.size = len(data)
            archive.addfile(info, io.BytesIO(data))
    return stream.getvalue()


def run_with_terminal(command, env, directory, reply):
    child, terminal = pty.fork()
    if child == 0:
        os.chdir(directory)
        os.execvpe(command[0], command, env)
    output = bytearray()
    answered = False
    deadline = time.monotonic() + 60
    try:
        while time.monotonic() < deadline:
            if not select.select([terminal], [], [], 0.1)[0]:
                continue
            try:
                data = os.read(terminal, 65536)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                break  # Linux reports EIO when the PTY's child exits.
            if not data:
                break
            output.extend(data)
            if not answered and b"Type yes to install: " in output:
                os.write(terminal, reply)
                answered = True
        else:
            raise subprocess.TimeoutExpired(command, 60, bytes(output))
        _, status = os.waitpid(child, 0)
        child = 0
        return subprocess.CompletedProcess(command, os.waitstatus_to_exitcode(status),
                                           output.decode().replace("\r\n", "\n"))
    finally:
        os.close(terminal)
        if child:
            try:
                os.kill(child, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(child, 0)


class PlatformPackages(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="taf-qa-", dir="/tmp")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.root = Path(cls.temp.name)
        cls.keys = cls.root / "keys"
        cls.keys.mkdir(mode=0o700)
        cls.gpg = ["gpg", "--homedir", str(cls.keys), "--batch", "--yes",
                   "--pinentry-mode", "loopback", "--passphrase", ""]
        cls.addClassCleanup(subprocess.run, ["gpgconf", "--homedir", str(cls.keys),
                                            "--kill", "gpg-agent"], check=False)
        subprocess.run(cls.gpg + ["--quick-generate-key", "TAFFISH offline test",
                                  "ed25519", "sign", "0"], check=True)
        listing = subprocess.check_output(cls.gpg + ["--with-colons", "--list-keys"], text=True)
        cls.fingerprint = next(line.split(":")[9] for line in listing.splitlines()
                               if line.startswith("fpr:"))
        cls.key = subprocess.check_output(cls.gpg + ["--armor", "--export", cls.fingerprint])
        for installer, _ in PROVIDERS.values():
            source = (ROOT / "install" / installer).read_text()
            source, replacements = re.subn(r"^TAFFISH_RELEASE_KEY_FINGERPRINT=[A-F0-9]{40}$",
                                           "TAFFISH_RELEASE_KEY_FINGERPRINT=" + cls.fingerprint,
                                           source, flags=re.MULTILINE)
            if replacements != 1:
                raise AssertionError("could not pin the fixture key in the test copy")
            (cls.root / installer).write_text(source)
        tools = cls.root / "bin"
        tools.mkdir()
        curl = tools / "curl"
        curl.write_text("""#!/bin/sh
set -eu
url= out=
while [ "$#" -gt 0 ]; do
  case "$1" in
    https://*) url=$1; shift ;;
    -o) out=$2; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s\\n' "$url" >> "$REQUEST_LOG"
case "$url" in
  "$EXPECTED_BASE"/*) source_file=$MIRROR/${url#"$EXPECTED_BASE"/} ;;
  *) exit 22 ;;
esac
[ -f "$source_file" ] || exit 22
case "$source_file" in
  *.part-ab)
    if [ -f "$MIRROR/interrupt-second" ]; then
      printf 'partial transfer' > "$out"
      exit 18
    fi ;;
esac
cp "$source_file" "$out"
""")
        curl.chmod(0o755)

    def setUp(self):
        self.case = Path(self.temp.name) / self._testMethodName
        self.case.mkdir()
        self.mirror = self.case / "mirror"
        self.checkout = self.mirror / "v0.12.0"
        self.install_dir = self.checkout / "install"
        self.install_dir.mkdir(parents=True)
        for installer, _ in PROVIDERS.values():
            shutil.copyfile(self.root / installer, self.install_dir / installer)

    def sign(self, data):
        return subprocess.check_output(self.gpg + ["--armor", "--detach-sign", "--output", "-"],
                                       input=data)

    def release(self, osname, version="0.12.0", fault="", runtime_suffix=b"", binary_suffix=b"", extra_files=None):
        arch = "arm64" if osname == "darwin" else "amd64"
        platform = osname + "-" + arch
        directory = self.mirror / ("v" + version) / "target"
        directory.mkdir(parents=True, exist_ok=True)
        binaries = scripts(version, platform)
        binaries = {name: body + binary_suffix for name, body in binaries.items()}
        inner = checksums(binaries)
        files = {"target/" + n: data for n, data in binaries.items()}
        files["completion/bash/taf"] = b"# completion\n"
        files["vim-highlight/syntax/taf.vim"] = b'" syntax\n'
        if fault != "missing-inner":
            files["target/SHA256SUMS"] = inner
        files["target/SHA256SUMS.asc"] = self.sign(inner)
        files["target/TAFFISH-RELEASE-KEY.asc"] = self.key
        if version == "0.11.0":
            for path, data in files.items():
                dest = directory.parent / path
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(data)
            return ""
        files["LICENSE"] = (ROOT / "LICENSE").read_bytes()
        files["vendor/han/LICENSE"] = (ROOT / "vendor/han/LICENSE").read_bytes()
        runtime_path = "licenses/" + RUNTIME_FILES[osname]
        files[runtime_path] = (ROOT / runtime_path).read_bytes() + runtime_suffix
        if fault == "missing-runtime":
            del files[runtime_path]
        elif fault == "empty-runtime":
            files[runtime_path] = b""
        elif fault == "wrong-runtime":
            other = RUNTIME_FILES["darwin" if osname == "linux" else "linux"]
            files["licenses/" + other] = files.pop(runtime_path)
        elif fault == "missing-license":
            del files["LICENSE"]
        elif fault == "empty-han-license":
            files["vendor/han/LICENSE"] = b""
        directory = directory / ("packages-" + version)
        directory.mkdir(exist_ok=True)
        if fault == "bad-inner-signature":
            files["target/SHA256SUMS.asc"] = self.sign(inner + b"\n")
        if fault == "bad-binary":
            files["target/" + next(iter(binaries))] += b"# damaged\n"
        name = "taffish-" + version + "-" + platform + (".tar.xz" if osname == "darwin" else ".tar.gz")
        files.update(extra_files or {})
        archive = archive_bytes(platform, files)
        outer = checksums({name: archive})
        (directory / name).write_bytes(archive + (b"extra" if fault == "bad-archive" else b""))
        if osname == "darwin":
            self.write_parts(directory / name)
        (directory / "TAFFISH-RELEASE-KEY.asc").write_bytes(self.key)
        manifest = directory / "ARCHIVE-SHA256SUMS"
        manifest.write_bytes(outer)
        (directory / "ARCHIVE-SHA256SUMS.asc").write_bytes(
            self.sign(outer + (b"\n" if fault == "bad-outer-signature" else b"")))
        if fault == "missing-outer":
            manifest.unlink()
        return name

    def write_parts(self, archive):
        for old in archive.parent.glob(archive.name + ".part-*"):
            old.unlink()
        data = archive.read_bytes()
        parts = {}
        for i, start in enumerate(range(0, len(data), PART_SIZE)):
            name = archive.name + f".part-{chr(97 + i // 26)}{chr(97 + i % 26)}"
            parts[name] = data[start:start + PART_SIZE]
            (archive.parent / name).write_bytes(parts[name])
        Path(str(archive) + ".parts").write_bytes(checksums(parts))
        return parts

    def install(self, provider, osname, version, prefix, *extra, success=True, accept=True, terminal=None):
        installer, base = PROVIDERS[provider]
        log = self.case / "requests"
        log.write_text("")
        executions = self.case / "program-invocations"
        executions.write_text("")
        base_env = {k: v for k, v in os.environ.items() if not k.startswith("TAFFISH_")}
        env = dict(base_env, HOME=str(self.case),
                   PATH=os.pathsep.join((str(self.case / "bin"), str(self.root / "bin"), os.environ["PATH"])),
                   EXPECTED_BASE=base, MIRROR=str(self.mirror), REQUEST_LOG=str(log),
                   PROGRAM_LOG=str(executions), RECEIPT_FAIL_ONCE=str(self.case / "receipt-failure"))
        command = ["sh", str(self.install_dir / installer), "--prefix", str(prefix), "--version", version,
                   "--os", osname, "--arch", "arm64" if osname == "darwin" else "amd64",
                   "--retry", "0", "--config-profile", "none", "--no-doctor", *extra]
        if accept and osname == "linux" and version != "0.11.0":
            command.append("--accept-runtime-license")
        if terminal is None:
            result = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    stdin=subprocess.DEVNULL, start_new_session=True,
                                    cwd=self.case, text=True, timeout=60)
        else:
            result = run_with_terminal(command, env, self.case, terminal)
        self.assertEqual(success, result.returncode == 0, result.stdout)
        requests = log.read_text().splitlines()
        self.assertTrue(all(url.startswith(base + "/v" + version + "/") for url in requests), requests)
        return result.stdout, requests

    def test_default_provider_download_and_upgrade(self):
        for provider in PROVIDERS:
            for osname in ("darwin", "linux"):
                with self.subTest(provider=provider, os=osname):
                    prefix = self.case / (provider + "-" + osname)
                    self.release(osname, "0.11.0")
                    self.install(provider, osname, "0.11.0", prefix, "--verify", "gpg")
                    home = prefix / "share/taffish"
                    receipt = home / "install-receipt.toml"
                    self.assertIn('source_kind = "raw"', receipt.read_text())
                    marker = home / "kept.txt"
                    marker.write_text("user data")
                    name = self.release(osname)
                    output, requests = self.install(provider, osname, "0.12.0", prefix, "--verify", "gpg")
                    self.assertIn("update=ok", output)
                    directory_url = PROVIDERS[provider][1] + "/v0.12.0/target/packages-0.12.0/"
                    payloads = (name + ".parts", name + ".part-aa") if (
                        provider == "gitee" and osname == "darwin") else (name,)
                    self.assertCountEqual(requests, [directory_url + asset for asset in
                                          (*payloads, "ARCHIVE-SHA256SUMS", "ARCHIVE-SHA256SUMS.asc",
                                           "TAFFISH-RELEASE-KEY.asc")])
                    for statement in ('source_kind = "bundle"', 'verification = "gpg"',
                                      f'provider = "{provider}"', f'archive_asset = "{name}"'):
                        self.assertIn(statement, receipt.read_text())
                    self.assertEqual(marker.read_text(), "user data")
                    self.assert_installed_licenses(prefix, osname)
                    for program in PROGRAMS:
                        exe = prefix / "bin" / program
                        self.assertEqual(subprocess.check_output([exe, "--version"], text=True).split(),
                                         [program, "0.12.0"])

    def large_macos_release(self):
        # Incompressible data forces two actual 8 MiB transport chunks.
        return self.release("darwin", extra_files={
            "completion/transport-test-data": random.Random(176).randbytes(PART_SIZE + 4096)})

    def test_gitee_two_parts_restore_the_signed_archive(self):
        name = self.large_macos_release()
        packages = self.checkout / "target/packages-0.12.0"
        archive = packages / name
        expected = digest(archive.read_bytes())
        self.assertGreater(archive.stat().st_size, PART_SIZE)
        self.assertLess(archive.stat().st_size, 2 * PART_SIZE)
        archive.unlink()  # Gitee has only the parts; a fallback cannot hide a defect.
        prefix = self.case / "installed"
        _, requests = self.install("gitee", "darwin", "0.12.0", prefix, "--verify", "gpg")
        self.assertEqual([url.rsplit("/", 1)[-1] for url in requests[:3]],
                         [name + ".parts", name + ".part-aa", name + ".part-ab"])
        self.assertFalse(any(url.endswith("/" + name) for url in requests))
        receipt = (prefix / "share/taffish/install-receipt.toml").read_text()
        self.assertIn(f'archive_sha256 = "{expected}"', receipt)
        self.assertIn('archive_verification = "gpg"', receipt)
        for program in PROGRAMS:
            self.assertEqual(subprocess.check_output([prefix / "bin" / program, "--version"],
                                                     text=True).split(), [program, "0.12.0"])

    def test_gitee_part_faults_preserve_previous_install(self):
        prefix = self.case / "installed"
        self.release("darwin", "0.11.0")
        self.install("gitee", "darwin", "0.11.0", prefix, "--verify", "gpg")
        protected = [prefix / "share/taffish/install-receipt.toml",
                     *(prefix / "bin" / p for p in PROGRAMS)]
        before = {p: p.read_bytes() for p in protected}
        name = self.large_macos_release()
        packages = self.checkout / "target/packages-0.12.0"
        manifest = packages / (name + ".parts")
        first = packages / (name + ".part-aa")
        second = packages / (name + ".part-ab")
        originals = {p: p.read_bytes() for p in (manifest, first, second)}
        rows = originals[manifest].splitlines(keepends=True)
        faults = {
            "missing-list": "download failed:",
            "missing-second": "download failed:",
            "interrupted-second": "download failed:",
            "damaged-second": "SHA256 mismatch for " + second.name,
            "short-first": "incomplete non-final archive part",
            "empty-second": "invalid archive part size",
            "oversized-second": "invalid archive part size",
            "empty-list": "invalid archive part manifest",
            "swapped-list": "invalid archive part manifest",
            "duplicate-list": "invalid archive part manifest",
            "other-version": "invalid archive part manifest",
            "unsafe-path": "invalid archive part manifest",
            "too-many-parts": "invalid archive part manifest",
            "forged-part-and-list": "SHA256 mismatch for " + name + " (",
        }
        for fault, message in faults.items():
            with self.subTest(fault=fault):
                for path, content in originals.items():
                    path.write_bytes(content)
                interruption = self.mirror / "interrupt-second"
                interruption.unlink(missing_ok=True)
                if fault == "missing-list":
                    manifest.unlink()
                elif fault == "missing-second":
                    second.unlink()
                elif fault == "interrupted-second":
                    interruption.touch()
                elif fault == "damaged-second":
                    second.write_bytes(b"damaged")
                elif fault == "short-first":
                    first.write_bytes(b"short")
                elif fault == "empty-second":
                    second.write_bytes(b"")
                elif fault == "oversized-second":
                    second.write_bytes(b"x" * (PART_SIZE + 1))
                elif fault == "empty-list":
                    manifest.write_bytes(b"")
                elif fault == "swapped-list":
                    manifest.write_bytes(rows[1] + rows[0])
                elif fault == "duplicate-list":
                    manifest.write_bytes(rows[0] + rows[0])
                elif fault == "other-version":
                    manifest.write_bytes(originals[manifest].replace(b"0.12.0", b"0.13.0"))
                elif fault == "unsafe-path":
                    manifest.write_bytes(rows[0].replace(name.encode(), b"../../outside"))
                elif fault == "too-many-parts":
                    manifest.write_bytes(checksums({name + f".part-{chr(97+i//26)}{chr(97+i%26)}":
                                                   b"x" for i in range(65)}))
                elif fault == "forged-part-and-list":
                    second.write_bytes(b"replacement")
                    manifest.write_bytes(checksums({first.name: first.read_bytes(), second.name: b"replacement"}))
                output, requests = self.install("gitee", "darwin", "0.12.0", prefix,
                                                 "--verify", "gpg", success=False)
                self.assertIn(message, output)
                self.assertEqual({p: p.read_bytes() for p in protected}, before)
                self.assertEqual((self.case / "program-invocations").read_text(), "")
                self.assertFalse(any(url.endswith("/" + name) for url in requests))
                self.assertFalse(any("../" in url for url in requests))
        for path, content in originals.items():
            path.write_bytes(content)
        (self.mirror / "interrupt-second").unlink(missing_ok=True)
        self.install("gitee", "darwin", "0.12.0", prefix, "--verify", "gpg")
        self.assertIn("0.12.0", subprocess.check_output([prefix / "bin/taf", "--version"], text=True))

    def test_gitee_parts_keep_explicit_verify_none(self):
        self.release("darwin")
        prefix = self.case / "installed"
        _, requests = self.install("gitee", "darwin", "0.12.0", prefix, "--verify", "none")
        receipt = (prefix / "share/taffish/install-receipt.toml").read_text()
        self.assertIn('archive_verification = "none"', receipt)
        self.assertTrue(any(url.endswith(".parts") for url in requests))
        self.assertFalse(any(url.endswith("ARCHIVE-SHA256SUMS") for url in requests))

    def test_gitee_parts_do_not_replace_full_archive_authentication(self):
        prefix = self.case / "installed"
        self.release("darwin", "0.11.0")
        self.install("gitee", "darwin", "0.11.0", prefix, "--verify", "gpg")
        protected = [prefix / "share/taffish/install-receipt.toml",
                     *(prefix / "bin" / p for p in PROGRAMS)]
        before = {p: p.read_bytes() for p in protected}
        for fault in ("bad-archive", "bad-outer-signature", "missing-outer", "bad-inner-signature"):
            with self.subTest(fault=fault):
                self.release("darwin", fault=fault)
                self.install("gitee", "darwin", "0.12.0", prefix, "--verify", "gpg", success=False)
                self.assertEqual({p: p.read_bytes() for p in protected}, before)
                self.assertEqual((self.case / "program-invocations").read_text(), "")

    def test_gitee_explicit_macos_url_keeps_full_archive_path(self):
        name = self.release("darwin")
        packages = self.checkout / "target/packages-0.12.0"
        (packages / (name + ".parts")).unlink()
        url = PROVIDERS["gitee"][1] + "/v0.12.0/target/packages-0.12.0/" + name
        _, requests = self.install("gitee", "darwin", "0.12.0", self.case / "installed",
                                   "--url", url, "--verify", "gpg")
        self.assertIn(url, requests)
        self.assertFalse(any(".part" in request for request in requests))

    def test_sbcl_notice_replaces_ccl_candidate_notice_and_keeps_user_files(self):
        self.release("darwin")
        for provider in PROVIDERS:
            with self.subTest(provider=provider):
                prefix = self.case / provider
                self.install(provider, "darwin", "0.12.0", prefix, "--verify", "gpg")
                licenses = prefix / "share/taffish/share/licenses"
                (licenses / "SBCL-NOTICES.txt").unlink()
                (licenses / "CCL-NOTICES.txt").write_bytes((ROOT / "licenses/CCL-NOTICES.txt").read_bytes())
                marker = licenses / "local-note.txt"
                marker.write_text("user notice")
                self.install(provider, "darwin", "0.12.0", prefix, "--verify", "gpg")
                self.assert_installed_licenses(prefix, "darwin")
                self.assertFalse((licenses / "CCL-NOTICES.txt").exists())
                self.assertEqual(marker.read_text(), "user notice")

    def assert_installed_licenses(self, prefix, osname, acceptance="flag"):
        home = prefix / "share/taffish"
        licenses = home / "share/licenses"
        expected = {"TAFFISH-LICENSE.txt": ROOT / "LICENSE",
                    "HAN-LICENSE.txt": ROOT / "vendor/han/LICENSE",
                    RUNTIME_FILES[osname]: ROOT / "licenses" / RUNTIME_FILES[osname]}
        for name, source in expected.items():
            path = licenses / name
            self.assertFalse(path.is_symlink())
            self.assertEqual(path.read_bytes(), source.read_bytes())
            self.assertEqual(path.stat().st_mode & 0o777, 0o644)
        receipt = (home / "install-receipt.toml").read_text()
        if osname == "linux":
            self.assertIn('runtime_license_file = "share/licenses/LISPWORKS-RUNTIME.txt"', receipt)
            self.assertIn(f'runtime_license_acceptance = "{acceptance}"', receipt)
            self.assertIn('runtime_license_sha256 = "' +
                          digest((licenses / RUNTIME_FILES[osname]).read_bytes()) + '"', receipt)
        else:
            self.assertNotIn("runtime_license_acceptance", receipt)

    def test_show_runtime_license_verifies_without_installing_or_running(self):
        prefix = self.case / "untouched"
        for provider in PROVIDERS:
            for osname in RUNTIME_FILES:
                with self.subTest(provider=provider, os=osname):
                    self.release(osname)
                    output, _ = self.install(provider, osname, "0.12.0", prefix,
                                             "--verify", "gpg", "--show-runtime-license", accept=False)
                    text = (ROOT / "licenses" / RUNTIME_FILES[osname]).read_text()
                    self.assertIn(text, output)
                    self.assertFalse(prefix.exists())
                    self.assertEqual((self.case / "program-invocations").read_text(), "")
                    self.release(osname, fault="bad-inner-signature")
                    output, _ = self.install(provider, osname, "0.12.0", prefix,
                                             "--verify", "gpg", "--show-runtime-license",
                                             accept=False, success=False)
                    self.assertNotIn(text, output)
                    self.assertFalse(prefix.exists())
                    self.assertEqual((self.case / "program-invocations").read_text(), "")
        self.release("linux")
        output, _ = self.install("github", "linux", "0.12.0", prefix, "--local", "--system",
                                 "--show-runtime-license", accept=False)
        self.assertIn((ROOT / "licenses/LISPWORKS-RUNTIME.txt").read_text(), output)
        self.assertFalse(prefix.exists())
        self.assertEqual((self.case / "program-invocations").read_text(), "")

    def test_linux_requires_explicit_acceptance_before_installing_or_running(self):
        self.release("linux")
        for provider in PROVIDERS:
            with self.subTest(provider=provider):
                prefix = self.case / provider
                output, _ = self.install(provider, "linux", "0.12.0", prefix,
                                         "--local", accept=False, success=False)
                self.assertIn("--accept-runtime-license", output)
                self.assertFalse(prefix.exists())
                self.assertEqual((self.case / "program-invocations").read_text(), "")
                self.install(provider, "linux", "0.12.0", prefix, "--local")
                self.assert_installed_licenses(prefix, "linux")
                home = prefix / "share/taffish"
                marker = home / "kept.txt"
                marker.write_text("kept user data")
                receipt = home / "install-receipt.toml"
                previous = receipt.read_bytes()
                self.install(provider, "linux", "0.12.0", prefix,
                             "--local", accept=False, success=False)
                self.assertEqual(receipt.read_bytes(), previous)
                self.assertEqual(marker.read_text(), "kept user data")
                self.assertEqual((self.case / "program-invocations").read_text(), "")
                self.install(provider, "linux", "0.12.0", prefix, "--local")
                self.assert_installed_licenses(prefix, "linux")
                self.assertIn('binary_action = "unchanged"', receipt.read_text())

    def test_incomplete_license_materials_fail_before_install(self):
        for osname in RUNTIME_FILES:
            for fault in ("missing-runtime", "empty-runtime", "wrong-runtime",
                          "missing-license", "empty-han-license"):
                with self.subTest(os=osname, fault=fault):
                    self.release(osname, fault=fault)
                    prefix = self.case / (osname + "-" + fault)
                    self.install("github", osname, "0.12.0", prefix, "--local", success=False)
                    self.assertFalse(prefix.exists())
                    self.assertEqual((self.case / "program-invocations").read_text(), "")

    def test_terminal_acceptance_requires_yes(self):
        self.release("linux")
        for label, reply, accepted in (("no", b"no\n", False), ("short-y", b"y\n", False),
                                       ("eof", b"\x04", False), ("yes", b"yes\n", True)):
            with self.subTest(reply=label):
                prefix = self.case / label
                output, _ = self.install("github", "linux", "0.12.0", prefix, "--local",
                                         accept=False, terminal=reply, success=accepted)
                self.assertIn((ROOT / "licenses/LISPWORKS-RUNTIME.txt").read_text(), output)
                if accepted:
                    self.assert_installed_licenses(prefix, "linux", acceptance="terminal")
                else:
                    self.assertFalse(prefix.exists())
                    self.assertEqual((self.case / "program-invocations").read_text(), "")

    def test_license_destination_symlinks_preserve_previous_install(self):
        self.release("linux")
        prefix = self.case / "installed"
        self.install("github", "linux", "0.12.0", prefix, "--local")
        home = prefix / "share/taffish"
        licenses = home / "share/licenses"
        receipt = home / "install-receipt.toml"
        before = receipt.read_bytes()
        outside = self.case / "outside"
        licenses.rename(outside)
        licenses.symlink_to(outside, target_is_directory=True)
        self.install("github", "linux", "0.12.0", prefix, "--local", success=False)
        self.assertEqual(receipt.read_bytes(), before)
        self.assertTrue(licenses.is_symlink())
        licenses.unlink()
        outside.rename(licenses)
        runtime = licenses / RUNTIME_FILES["linux"]
        contents = runtime.read_bytes()
        runtime.rename(outside)
        runtime.symlink_to(outside)
        self.install("github", "linux", "0.12.0", prefix, "--local", success=False)
        self.assertEqual(receipt.read_bytes(), before)
        self.assertEqual(outside.read_bytes(), contents)
        self.assertTrue(runtime.is_symlink())

    def test_receipt_failure_rolls_back_licenses_and_binaries(self):
        tools = self.case / "bin"
        tools.mkdir()
        mv = tools / "mv"
        mv.write_text('''#!/bin/sh
case "$1:$2" in
    */.install-receipt.*:*/install-receipt.toml)
        if [ -f "$RECEIPT_FAIL_ONCE" ]; then
            rm "$RECEIPT_FAIL_ONCE"
            exit 41
        fi
        ;;
esac
exec /bin/mv "$@"
''')
        mv.chmod(0o755)
        for changed in (False, True):
            with self.subTest(changed_binaries=changed):
                self.release("linux")
                prefix = self.case / ("changed" if changed else "same")
                self.install("github", "linux", "0.12.0", prefix, "--local")
                home = prefix / "share/taffish"
                licenses = home / "share/licenses"
                marker = licenses / "local-note.txt"
                marker.write_text("keep user file")
                protected = [home / "install-receipt.toml", *licenses.iterdir(),
                             *(prefix / "bin" / name for name in PROGRAMS)]
                before = {path: path.read_bytes() for path in protected}
                self.release("linux", runtime_suffix=b"\nTest-only updated terms\n",
                             binary_suffix=b"# updated fixture\n" if changed else b"")
                failure = self.case / "receipt-failure"
                failure.touch()
                self.install("github", "linux", "0.12.0", prefix, "--local", success=False)
                self.assertFalse(failure.exists(), "fault must reach receipt commit")
                self.assertEqual({path: path.read_bytes() for path in protected}, before)
                self.assertFalse(list((home / "share").glob(".licenses-install.*")))
                self.install("github", "linux", "0.12.0", prefix, "--local")
                self.assertEqual(marker.read_text(), "keep user file")
                runtime = licenses / RUNTIME_FILES["linux"]
                self.assertTrue(runtime.read_bytes().endswith(b"\nTest-only updated terms\n"))
                receipt = (home / "install-receipt.toml").read_text()
                self.assertIn(f'runtime_license_sha256 = "{digest(runtime.read_bytes())}"', receipt)

    def test_dry_run_selects_platform_without_download(self):
        prefix = self.case / "untouched"
        for version in ("0.12.0", "0.13.0", "1.0.0"):
            for provider in PROVIDERS:
                output, requests = self.install(provider, "darwin", version, prefix, "--dry-run")
                self.assertIn(f"/target/packages-{version}/taffish-{version}-darwin-arm64.tar.xz", output)
                self.assertFalse(requests)
        self.assertFalse(prefix.exists())

    def test_named_local_archive_and_explicit_url(self):
        name = self.release("linux")
        local = self.checkout / "target" / "packages-0.12.0" / name
        url = PROVIDERS["github"][1] + "/v0.12.0/target/packages-0.12.0/" + name
        for flag, location in (("--archive", str(local)), ("--url", url)):
            prefix = self.case / flag[2:]
            _, requests = self.install("github", "linux", "0.12.0", prefix, flag, location)
            if flag == "--archive":
                self.assertFalse(requests)
            else:
                self.assertIn(url, requests)
            receipt = (prefix / "share/taffish/install-receipt.toml").read_text()
            self.assertIn('verification = "gpg"', receipt)
            self.assertIn(f'archive_sha256 = "{digest(local.read_bytes())}"', receipt)
        (local.parent / "ARCHIVE-SHA256SUMS").unlink()
        untouched = self.case / "absent"
        for flag, location in (("--archive", str(local)), ("--url", url)):
            output, _ = self.install("github", "linux", "0.12.0", untouched, flag, location,
                                     success=False)
            self.assertIn("archive checksum manifest is unavailable", output)
            self.assertFalse(untouched.exists())

    def test_local_discovery_and_install_scope(self):
        name = self.release("darwin")
        packages = self.checkout / "target" / "packages-0.12.0"
        for scope in ("--user", "--system"):
            output, requests = self.install("github", "darwin", "0.12.0", self.case / "dry",
                                            "--local", scope, "--dry-run")
            self.assertRegex(output, rf"scope\s*:\s*{scope[2:]}\b")
            self.assertIn(name, output)
            self.assertFalse(requests)
        self.assertFalse((self.case / "dry").exists())

        for provider in PROVIDERS:
            if provider == "gitee":
                # A portable kit beside the script takes priority over the checkout.
                for asset in packages.iterdir():
                    shutil.copy2(asset, self.install_dir / asset.name)
                (packages / name).write_bytes(b"damaged fallback")
            prefix = self.case / provider
            output, requests = self.install(provider, "darwin", "0.12.0", prefix, "--local", "--verify", "gpg")
            self.assertFalse(requests)
            self.assertIn("update=skipped", output)
            receipt = (prefix / "share/taffish/install-receipt.toml").read_text()
            self.assertIn('archive_verification = "gpg"', receipt)
            self.assertIn('verification = "gpg"', receipt)
            self.assertIn(f'archive_asset = "{name}"', receipt)

    def test_local_renamed_archive_keeps_both_verification_layers(self):
        name = self.release("linux")
        packages = self.checkout / "target" / "packages-0.12.0"
        relocated = self.case / "offline files"
        shutil.copytree(packages, relocated)
        renamed = relocated / "renamed payload"
        (relocated / name).rename(renamed)
        prefix = self.case / "installed"
        options = ("--local", "--archive", str(renamed), "--verify", "gpg")
        output, requests = self.install("gitee", "linux", "0.12.0", prefix, *options)
        self.assertFalse(requests)
        self.assertIn("update=skipped", output)
        receipt = prefix / "share/taffish/install-receipt.toml"
        self.assertIn('archive_verification = "gpg"', receipt.read_text())
        self.assertIn('verification = "gpg"', receipt.read_text())
        self.assertIn(f'archive_asset = "{name}"', receipt.read_text())
        self.assertIn(f'archive_sha256 = "{digest(renamed.read_bytes())}"', receipt.read_text())

        original_receipt = receipt.read_bytes()
        for fault in ("bad-archive", "bad-outer-signature", "bad-inner-signature", "missing-outer"):
            with self.subTest(fault=fault):
                self.release("linux", fault=fault)
                shutil.rmtree(relocated)
                shutil.copytree(packages, relocated)
                (relocated / name).rename(renamed)
                # A valid package in the normal location must not mask a bad explicit file.
                self.release("linux")
                _, requests = self.install("gitee", "linux", "0.12.0", prefix, *options, success=False)
                self.assertFalse(requests)
                self.assertEqual(receipt.read_bytes(), original_receipt)

    def test_local_missing_archive_and_remote_overrides(self):
        prefix = self.case / "untouched"
        output, requests = self.install("github", "linux", "0.12.0", prefix, "--local", success=False)
        self.assertIn("taffish-0.12.0-linux-amd64.tar.gz", output)
        self.assertIn("--archive", output)
        self.assertFalse(requests)
        self.release("linux")
        for remote_option in ("--url", "--raw-base-url", "--taf-url", "--share-url", "--release-key-url",
                              "--signature-url", "--checksum-url"):
            with self.subTest(remote_option=remote_option):
                _, requests = self.install("github", "linux", "0.12.0", prefix,
                                           "--local", remote_option, "https://example.invalid/file", success=False)
                self.assertFalse(requests)
        _, requests = self.install("github", "linux", "0.11.0", prefix, "--local", success=False)
        self.assertFalse(requests)
        self.assertFalse(prefix.exists())

    def test_integrity_failures_preserve_install(self):
        prefix = self.case / "previous-install"
        self.release("linux", "0.11.0")
        self.install("gitee", "linux", "0.11.0", prefix, "--verify", "gpg")
        protected = [prefix / "share/taffish/install-receipt.toml"] + [prefix / "bin" / n for n in PROGRAMS]
        before = [path.read_bytes() for path in protected]
        faults = {"missing-outer": "archive checksum manifest is unavailable",
                  "bad-archive": "SHA256 mismatch for taffish-0.12.0-linux-amd64.tar.gz",
                  "bad-outer-signature": "checksum manifest signature verification failed",
                  "missing-inner": "requires a checksum manifest",
                  "bad-binary": "SHA256 mismatch for taf-linux-amd64-0.12.0",
                  "bad-inner-signature": "checksum manifest signature verification failed"}
        for fault, expected in faults.items():
            self.release("linux", fault=fault)
            for verify in ("auto", "gpg"):
                with self.subTest(fault=fault, verify=verify):
                    output, _ = self.install("gitee", "linux", "0.12.0", prefix,
                                             "--verify", verify, success=False)
                    self.assertIn(expected, output)
                    self.assertEqual([path.read_bytes() for path in protected], before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
