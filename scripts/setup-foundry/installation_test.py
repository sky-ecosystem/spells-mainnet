import contextlib
import io
import os
import platform
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

from pathlib import Path
from unittest import mock

import installation as installation_module
from mocks.cli_environment import (
    BINARIES,
    FoundryFixture,
    load_cli_module,
)


class InstallTests(FoundryFixture, unittest.TestCase):
    def test_install_platform_matrix_including_rosetta(self):
        cases = (
            ("Linux", "x86_64", None, ("linux", "amd64")),
            ("Linux", "aarch64", None, ("linux", "arm64")),
            ("Darwin", "arm64", None, ("darwin", "arm64")),
            ("Darwin", "x86_64", "0", ("darwin", "amd64")),
            ("Darwin", "x86_64", "1", ("darwin", "arm64")),
        )
        for system, machine, translated, expected in cases:
            with self.subTest(system=system, machine=machine, translated=translated):
                result = subprocess.CompletedProcess(
                    ["sysctl"], 0 if translated is not None else 1, translated or "", ""
                )
                with (
                    mock.patch.object(
                        installation_module.platform, "system", return_value=system
                    ),
                    mock.patch.object(
                        installation_module.platform, "machine", return_value=machine
                    ),
                    mock.patch.object(
                        installation_module.subprocess, "run", return_value=result
                    ),
                ):
                    self.assertEqual(
                        installation_module.validate_install_platform(), expected
                    )

    def test_install_sets_executable_permissions_on_all_binaries(self):
        result = self.run_cli("install", "destination")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(
            all(
                (self.destination / name).stat().st_mode & 0o777 == 0o755
                for name in BINARIES
            )
        )

    def test_install_replaces_destination_without_running_existing_binaries(self):
        for binary in BINARIES:
            self.write_executable(
                self.destination / binary,
                f"#!{sys.executable}\nprint('untrusted {binary}')\n",
            )

        result = self.run_cli("install", "destination")

        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("untrusted", result.stdout)
        self.assertEqual(self.version_log(), list(BINARIES))

    def test_install_asset_attestation_failure_blocks_archive_read_and_mutation(self):
        systems = {"Linux": "linux", "Darwin": "darwin"}
        architectures = {
            "x86_64": "amd64",
            "amd64": "amd64",
            "arm64": "arm64",
            "aarch64": "arm64",
        }
        asset = (
            f"foundry_v2.0.0_{systems[platform.system()]}_"
            f"{architectures[platform.machine()]}.tar.gz"
        )
        self.env.update({"TEST_ATTEST_FAIL": asset, "TEST_INVALID_ARCHIVE": "1"})
        result = self.run_cli("install", "none")
        self.assertEqual(result.returncode, 1)
        self.assertIn("could not verify attestation for", result.stdout)
        self.assertIn(asset, result.stdout)
        self.assertNotIn("could not read Foundry release archive", result.stdout)
        self.assertTrue(self.destination.is_dir())
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_install_rejects_asset_attestation_tag_mismatch_before_archive_read(self):
        self.env.update({"TEST_ASSET_TAG": "v1.9.0", "TEST_INVALID_ARCHIVE": "1"})
        result = self.run_cli("install", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "release asset attestation tag v1.9.0 does not match v2.0.0", result.stdout
        )
        self.assertNotIn("tar archive", result.stdout)

    def test_install_rejects_unsafe_nonregular_unexpected_and_incomplete_archives(self):
        for variant in ("traversal", "nonregular", "unexpected", "missing"):
            with self.subTest(variant=variant):
                self.env["TEST_ARCHIVE_VARIANT"] = variant
                result = self.run_cli("install", "none")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    "archive must contain only regular files named forge, cast, anvil, and chisel",
                    result.stdout,
                )
                self.assertEqual(list(self.destination.iterdir()), [])

    def test_install_outside_path_reports_action_after_verified_success(self):
        result = self.run_cli("install", "none")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Required action: update-path", result.stdout)
        self.assertIn(
            "Foundry installation and verification completed successfully",
            result.stdout,
        )
        self.assertTrue((self.destination / "forge").is_file())
        self.assertEqual(self.version_log(), list(BINARIES))

    def test_post_mutation_failure_restores_partial_prior_installation(self):
        (self.destination / "forge").write_text("old forge\n")
        (self.destination / "cast").write_text("old cast\n")
        (self.destination / "forge").chmod(0o700)
        (self.destination / "cast").chmod(0o600)
        self.env.update({"TEST_ATTEST_FAIL": "cast", "TEST_ATTEST_STATUS": "42"})
        result = self.run_cli("install", "destination")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertEqual((self.destination / "forge").read_text(), "old forge\n")
        self.assertEqual(
            stat.S_IMODE((self.destination / "forge").stat().st_mode), 0o700
        )
        self.assertEqual((self.destination / "cast").read_text(), "old cast\n")
        self.assertEqual(
            stat.S_IMODE((self.destination / "cast").stat().st_mode), 0o600
        )
        self.assertFalse((self.destination / "anvil").exists())
        self.assertFalse((self.destination / "chisel").exists())
        self.assertIn("Previous Foundry installation restored", result.stdout)

    def test_incomplete_rollback_preserves_reported_backups(self):
        module = installation_module

        cli_module = load_cli_module()
        old_forge = self.destination / "forge"
        old_forge.write_text("old forge\n")
        env = self.env.copy()
        env.update(
            {
                "PATH": f"{self.destination}:{self.fake_bin}:/usr/bin:/bin",
                "TEST_ATTEST_FAIL": "cast",
                "TEST_ATTEST_STATUS": "42",
            }
        )
        real_copy2 = module.shutil.copy2
        real_mkdtemp = tempfile.mkdtemp

        def fail_restore(source, destination, *, follow_symlinks=True):
            if source.parent.name == "previous-installation":
                raise OSError("simulated restore failure")
            real_copy2(source, destination, follow_symlinks=follow_symlinks)

        output = io.StringIO()
        with mock.patch.dict(os.environ, env, clear=True):
            with mock.patch.object(module.shutil, "copy2", side_effect=fail_restore):
                with mock.patch.object(
                    module.tempfile,
                    "mkdtemp",
                    side_effect=lambda *args, **kwargs: real_mkdtemp(dir=self.fixture),
                ):
                    with (
                        contextlib.redirect_stdout(output),
                        contextlib.redirect_stderr(output),
                    ):
                        self.assertEqual(
                            cli_module.main(["install", "--release", "v2.0.0"]), 1
                        )

        prefix = "Backups preserved at: "
        recovery_lines = [
            line for line in output.getvalue().splitlines() if line.startswith(prefix)
        ]
        self.assertEqual(len(recovery_lines), 1, output.getvalue())
        recovery_directory = Path(recovery_lines[0][len(prefix) :])
        self.assertTrue(recovery_directory.is_dir())
        self.assertEqual((recovery_directory / "forge").read_text(), "old forge\n")

    def test_success_and_complete_rollback_clean_temporary_data(self):
        module = installation_module

        cli_module = load_cli_module()
        real_mkdtemp = tempfile.mkdtemp
        created = []

        def tracked_mkdtemp(*args, **kwargs):
            path = Path(real_mkdtemp(dir=self.fixture))
            created.append(path)
            return str(path)

        env = self.env.copy()
        env["PATH"] = f"{self.destination}:{self.fake_bin}:/usr/bin:/bin"
        with mock.patch.dict(os.environ, env, clear=True):
            with mock.patch.object(
                module.tempfile, "mkdtemp", side_effect=tracked_mkdtemp
            ):
                with (
                    contextlib.redirect_stdout(io.StringIO()),
                    contextlib.redirect_stderr(io.StringIO()),
                ):
                    self.assertEqual(
                        cli_module.main(["install", "--release", "v2.0.0"]), 0
                    )
        self.assertFalse(created[-1].exists())

        env["TEST_ATTEST_FAIL"] = "cast"
        with mock.patch.dict(os.environ, env, clear=True):
            with mock.patch.object(
                module.tempfile, "mkdtemp", side_effect=tracked_mkdtemp
            ):
                with (
                    contextlib.redirect_stdout(io.StringIO()),
                    contextlib.redirect_stderr(io.StringIO()),
                ):
                    self.assertEqual(
                        cli_module.main(["install", "--release", "v2.0.0"]), 1
                    )
        self.assertFalse(created[-1].exists())

    def test_mid_install_failure_rolls_back_partial_mutation(self):
        module = installation_module

        extracted = self.fixture / "extracted"
        backup = self.fixture / "backup"
        extracted.mkdir()
        for binary in BINARIES:
            (self.destination / binary).write_text(f"old {binary}\n")
            (extracted / binary).write_text(f"new {binary}\n")

        transaction = module.Installation(self.destination, backup)
        transaction.prepare()
        real_replace = os.replace
        replacements = 0

        def fail_on_third_replacement(source, destination):
            nonlocal replacements
            replacements += 1
            if replacements == 3:
                raise OSError("simulated partial installation failure")
            real_replace(source, destination)

        with mock.patch.object(
            module.os, "replace", side_effect=fail_on_third_replacement
        ):
            with self.assertRaises(OSError):
                transaction.install(extracted)
        rollback_output = io.StringIO()
        with contextlib.redirect_stderr(rollback_output):
            transaction.rollback()

        for binary in BINARIES:
            self.assertEqual((self.destination / binary).read_text(), f"old {binary}\n")
        self.assertEqual(list(self.destination.glob(".*.setup-foundry.*")), [])
        self.assertIn(
            "Previous Foundry installation restored", rollback_output.getvalue()
        )

    def test_install_preserves_unmanaged_destination_files(self):
        unmanaged = self.destination / ".forge.setup-foundry"
        unmanaged.write_text("keep me\n")
        result = self.run_cli("install", "destination")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(unmanaged.read_text(), "keep me\n")

    def test_post_mutation_failure_restores_existing_symlink(self):
        target = self.fixture / "old-forge"
        target.write_text("old forge target\n")
        forge = self.destination / "forge"
        forge.symlink_to(target)
        self.env["TEST_ATTEST_FAIL"] = "cast"
        result = self.run_cli("install", "destination")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(forge.is_symlink())
        self.assertEqual(os.readlink(forge), str(target))

    def test_failure_removes_destination_created_by_install(self):
        shutil.rmtree(self.home / ".foundry")
        self.env["TEST_ATTEST_FAIL"] = "cast"
        result = self.run_cli("install", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.destination.exists())
        self.assertFalse((self.home / ".foundry").exists())

    def test_install_reuses_destination_symlink_to_directory(self):
        real_destination = self.fixture / "real-bin"
        real_destination.mkdir()
        shutil.rmtree(self.destination)
        self.destination.symlink_to(real_destination, target_is_directory=True)
        result = self.run_cli("install", "destination")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(self.destination.is_symlink())
        self.assertTrue((real_destination / "forge").is_file())

    def test_install_rejects_invalid_or_broken_destination(self):
        shutil.rmtree(self.destination)
        self.destination.write_text("not a directory")
        result = self.run_cli("install", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("installation destination is not a directory", result.stdout)

        self.destination.unlink()
        self.destination.symlink_to(self.fixture / "missing")
        result = self.run_cli("install", "none")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("installation destination is not a directory", result.stdout)
