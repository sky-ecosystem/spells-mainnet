import unittest

from mocks.cli_environment import BINARIES, FoundryFixture


class VerifyTests(FoundryFixture, unittest.TestCase):
    def test_verify_newest_eligible_toolchain(self):
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.gh_log().count("attestation verify "), 4)
        self.assertEqual(self.version_log(), list(BINARIES))
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
