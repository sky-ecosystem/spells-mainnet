import unittest
from unittest import mock

from .support import BINARIES, FoundryFixture, load_module


class VerifyHandlerBoundaryTests(unittest.TestCase):
    def test_verify_handler_only_orchestrates_high_level_steps(self):
        verify = load_module("commands.verify")

        selection = object()
        paths = object()
        calls = []

        def record(name, result=None):
            return mock.Mock(
                side_effect=lambda *args: calls.append((name, args)) or result
            )

        with mock.patch.multiple(
            verify,
            validate_environment=record("validate"),
            collect_source_metadata=record("metadata", ("commit", "sha256")),
            select_release=record("select", selection),
            report_selection=record("report_selection"),
            resolve_path_binaries=record("resolve", paths),
            verify_binary_paths=record("attest", "v2.0.0"),
            validate_installed_release=record("policy", "eligible"),
            run_binary_versions=record("versions"),
            report_verification_summary=record("summary"),
        ):
            self.assertEqual(verify.handle(), 0)

        self.assertEqual(
            calls,
            [
                ("validate", ()),
                ("metadata", (verify.TOOL_ROOT,)),
                ("select", ()),
                ("report_selection", (selection, "commit", "sha256")),
                ("resolve", ()),
                ("attest", (paths,)),
                ("policy", ("v2.0.0", selection)),
                ("versions", (paths,)),
                ("summary", (selection, "commit", "sha256", "v2.0.0", "eligible")),
            ],
        )


class VerifyTests(FoundryFixture, unittest.TestCase):
    def test_verify_newest_eligible_toolchain(self):
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.gh_log().count("attestation verify "), 4)
        self.assertEqual(self.version_log(), list(BINARIES))
        self.assertIn("Eligible Foundry release: v2.0.0", result.stdout)
        self.assertIn("Setup tooling SHA-256:", result.stdout)
        self.assertIn("Foundry verification completed successfully", result.stdout)

    def test_verify_rejects_older_release_before_execution(self):
        self.env["TEST_INSTALLED_TAG"] = "v1.9.0"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])
        self.assertIn("does not match newest eligible stable v2.0.0", result.stdout)

    def test_verify_rejects_too_new_release_before_execution(self):
        self.env["TEST_INSTALLED_TAG"] = "v2.1.0"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])
        self.assertIn("seven-day policy", result.stdout)

    def test_verify_rejects_prerelease_before_execution(self):
        self.env["TEST_INSTALLED_TAG"] = "v1.8.0-rc1"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])
        self.assertIn("is not stable", result.stdout)

    def test_verify_reports_version_failure(self):
        self.env["TEST_VERSION_FAIL"] = "cast"
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 1)
        self.assertIn("could not read version from", result.stdout)

    def test_verify_rejects_missing_mixed_and_unattested_toolchains(self):
        (self.path_bin / "chisel").unlink()
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])

        self.write_binary(self.path_bin / "chisel", "chisel")
        self.env["TEST_MIXED_BINARY"] = "cast"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])

        self.env.pop("TEST_MIXED_BINARY")
        self.env["TEST_ATTEST_FAIL"] = "cast"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version_log(), [])

    def test_verify_rejects_wrong_attestation_signer_and_source(self):
        self.env["TEST_SIGNER"] = (
            "https://github.com/attacker/project/.github/workflows/release.yml@refs/tags/v2.0.0"
        )
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected attestation signer", result.stdout)
        self.assertEqual(self.version_log(), [])

        self.env.pop("TEST_SIGNER")
        self.env["TEST_SOURCE"] = "https://github.com/attacker/project"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected attestation source", result.stdout)
        self.assertEqual(self.version_log(), [])
