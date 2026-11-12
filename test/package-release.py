"""Exercise the shell release packager with small, genuinely signed inputs."""

import hashlib
import json
import sys
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.12.0"
PROGRAMS = ("taf", "taffish", "taffish-mcp")
PLATFORMS = (("darwin-arm64", "xz"), ("linux-amd64", "gz"))
MANIFEST = "SHA256SUMS"
KEY = "TAFFISH-RELEASE-KEY.asc"
RESOURCES = (
    "LICENSE", "vendor/han/LICENSE",
    "completion/README.md", "completion/bash/taf", "completion/bash/taffish",
    "completion/fish/taf.fish", "completion/fish/taffish.fish",
    "completion/zsh/_taf", "completion/zsh/_taffish",
    "vim-highlight/README.md", "vim-highlight/ftdetect/taf.vim",
    "vim-highlight/syntax/old-taf.vim", "vim-highlight/syntax/taf.vim",
)
RUNTIME_RESOURCES = {
    "darwin-arm64": "licenses/SBCL-NOTICES.txt",
    "linux-amd64": "licenses/LISPWORKS-RUNTIME.txt",
}


class ReleasePackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # A short socket path also works with gpg-agent on macOS.
        key_home = tempfile.TemporaryDirectory(prefix="taf-sign-", dir="/tmp")
        cls.addClassCleanup(key_home.cleanup)
        cls.addClassCleanup(subprocess.run, ["gpgconf", "--homedir", key_home.name,
                                            "--kill", "gpg-agent"], check=False)
        cls.key_home = key_home.name
        cls.gpg = ["gpg", "--no-options", "--homedir", key_home.name, "--batch", "--yes",
                   "--pinentry-mode", "loopback", "--passphrase", ""]
        subprocess.run(cls.gpg + ["--quick-generate-key", "TAFFISH package test",
                                  "ed25519", "sign", "0"], check=True)
        listing = subprocess.check_output(cls.gpg + ["--with-colons", "--list-keys"], text=True)
        cls.fingerprint = next(line.split(":")[9] for line in listing.splitlines()
                               if line.startswith("fpr:"))
        cls.key = subprocess.check_output(cls.gpg + ["--armor", "--export", cls.fingerprint])

    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="taffish-package-test-")
        self.addCleanup(temp.cleanup)
        self.work = Path(temp.name)
        self.repo = self.work / "source tree"
        self.target = self.repo / "target"
        self.target.mkdir(parents=True)
        self.script = self.target / "make-sha-asc.sh"
        signing_template = Path("scripts/sign-release-archives.sh.in")
        (self.repo / signing_template.parent).mkdir()
        shutil.copyfile(ROOT / signing_template, self.repo / signing_template)
        split_helper = Path("scripts/split-release-archive.sh")
        shutil.copyfile(ROOT / split_helper, self.repo / split_helper)
        template = Path("install/install-taffish.template.sh")
        template_text = (ROOT / template).read_text()
        pins = re.findall(r"^TAFFISH_RELEASE_KEY_FINGERPRINT=([0-9A-F]{40})$", template_text, re.M)
        self.assertEqual(len(pins), 1)
        program_signer = Path("target/make-sha-asc.sh")
        text, count = re.subn(r"^fingerprint=" + pins[0] + "$", "fingerprint=" + self.fingerprint,
                              (ROOT / program_signer).read_text(), flags=re.M)
        self.assertEqual(count, 1)
        (self.repo / program_signer).write_text(text)
        (self.repo / program_signer).chmod(0o755)
        (self.repo / template.parent).mkdir()
        (self.repo / template).write_text(template_text.replace(pins[0], self.fingerprint))
        for name in (*RESOURCES, *RUNTIME_RESOURCES.values()):
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((ROOT / name).read_bytes())
        (self.repo / "completion/other-local-file").write_text("private fixture")
        self.out = self.work / "release output"
        for platform, _ in PLATFORMS:
            for program in PROGRAMS:
                name = f"{program}-{platform}-{VERSION}"
                (self.target / name).write_bytes(name.encode())
        (self.target / KEY).write_bytes(self.key)
        self.run_signer(directory=self.target)

    def pack(self, *args, success=True):
        result = subprocess.run(["sh", str(self.script), "--package-only", VERSION, *args], cwd=self.work,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_python_compatibility_entry_packages_without_signing(self):
        entry = self.repo / "scripts/package-release.py"
        shutil.copyfile(ROOT / "scripts/package-release.py", entry)
        help_result = subprocess.run([sys.executable, str(entry), "--help"],
                                     cwd=self.work, capture_output=True, text=True)
        self.assertEqual(help_result.returncode, 0, help_result.stdout + help_result.stderr)
        result = subprocess.run([sys.executable, str(entry), VERSION, str(self.target), str(self.out)],
                                cwd=self.work, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.out / "ARCHIVE-SHA256SUMS").is_file())
        self.assertFalse((self.out / "ARCHIVE-SHA256SUMS.asc").exists())

    def test_default_outputs_match_explicit_release(self):
        self.pack()
        default = self.target / f"packages-{VERSION}"
        rows = (default / "ARCHIVE-SHA256SUMS").read_text().splitlines()
        self.assertEqual(len(rows), 2)
        for row, (platform, fmt) in zip(rows, PLATFORMS):
            digest, asset = row.split()
            self.assertEqual(asset, f"taffish-{VERSION}-{platform}.tar.{fmt}")
            path = default / asset
            self.assertEqual(digest, hashlib.sha256(path.read_bytes()).hexdigest())
            with tarfile.open(path, f"r:{fmt}") as archive:
                programs = [f"{p}-{platform}-{VERSION}" for p in PROGRAMS]
                executable_paths = {"target/" + name for name in programs}
                targets = (*programs, MANIFEST, MANIFEST + ".asc", KEY)
                files = [member for member in archive if not member.isdir()]
                expected = [*RESOURCES, RUNTIME_RESOURCES[platform],
                            *("target/" + name for name in targets)]
                self.assertCountEqual([f.name for f in files], expected)
                for member in files:
                    self.assertTrue(member.isfile())
                    self.assertEqual(member.mode, 0o755 if member.name in executable_paths else 0o644)
                    self.assertEqual(archive.extractfile(member).read(), (self.repo / member.name).read_bytes())
        self.assertEqual((default / KEY).read_bytes(), self.key)
        self.assertTrue(os.access(default / "make-sha-asc.sh", os.X_OK))
        self.assertFalse((default / "ARCHIVE-SHA256SUMS.asc").exists())
        mac = default / f"taffish-{VERSION}-darwin-arm64.tar.xz"
        part_rows = Path(str(mac) + ".parts").read_text().splitlines()
        self.assertEqual(len(part_rows), 1)  # The signed fixture archive is under 8 MiB.
        part_digest, part_name = part_rows[0].split()
        self.assertEqual(part_name, mac.name + ".part-aa")
        self.assertEqual((default / part_name).read_bytes(), mac.read_bytes())
        self.assertEqual(part_digest, hashlib.sha256(mac.read_bytes()).hexdigest())
        self.assertFalse(list(default.glob("*linux*.part*")))
        # Identical bytes with different source mtimes must give identical archives.
        for path in [self.target / f"taf-linux-amd64-{VERSION}", self.repo / "LICENSE"]:
            os.utime(path, (946684800, 946684800))
        self.pack(self.target, self.out)
        self.assertEqual((self.out / "ARCHIVE-SHA256SUMS").read_bytes(),
                         (default / "ARCHIVE-SHA256SUMS").read_bytes())
        self.pack(success=False)
        self.assertEqual((default / "ARCHIVE-SHA256SUMS").read_text().splitlines(), rows)

    def test_license_inputs_must_be_nonempty_regular_files(self):
        for name in ("LICENSE", "vendor/han/LICENSE", *RUNTIME_RESOURCES.values()):
            path = self.repo / name
            original = path.read_bytes()
            for kind in ("missing", "empty", "symlink"):
                with self.subTest(path=name, kind=kind):
                    path.unlink()
                    output = self.work / (name.replace("/", "-") + "-" + kind)
                    try:
                        if kind == "empty":
                            path.write_bytes(b"")
                        elif kind == "symlink":
                            path.symlink_to(self.repo / "completion/README.md")
                        self.pack(self.target, output, success=False)
                        self.assertFalse(output.exists())
                        self.assertFalse((self.work / ("." + output.name + ".package-lock")).exists())
                    finally:
                        if path.is_symlink() or path.exists():
                            path.unlink()
                        path.write_bytes(original)

    def run_signer(self, *args, directory=None, success=True, key_home=None, combined=False, extra_env=None):
        # Invoke the executable from outside its own directory, with disposable keys.
        if directory == self.target and not combined:
            args = ("--sign-only", *args)
        result = subprocess.run([str((directory or self.out) / "make-sha-asc.sh"), *args],
                                cwd=self.work,
                                env=dict(os.environ, GNUPGHOME=key_home or self.key_home, **(extra_env or {})),
                                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)

        return result

    def remove_inner_signature(self):
        for name in (MANIFEST, MANIFEST + ".asc"):
            (self.target / name).unlink()

    def tool_wrapper(self, name, body):
        directory = self.work / (name + " wrapper")
        directory.mkdir()
        script = directory / name
        script.write_text("#!" + sys.executable + "\n" + body)
        script.chmod(0o755)
        return str(directory) + os.pathsep + os.environ["PATH"]

    def test_default_signs_then_packages_and_leaves_outer_signature_to_maintainer(self):
        self.remove_inner_signature()
        self.run_signer(directory=self.target, combined=True)
        package = self.target / ("packages-" + VERSION)
        self.assertTrue((self.target / (MANIFEST + ".asc")).is_file())
        self.assertFalse((package / "ARCHIVE-SHA256SUMS.asc").exists())
        self.assertTrue((package / "make-sha-asc.sh").is_file())
        for platform, fmt in PLATFORMS:
            with tarfile.open(package / f"taffish-{VERSION}-{platform}.tar.{fmt}") as archive:
                for name in (MANIFEST, MANIFEST + ".asc"):
                    self.assertEqual(archive.extractfile("target/" + name).read(),
                                     (self.target / name).read_bytes())
        self.run_signer(directory=package)
        status = subprocess.check_output(self.gpg + ["--status-fd", "1", "--verify",
            str(package / "ARCHIVE-SHA256SUMS.asc"), str(package / "ARCHIVE-SHA256SUMS")], text=True)
        self.assertIn("[GNUPG:] VALIDSIG " + self.fingerprint + " ", status)

    def test_valid_inner_signature_still_continues_to_packaging(self):
        before = (self.target / (MANIFEST + ".asc")).read_bytes()
        self.run_signer(directory=self.target, combined=True)
        self.assertEqual((self.target / (MANIFEST + ".asc")).read_bytes(), before)
        self.assertTrue((self.target / ("packages-" + VERSION) / "ARCHIVE-SHA256SUMS").is_file())

    def test_rebuilt_program_replaces_old_signature_then_packages(self):
        before = (self.target / (MANIFEST + ".asc")).read_bytes()
        rebuilt = self.target / f"taf-darwin-arm64-{VERSION}"
        rebuilt.write_bytes(b"rebuilt macOS program")
        real_gpg = shutil.which("gpg")
        # Approve overwriting the staged signature only for this disposable key.
        path = self.tool_wrapper("gpg", "import os,sys\n" +
            "os.execv(" + repr(real_gpg) + ", [" + repr(real_gpg) + ", '--yes', *sys.argv[1:]])\n")
        self.run_signer(directory=self.target, combined=True, extra_env={"PATH": path})
        self.assertNotEqual((self.target / (MANIFEST + ".asc")).read_bytes(), before)
        self.assertIn(hashlib.sha256(rebuilt.read_bytes()).hexdigest() + "  " + rebuilt.name,
                      (self.target / MANIFEST).read_text())
        archive = self.target / ("packages-" + VERSION) / f"taffish-{VERSION}-darwin-arm64.tar.xz"
        with tarfile.open(archive) as package:
            self.assertEqual(package.extractfile("target/" + rebuilt.name).read(), rebuilt.read_bytes())
            self.assertEqual(package.extractfile("target/" + MANIFEST + ".asc").read(),
                             (self.target / (MANIFEST + ".asc")).read_bytes())

    def test_default_preflight_preserves_old_signature_and_output(self):
        before = [(self.target / name).read_bytes() for name in (MANIFEST, MANIFEST + ".asc")]
        (self.target / f"taf-darwin-arm64-{VERSION}").write_bytes(b"rebuilt")
        output = self.target / ("packages-" + VERSION)
        output.mkdir()
        sentinel = output / "keep"
        sentinel.write_bytes(b"existing release")
        self.run_signer(directory=self.target, combined=True, success=False)
        self.assertEqual(sentinel.read_bytes(), b"existing release")
        self.assertEqual([(self.target / name).read_bytes() for name in (MANIFEST, MANIFEST + ".asc")], before)
        sentinel.unlink()
        output.rmdir()
        (self.repo / "licenses/SBCL-NOTICES.txt").unlink()
        self.run_signer(directory=self.target, combined=True, success=False)
        self.assertFalse(output.exists())
        self.assertEqual([(self.target / name).read_bytes() for name in (MANIFEST, MANIFEST + ".asc")], before)
        self.assertFalse((self.target / ".SHA256SUMS.sign-lock").exists())

    def test_all_modes_respect_the_same_input_lock(self):
        lock = self.target / ".SHA256SUMS.sign-lock"
        lock.mkdir()
        sentinel = lock / "owner"
        sentinel.write_bytes(b"another process")
        for mode in ((), ("--sign-only",), ("--package-only",)):
            self.run_signer(*mode, directory=self.target, combined=True, success=False)
            self.assertEqual(sentinel.read_bytes(), b"another process")
        self.assertFalse((self.target / ("packages-" + VERSION)).exists())

    def test_default_signing_failure_does_not_package(self):
        before = [(self.target / name).read_bytes() for name in (MANIFEST, MANIFEST + ".asc")]
        (self.target / f"taf-darwin-arm64-{VERSION}").write_bytes(b"rebuilt")
        with tempfile.TemporaryDirectory(prefix="taf-no-key-", dir="/tmp") as empty_home:
            try:
                self.run_signer(directory=self.target, combined=True, success=False, key_home=empty_home)
            finally:
                subprocess.run(["gpgconf", "--homedir", empty_home, "--kill", "gpg-agent"], check=False)
        self.assertEqual([(self.target / name).read_bytes() for name in (MANIFEST, MANIFEST + ".asc")], before)
        self.assertFalse((self.target / ("packages-" + VERSION)).exists())
        self.assertFalse((self.target / ".SHA256SUMS.sign-lock").exists())

    def test_compression_failure_keeps_signed_inputs_for_package_only_retry(self):
        self.remove_inner_signature()
        real_tar = shutil.which("tar")
        path = self.tool_wrapper("tar", "import os,sys\n" +
            "if sys.argv[1:] != ['--version']: sys.exit(42)\n" +
            "os.execv(" + repr(real_tar) + ", [" + repr(real_tar) + ", *sys.argv[1:]])\n")
        self.run_signer(directory=self.target, combined=True, success=False, extra_env={"PATH": path})
        self.assertTrue((self.target / (MANIFEST + ".asc")).is_file())
        self.assertFalse((self.target / ("packages-" + VERSION)).exists())
        self.assertFalse((self.target / (".packages-" + VERSION + ".package-lock")).exists())
        self.assertFalse((self.target / ".SHA256SUMS.sign-lock").exists())
        before = (self.target / (MANIFEST + ".asc")).read_bytes()
        self.pack()
        self.assertEqual((self.target / (MANIFEST + ".asc")).read_bytes(), before)

    def test_both_signers_pass_utf8_to_real_gpg_even_under_C_locale(self):
        self.remove_inner_signature()
        log = self.work / "gpg-encoding.jsonl"
        real_gpg = shutil.which("gpg")
        path = self.tool_wrapper("gpg", "import os,sys,json,locale\n" +
            "if '--detach-sign' in sys.argv:\n" +
            "    locale.setlocale(locale.LC_ALL, '')\n" +
            "    charset = locale.nl_langinfo(locale.CODESET)\n" +
            "    if charset.upper().replace('-', '') != 'UTF8': sys.exit(86)\n" +
            "    lc = os.environ['LC_ALL']\n" +
            "    if sys.argv[sys.argv.index('--lc-ctype') + 1] != lc: sys.exit(87)\n" +
            "    if sys.argv[sys.argv.index('--lc-messages') + 1] != lc: sys.exit(88)\n" +
            "    with open(" + repr(str(log)) + ", 'a') as out: out.write(json.dumps({'charset':charset,'locale':lc}) + '\\n')\n" +
            "os.execv(" + repr(real_gpg) + ", [" + repr(real_gpg) + ", *sys.argv[1:]])\n")
        env = {"PATH": path, "LC_ALL": "C"}
        self.run_signer(directory=self.target, combined=True, extra_env=env)
        self.run_signer(directory=self.target / ("packages-" + VERSION), extra_env=env)
        rows = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(rows), 2)
        self.assertTrue(all(row["charset"].upper().replace("-", "") == "UTF8" for row in rows))

    def test_program_manifest_order_and_repeat_signing(self):
        manifest = self.target / MANIFEST
        signature = self.target / (MANIFEST + ".asc")
        names = [f"{program}-{platform}-{VERSION}" for program in PROGRAMS
                 for platform, _ in PLATFORMS]
        self.assertEqual(manifest.read_text().splitlines(),
                         [f"{hashlib.sha256(name.encode()).hexdigest()}  {name}" for name in names])
        before = [path.read_bytes() for path in (manifest, signature)]
        for path in (manifest, signature):
            os.utime(path, (946684800, 946684800))
        self.run_signer(directory=self.target)
        self.assertEqual([path.read_bytes() for path in (manifest, signature)], before)
        self.assertEqual([path.stat().st_mtime for path in (manifest, signature)], [946684800] * 2)

    def test_program_signer_rejects_ambiguous_and_incomplete_sets(self):
        manifest = self.target / MANIFEST
        signature = self.target / (MANIFEST + ".asc")
        manifest.unlink()
        signature.unlink()
        foreign = self.target / "taffish-mcp-linux-amd64-0.11.9-rc.1"
        foreign.write_bytes(b"another release")
        self.run_signer(directory=self.target, success=False)
        self.assertFalse(manifest.exists())
        self.assertFalse(signature.exists())
        self.run_signer(VERSION, directory=self.target)
        self.pack(self.target, self.out)
        before = [path.read_bytes() for path in (manifest, signature)]
        foreign.unlink()
        (self.target / f"taffish-mcp-linux-amd64-{VERSION}").unlink()
        self.run_signer(directory=self.target, success=False)
        self.assertEqual([path.read_bytes() for path in (manifest, signature)], before)

    def test_program_signing_failure_preserves_existing_manifest(self):
        manifest = self.target / MANIFEST
        signature = self.target / (MANIFEST + ".asc")
        before = [path.read_bytes() for path in (manifest, signature)]
        (self.target / f"taf-darwin-arm64-{VERSION}").write_bytes(b"rebuilt")
        with tempfile.TemporaryDirectory(prefix="taf-no-key-", dir="/tmp") as empty_home:
            try:
                self.run_signer(directory=self.target, success=False, key_home=empty_home)
            finally:
                subprocess.run(["gpgconf", "--homedir", empty_home, "--kill", "gpg-agent"],
                               check=False)
        self.assertEqual([path.read_bytes() for path in (manifest, signature)], before)

    def test_archive_signing_and_retry(self):
        self.pack(self.target, self.out)
        manifest = self.out / "ARCHIVE-SHA256SUMS"
        signature = self.out / "ARCHIVE-SHA256SUMS.asc"
        unsigned_files = set(self.out.iterdir())
        with tempfile.TemporaryDirectory(prefix="taf-no-key-", dir="/tmp") as empty_home:
            try:
                self.run_signer(success=False, key_home=empty_home)
            finally:
                subprocess.run(["gpgconf", "--homedir", empty_home, "--kill", "gpg-agent"],
                               check=False)
        self.assertEqual(set(self.out.iterdir()), unsigned_files)
        self.run_signer()
        status = subprocess.check_output(self.gpg + ["--status-fd", "1", "--verify",
                                                      str(signature), str(manifest)], text=True)
        self.assertIn("[GNUPG:] VALIDSIG " + self.fingerprint + " ", status)
        self.assertEqual(set(self.out.iterdir()), unsigned_files | {signature})
        signed = signature.read_bytes()
        self.run_signer(success=False)
        self.assertEqual(signature.read_bytes(), signed)

    def test_signing_rejects_changed_archive_and_incomplete_manifest(self):
        self.pack(self.target, self.out)
        manifest = self.out / "ARCHIVE-SHA256SUMS"
        linux = self.out / f"taffish-{VERSION}-linux-amd64.tar.gz"
        unsigned_files = set(self.out.iterdir())
        original = linux.read_bytes()
        linux.write_bytes(original + b"changed")
        self.run_signer(success=False)
        self.assertEqual(set(self.out.iterdir()), unsigned_files)
        linux.write_bytes(original)
        manifest.write_bytes(manifest.read_bytes().splitlines(keepends=True)[0])
        self.run_signer(success=False)
        self.assertEqual(set(self.out.iterdir()), unsigned_files)

    def test_tampered_second_platform_leaves_no_partial_release(self):
        (self.target / f"taffish-mcp-linux-amd64-{VERSION}").write_bytes(b"modified")
        self.pack(self.target, self.out, success=False)
        self.assertCountEqual(self.work.iterdir(), [self.repo])

    def test_wrong_key_and_invalid_signature_are_rejected(self):
        # The payloads and signature match. Only the trusted fingerprint differs.
        template = Path("install/install-taffish.template.sh")
        trusted = (self.repo / template).read_bytes()
        shutil.copyfile(ROOT / template, self.repo / template)
        self.pack(self.target, self.out, success=False)
        self.assertFalse(self.out.exists())
        (self.repo / template).write_bytes(trusted)
        (self.target / (MANIFEST + ".asc")).write_bytes(b"invalid signature")
        self.pack(self.target, self.out, success=False)
        self.assertFalse(self.out.exists())

    def test_protected_destinations_and_signed_duplicate(self):
        for destination in (self.target, self.target / "output", self.repo / "new", self.work):
            with self.subTest(destination=destination):
                self.pack(self.target, destination, success=False)
        self.assertFalse((self.target / "output").exists())
        self.assertFalse((self.repo / "new").exists())
        first = (self.target / MANIFEST).read_text().splitlines()[0]
        with (self.target / MANIFEST).open("a") as manifest:
            manifest.write(first + "\n")
        subprocess.run(self.gpg + ["--armor", "--detach-sign", str(self.target / MANIFEST)],
                       check=True)
        self.pack(self.target, self.out, success=False)
        self.assertFalse(self.out.exists())


class SplitArchiveTests(unittest.TestCase):
    """The transport operation uses no keys and preserves an already signed package."""

    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="taffish-parts-test-")
        self.addCleanup(temp.cleanup)
        self.work = Path(temp.name)
        self.archive = self.work / f"taffish-{VERSION}-darwin-arm64.tar.xz"

    def split(self, archive=None, success=True, env=None):
        result = subprocess.run(["sh", str(ROOT / "target/make-sha-asc.sh"), "--split-only",
                                 str(archive or self.archive)], cwd=self.work,
                                env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def assert_parts(self, content, count):
        manifest = Path(str(self.archive) + ".parts")
        rows = manifest.read_text().splitlines()
        self.assertEqual(len(rows), count)
        restored = bytearray()
        for index, row in enumerate(rows):
            digest, filename = row.split()
            suffix = chr(97 + index // 26) + chr(97 + index % 26)
            self.assertEqual(filename, self.archive.name + ".part-" + suffix)
            data = (self.work / filename).read_bytes()
            self.assertEqual(len(data), min(8388608, len(content) - len(restored)))
            self.assertEqual(digest, hashlib.sha256(data).hexdigest())
            restored.extend(data)
        self.assertEqual(restored, content)
        self.assertEqual(self.archive.read_bytes(), content)
        self.assertFalse((self.work / ("." + self.archive.name + ".parts-lock")).exists())

    def test_multiple_parts_preserve_existing_release_and_signatures(self):
        content = bytes(range(256)) * 65536 + b"last fragment"
        self.archive.write_bytes(content)
        protected = {}
        for name in ("ARCHIVE-SHA256SUMS", "ARCHIVE-SHA256SUMS.asc", "TAFFISH-RELEASE-KEY.asc"):
            protected[name] = ("existing " + name).encode()
            (self.work / name).write_bytes(protected[name])
        self.split()
        self.assert_parts(content, 3)
        self.assertEqual({name: (self.work / name).read_bytes() for name in protected}, protected)
        self.assertFalse(list(self.work.glob("*linux*")))

    def test_chunk_boundaries(self):
        for size, count in ((1, 1), (8388608, 1), (8388609, 2)):
            with self.subTest(size=size):
                content = b"x" * size
                self.archive.write_bytes(content)
                self.split()
                self.assert_parts(content, count)
                for path in self.work.glob(self.archive.name + ".part*"):
                    path.unlink()

    def test_existing_outputs_and_other_producer_lock_are_preserved(self):
        self.archive.write_bytes(b"original")
        for name in (self.archive.name + ".parts", self.archive.name + ".part-aa"):
            with self.subTest(name=name):
                target = self.work / name
                target.write_bytes(b"keep existing output")
                self.split(success=False)
                self.assertEqual(target.read_bytes(), b"keep existing output")
                self.assertCountEqual(self.work.iterdir(), [self.archive, target])
                target.unlink()
        lock = self.work / ("." + self.archive.name + ".parts-lock")
        lock.mkdir()
        (lock / "owner").write_bytes(b"another producer")
        self.split(success=False)
        self.assertEqual((lock / "owner").read_bytes(), b"another producer")
        self.assertEqual(self.archive.read_bytes(), b"original")

    def test_wrong_platform_empty_symlink_and_oversized_inputs_are_rejected(self):
        linux = self.work / f"taffish-{VERSION}-linux-amd64.tar.gz"
        linux.write_bytes(b"Linux remains whole")
        self.split(linux, success=False)
        self.archive.write_bytes(b"")
        self.split(success=False)
        self.archive.unlink()
        self.archive.symlink_to(linux)
        self.split(success=False)
        self.assertTrue(self.archive.is_symlink())
        self.archive.unlink()
        with self.archive.open("wb") as stream:
            stream.truncate(536870913)  # Sparse, rejected before copying or hashing.
        self.split(success=False)
        self.assertCountEqual(self.work.iterdir(), [linux, self.archive])

    def test_publish_failure_removes_only_new_parts_and_allows_retry(self):
        content = b"a" * 8388608 + b"b"
        self.archive.write_bytes(content)
        tools = self.work / "tools"
        tools.mkdir()
        real_ln = shutil.which("ln")
        wrapper = tools / "ln"
        wrapper.write_text("#!" + sys.executable + "\nimport os,sys\n"
                           "if sys.argv[-1].endswith('.part-ab'): sys.exit(42)\n"
                           f"os.execv({real_ln!r}, [{real_ln!r}, *sys.argv[1:]])\n")
        wrapper.chmod(0o755)
        env = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ["PATH"])
        self.split(success=False, env=env)
        self.assertCountEqual(self.work.iterdir(), [self.archive, tools])
        self.assertEqual(self.archive.read_bytes(), content)
        self.split()
        self.assert_parts(content, 2)


if __name__ == "__main__":
    unittest.main()
