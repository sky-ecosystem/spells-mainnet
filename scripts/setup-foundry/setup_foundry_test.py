import contextlib
import io
import subprocess
import sys
import unittest
from unittest import mock

from mocks.cli_environment import CLI, FoundryFixture, load_cli_module


class CliBehaviorTests(FoundryFixture, unittest.TestCase):
    def test_select_forwards_only_ignore_age(self):
        module = load_cli_module()
        with mock.patch.object(module.select, "handle", return_value=0) as handler:
            self.assertEqual(module.main(["select", "--ignore-age"]), 0)
        handler.assert_called_once_with(True)

        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            self.assertEqual(module.main(["select", "--release", "v2.0.0"]), 1)
        self.assertIn("select does not accept --release", output.getvalue())

    def test_exact_release_options_are_required_and_forwarded(self):
        module = load_cli_module()
        for command_module, command in (
            (module.verify, "verify"),
            (module.install, "install"),
        ):
            with self.subTest(command=command):
                with mock.patch.object(
                    command_module, "handle", return_value=0
                ) as handler:
                    self.assertEqual(
                        module.main([command, "--release", "v2.0.0", "--ignore-age"]),
                        0,
                    )
                handler.assert_called_once_with("v2.0.0", True)

                output = io.StringIO()
                with contextlib.redirect_stderr(output):
                    self.assertEqual(module.main([command]), 1)
                self.assertIn(f"{command} requires --release", output.getvalue())

    def test_release_rejects_missing_and_empty_values(self):
        module = load_cli_module()
        for arguments in (
            ["verify", "--release"],
            ["verify", "--release", ""],
            ["verify", "--release="],
            ["verify", "--release", "--ignore-age"],
        ):
            with self.subTest(arguments=arguments):
                output = io.StringIO()
                with contextlib.redirect_stderr(output):
                    self.assertEqual(module.main(arguments), 1)
                self.assertIn("--release requires a value", output.getvalue())

    def test_short_options_are_rejected(self):
        module = load_cli_module()
        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            self.assertEqual(module.main(["verify", "-r", "v2.0.0"]), 1)
        self.assertIn("unknown option: -r", output.getvalue())

    def test_setup_errors_exit_one(self):
        module = load_cli_module()
        output = io.StringIO()
        with mock.patch.object(
            module.verify, "handle", side_effect=module.SetupError("failed")
        ):
            with contextlib.redirect_stderr(output):
                self.assertEqual(module.main(["verify", "--release", "v2.0.0"]), 1)
        self.assertEqual(output.getvalue(), "Error: failed\n")

    def test_main_normalizes_interrupt_and_termination_to_one(self):
        module = load_cli_module()
        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            with mock.patch.object(
                module.verify, "handle", side_effect=KeyboardInterrupt
            ):
                self.assertEqual(module.main(["verify", "--release", "v2.0.0"]), 1)
            with mock.patch.object(
                module.install,
                "handle",
                side_effect=lambda *_: module.terminate(None, None),
            ):
                self.assertEqual(module.main(["install", "--release", "v2.0.0"]), 1)

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
module.verify.handle = lambda *_: os.kill(os.getpid(), getattr(signal, sys.argv[2]))
sys.exit(module.main(["verify", "--release", "v2.0.0"]))
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
                self.assertIn("SYNOPSIS", result.stdout)

    def test_help_does_not_check_the_environment(self):
        for arguments in (
            ("--help",),
            ("select", "--help"),
            ("verify", "--help"),
            ("install", "--help"),
        ):
            with self.subTest(arguments=arguments):
                result = self.run_cli(None, "none", *arguments)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn("SYNOPSIS", result.stdout)
                self.assertEqual(self.gh_log(), "")

    def test_select_reports_an_installable_release_without_running_foundry(self):
        result = self.run_cli("select")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Desired Foundry release: v2.0.0", result.stdout)
        self.assertIn("Archive preflight:", result.stdout)
        self.assertEqual(self.version_log(), [])

    def test_source_mismatch_fails_before_reporting_metadata(self):
        self.env["TEST_SOURCE_MISMATCH"] = "1"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("setup tooling differs from HEAD", result.stdout)
        self.assertNotIn("spells-mainnet commit:", result.stdout)

    def test_make_targets_forward_release_and_ignore_age(self):
        self.env["TEST_INSTALLED_TAG"] = "v2.1.0"
        result = self.run_command(
            [
                "make",
                "-s",
                "verify-foundry",
                "release=v2.1.0",
                "ignore-age=1",
            ],
            cwd=CLI.parents[2],
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("cooling period waived with --ignore-age", result.stdout)

        (self.log / "gh").unlink(missing_ok=True)
        result = self.run_command(
            ["make", "-s", "select-foundry", "ignore-age=1"],
            cwd=CLI.parents[2],
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Desired Foundry release: v2.1.0", result.stdout)

    def test_make_rejects_invalid_ignore_age_and_missing_release(self):
        result = self.run_command(
            ["make", "-s", "select-foundry", "ignore-age=2"],
            cwd=CLI.parents[2],
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ignore-age must be 0 or 1", result.stdout)

        for target in ("verify-foundry", "install-foundry"):
            with self.subTest(target=target):
                result = self.run_command(["make", "-s", target], cwd=CLI.parents[2])
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("--release requires a value", result.stdout)


if __name__ == "__main__":
    unittest.main()
