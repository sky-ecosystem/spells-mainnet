import contextlib
import inspect
import io
import subprocess
import sys
import unittest
from unittest import mock

from test_support import CLI, FoundryFixture, load_cli_module


class CliBoundaryTests(unittest.TestCase):
    def test_entrypoint_owns_cli_logic(self):
        module = load_cli_module()
        self.assertEqual(module.main.__module__, module.__name__)

    def test_subcommand_handlers_declare_integer_exit_codes(self):
        module = load_cli_module()
        self.assertIs(inspect.signature(module.install.handle).return_annotation, int)
        self.assertIs(inspect.signature(module.verify.handle).return_annotation, int)

    def test_dispatches_only_to_subcommand_handlers(self):
        module = load_cli_module()
        with mock.patch.object(
            module.install, "handle", return_value=2
        ) as install_handle:
            self.assertEqual(module.main(["install"]), 2)
        install_handle.assert_called_once_with()

        with mock.patch.object(
            module.verify, "handle", return_value=0
        ) as verify_handle:
            self.assertEqual(module.main(["verify"]), 0)
        verify_handle.assert_called_once_with()

    def test_entrypoint_does_not_expose_domain_implementation(self):
        module = load_cli_module()
        forbidden = {
            "select_release",
            "verify_binary_paths",
            "extract_release_archive",
            "Installation",
            "install_selected_release",
            "collect_source_metadata",
        }
        self.assertTrue(forbidden.isdisjoint(vars(module)))


class CliBehaviorTests(FoundryFixture, unittest.TestCase):
    def test_failure_never_uses_path_warning_exit_code(self):
        self.env.update({"TEST_ATTEST_FAIL": "cast", "TEST_ATTEST_STATUS": "2"})
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.version_log(), [])

    def test_nonzero_gh_statuses_are_normalized_to_one(self):
        self.env.update({"TEST_ATTEST_FAIL": "cast", "TEST_ATTEST_STATUS": "42"})
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 1)

        self.env.pop("TEST_ATTEST_FAIL")
        self.env.pop("TEST_ATTEST_STATUS")
        self.env["TEST_DOWNLOAD_STATUS"] = "17"
        result = self.run_cli("install", "none")
        self.assertEqual(result.returncode, 1)

    def test_main_normalizes_interrupt_and_termination_to_one(self):
        module = self.load_cli_module()
        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            with mock.patch.object(
                module.verify, "handle", side_effect=KeyboardInterrupt
            ):
                self.assertEqual(module.main(["verify"]), 1)
            with mock.patch.object(
                module.install,
                "handle",
                side_effect=lambda: module.terminate(None, None),
            ):
                self.assertEqual(module.main(["install"]), 1)

    def test_main_normalizes_process_signals_to_one(self):
        probe = r"""
import os
import signal
import sys
import importlib.util
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]).parent))
spec = importlib.util.spec_from_file_location("setup_foundry_signal_probe", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.verify.handle = lambda: os.kill(os.getpid(), getattr(signal, sys.argv[2]))
sys.exit(module.main(["verify"]))
"""
        for signal_name in ("SIGINT", "SIGTERM"):
            with self.subTest(signal=signal_name):
                result = subprocess.run(
                    [sys.executable, "-c", probe, str(CLI), signal_name],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 1, result.stdout)

    def test_invalid_and_missing_commands_fail_with_usage(self):
        for command in ("invalid", None):
            with self.subTest(command=command):
                result = self.run_cli(command)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Usage:", result.stdout)


if __name__ == "__main__":
    unittest.main()
