"""Offline unit checks for installer fixtures and explicit harness skips."""

import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SOURCE_ROOT = Path(__file__).resolve().parents[2]


class FixtureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="installer-fixture-unit-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "fixture-repo"
        self.target = self.repo / "target"
        self.target.mkdir(parents=True)
        self.tools = self.root / "tools"
        self.tools.mkdir()
        for name in ("gpg", "gpgv"):
            tool = self.tools / name
            # Prerequisite checks must discover tools, not invoke a verifier.
            tool.write_text("#!/bin/sh\nexit 93\n", encoding="ascii")
            tool.chmod(0o755)
        self.env = dict(os.environ)
        self.env.update({
            "TEST_SOURCE_ROOT": str(SOURCE_ROOT),
            "TAFFISH_TEST_REPO_ROOT": str(self.repo),
            "TAFFISH_TEST_TMP_ROOT": str(self.root),
            "TAFFISH_TEST_LOG_DIR": str(self.root / "logs"),
            "TAFFISH_TEST_FILTER": "",
            "TAFFISH_TEST_TOTAL": "0",
            "TAFFISH_TEST_PASSED": "0",
            "TAFFISH_TEST_FAILED": "0",
            "TAFFISH_TEST_SKIPPED": "0",
            "TAFFISH_TEST_VERSION": "1.2.3",
            "OS": "fixture",
            "ARCH": "arch",
            "PATH": str(self.tools) + os.pathsep + os.environ["PATH"],
        })
        rows = []
        for name, variable in (("taf", "TAF_BIN"), ("taffish", "TAFFISH_BIN"),
                               ("taffish-mcp", "TAFFISH_MCP_BIN")):
            asset = name + "-fixture-arch-1.2.3"
            binary = self.target / asset
            binary.write_bytes((name + " fixture\n").encode())
            self.env[variable] = str(binary)
            rows.append(hashlib.sha256(binary.read_bytes()).hexdigest() + "  " + asset)
        # Extra-platform rows must not prevent selecting the signed manifest.
        rows += ["0" * 64 + "  " + name + "-other-arch-1.2.3"
                 for name in ("taf", "taffish", "taffish-mcp")]
        self.manifest = self.target / "SHA256SUMS"
        self.manifest.write_text("\n".join(rows) + "\n", encoding="ascii")
        for name in ("SHA256SUMS.asc", "TAFFISH-RELEASE-KEY.asc"):
            (self.target / name).write_text("prerequisite fixture only\n", encoding="ascii")

    def run_shell(self, body):
        script = ('set -eu\n'
                  '. "$TEST_SOURCE_ROOT/test/lib/harness.sh"\n'
                  '. "$TEST_SOURCE_ROOT/test/installer/conformance.sh"\n' + body)
        return subprocess.run(["/bin/sh", "-c", script], env=self.env,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, timeout=20, check=False)

    def expect(self, body, code, *messages):
        result = self.run_shell(body)
        self.assertEqual(result.returncode, code, result.stdout)
        for message in messages:
            self.assertIn(message, result.stdout)
        return result.stdout

    def test_pass_summary_is_unchanged(self):
        out = self.expect('run_case pass true\nfinish_tests', 0,
                          'TOTAL: 1, PASSED: 1, FAILED: 0')
        self.assertNotIn('SKIPPED:', out)

    def test_regular_failure_and_unmarked_exit_77_fail(self):
        for code in (1, 77):
            with self.subTest(exit_code=code):
                self.expect(f'run_case failure /bin/sh -c "exit {code}"\nfinish_tests',
                            1, '[FAIL] failure', 'TOTAL: 1, PASSED: 0, FAILED: 1')

    def test_skip_is_visible_and_not_counted_as_pass(self):
        self.expect('run_case pass true\nrun_case optional skip_case "missing GPG"\nfinish_tests',
                    0, '[SKIP] optional', 'missing GPG',
                    'TOTAL: 2, PASSED: 1, FAILED: 0, SKIPPED: 1')

    def test_only_skip_cannot_pass_release_gate(self):
        self.expect('run_case gpg skip_case "missing GPG"\nfinish_tests', 1,
                    'TOTAL: 1, PASSED: 0, FAILED: 0, SKIPPED: 1',
                    'no selected test case passed')

    def test_skip_does_not_hide_failure(self):
        self.expect('run_case fail false\nrun_case optional skip_case "missing GPG"\nfinish_tests',
                    1, 'TOTAL: 2, PASSED: 0, FAILED: 1, SKIPPED: 1')

    def test_filter_with_no_match_still_fails(self):
        self.env['TAFFISH_TEST_FILTER'] = 'absent'
        self.expect('run_case ignored true\nfinish_tests', 1, 'no test cases matched filter')

    def test_six_entry_manifest_is_selected_without_rewriting(self):
        before = self.manifest.read_bytes()
        self.expect('_installer_gpg_prerequisites', 0)
        self.assertEqual(self.manifest.read_bytes(), before)

    def test_missing_tools_skip_with_reason(self):
        self.env['PATH'] = str(self.tools)
        (self.tools / 'gpg').unlink()
        self.expect('_installer_gpg_prerequisites', 77, '[test:SKIP]', 'gpg is required')
        (self.tools / 'gpgv').rename(self.tools / 'gpg')
        self.expect('_installer_gpg_prerequisites', 77, '[test:SKIP]', 'gpgv is required')

    def test_missing_signed_material_is_explicit(self):
        for name in ('SHA256SUMS', 'SHA256SUMS.asc', 'TAFFISH-RELEASE-KEY.asc'):
            with self.subTest(material=name):
                item = self.target / name
                data = item.read_bytes()
                item.unlink()
                self.expect('_installer_gpg_prerequisites', 77, '[test:SKIP]', name)
                item.write_bytes(data)

    def test_unmatched_local_build_skips(self):
        custom = self.root / 'local-taf'
        custom.write_bytes(b'unsigned local build\n')
        self.env['TAF_BIN'] = str(custom)
        self.expect('_installer_gpg_prerequisites', 77, '[test:SKIP]',
                    'selected local build is not covered')

    def test_matching_override_can_use_signed_manifest(self):
        custom = self.root / 'local-taf'
        custom.write_bytes(Path(self.env['TAF_BIN']).read_bytes())
        self.env['TAF_BIN'] = str(custom)
        self.expect('_installer_gpg_prerequisites', 0)

    def test_corrupted_release_binary_fails_not_skips(self):
        Path(self.env['TAF_BIN']).write_bytes(b'tampered release\n')
        out = self.expect('_installer_gpg_prerequisites', 1,
                          'release binary does not match signed manifest')
        self.assertNotIn('[test:SKIP]', out)

    def test_duplicate_manifest_entry_fails(self):
        with self.manifest.open('a') as stream:
            stream.write(self.manifest.read_text().splitlines()[0] + '\n')
        self.expect('_installer_gpg_prerequisites', 1, 'duplicate entries')


if __name__ == '__main__':
    unittest.main(verbosity=2)
