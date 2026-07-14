import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from setup_foundry.runtime import tooling_sha256
sys.path.insert(0, str(Path(__file__).resolve().parent))
from support import CLI, FoundryFixture


class RuntimeHashTests(unittest.TestCase):
    def test_hash_is_deterministic_and_covers_only_runtime_python(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "setup_foundry").mkdir()
            (root / "setup-foundry.py").write_text("entry\n")
            (root / "setup_foundry" / "z.py").write_text("z\n")
            (root / "setup_foundry" / "a.py").write_text("a\n")
            baseline = tooling_sha256(root)

            self.assertEqual(tooling_sha256(root), baseline)
            (root / "tests").mkdir()
            (root / "tests" / "test-cli.py").write_text("ignored\n")
            (root / "setup_foundry" / "__pycache__").mkdir()
            (root / "setup_foundry" / "__pycache__" / "a.pyc").write_bytes(b"ignored")
            self.assertEqual(tooling_sha256(root), baseline)

            (root / "setup_foundry" / "a.py").write_text("changed\n")
            self.assertNotEqual(tooling_sha256(root), baseline)

    def test_hash_includes_paths_to_avoid_ambiguous_concatenation(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            first_root = Path(first)
            second_root = Path(second)
            for root in (first_root, second_root):
                (root / "setup_foundry").mkdir()
                (root / "setup-foundry.py").write_text("")
            (first_root / "setup_foundry" / "a.py").write_text("bc")
            (second_root / "setup_foundry" / "ab.py").write_text("c")
            self.assertNotEqual(tooling_sha256(first_root), tooling_sha256(second_root))



class RuntimeBehaviorTests(FoundryFixture, unittest.TestCase):
    def test_prerequisites_require_gh_git_and_authentication(self):
        minimal_bin = self.fixture / "minimal-bin"
        minimal_bin.mkdir()
        (minimal_bin / "git").symlink_to(self.fake_bin / "git")
        env = self.env.copy()
        env["PATH"] = str(minimal_bin)
        result = subprocess.run(
            [sys.executable, str(CLI), "verify"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env, check=False,
        )
        self.assertIn("required command not found: gh", result.stdout)

        (minimal_bin / "git").unlink()
        (minimal_bin / "gh").symlink_to(self.fake_bin / "gh")
        result = subprocess.run(
            [sys.executable, str(CLI), "verify"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env, check=False,
        )
        self.assertIn("required command not found: git", result.stdout)

        self.env["TEST_AUTH_STATUS"] = "1"
        result = self.run_cli("verify")
        self.assertIn("GitHub CLI is not authenticated for github.com", result.stdout)


if __name__ == "__main__":
    unittest.main()
