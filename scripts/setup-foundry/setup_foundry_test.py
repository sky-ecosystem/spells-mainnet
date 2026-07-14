import contextlib
import io
import subprocess
import sys
import unittest
from unittest import mock

from mocks.cli_environment import CLI, FoundryFixture, load_cli_module


class CliBehaviorTests(FoundryFixture, unittest.TestCase):
    def test_setup_errors_exit_one(self):
        module = load_cli_module()
        output = io.StringIO()
        with mock.patch.object(
            module.verify, "handle", side_effect=module.SetupError("failed")
        ):
            with contextlib.redirect_stderr(output):
                self.assertEqual(module.main(["verify"]), 1)
        self.assertEqual(output.getvalue(), "Error: failed\n")

    def test_main_normalizes_interrupt_and_termination_to_one(self):
        module = load_cli_module()
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
