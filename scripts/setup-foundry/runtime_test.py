import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import runtime
from mocks.cli_environment import CLI, FoundryFixture
from runtime import tooling_sha256


class RuntimeHashTests(unittest.TestCase):
    def test_hash_is_deterministic_and_covers_only_runtime_python(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "setup-foundry.py").write_text("entry\n")
            (root / "z.py").write_text("z\n")
            (root / "a.py").write_text("a\n")
            (root / "commands").mkdir()
            (root / "commands" / "install.py").write_text("install\n")
            baseline = tooling_sha256(root)

            self.assertEqual(tooling_sha256(root), baseline)
            (root / "a_test.py").write_text("ignored\n")
            (root / "mocks").mkdir()
            (root / "mocks" / "cli_environment.py").write_text("ignored\n")
            (root / "setup_foundry_test.py").write_text("ignored\n")
            (root / "__pycache__").mkdir()
            (root / "__pycache__" / "a.pyc").write_bytes(b"ignored")
            self.assertEqual(tooling_sha256(root), baseline)

            (root / "a.py").write_text("changed\n")
            self.assertNotEqual(tooling_sha256(root), baseline)

    def test_hash_includes_paths_to_avoid_ambiguous_concatenation(self):
        with (
            tempfile.TemporaryDirectory() as first,
            tempfile.TemporaryDirectory() as second,
        ):
            first_root = Path(first)
            second_root = Path(second)
            for root in (first_root, second_root):
                (root / "setup-foundry.py").write_text("")
            (first_root / "a.py").write_text("bc")
            (second_root / "ab.py").write_text("c")
            self.assertNotEqual(tooling_sha256(first_root), tooling_sha256(second_root))


class RuntimeBehaviorTests(FoundryFixture, unittest.TestCase):
    def test_run_normalizes_nonzero_process_status(self):
        result = subprocess.CompletedProcess(
            ["command"], returncode=42, stdout="", stderr="process failed"
        )
        with mock.patch.object(runtime.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(
                runtime.SetupError, "could not run command: process failed"
            ):
                runtime.run(["command"], "could not run command")

    def test_prerequisites_require_gh_git_and_authentication(self):
        minimal_bin = self.fixture / "minimal-bin"
        minimal_bin.mkdir()
        (minimal_bin / "git").symlink_to(self.fake_bin / "git")
        env = self.env.copy()
        env["PATH"] = str(minimal_bin)
        result = subprocess.run(
            [sys.executable, str(CLI), "verify"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
            check=False,
        )
        self.assertIn("required command not found: gh", result.stdout)

        (minimal_bin / "git").unlink()
        (minimal_bin / "gh").symlink_to(self.fake_bin / "gh")
        result = subprocess.run(
            [sys.executable, str(CLI), "verify"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
            check=False,
        )
        self.assertIn("required command not found: git", result.stdout)

        self.env["TEST_AUTH_STATUS"] = "1"
        result = self.run_cli("verify")
        self.assertIn("GitHub CLI is not authenticated for github.com", result.stdout)


if __name__ == "__main__":
    unittest.main()
