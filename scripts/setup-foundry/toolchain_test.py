import unittest

from mocks.cli_environment import BINARIES, FoundryFixture


class VerifyTests(FoundryFixture, unittest.TestCase):
    def test_verify_exact_requested_toolchain(self):
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.gh_log().count("attestation verify "), 4)
        self.assertEqual(self.version_log(), list(BINARIES))
        self.assertIn("Foundry verification completed successfully", result.stdout)

    def test_version_mismatch_requires_exact_installation_before_execution(self):
        for installed in ("v1.9.0", "v2.1.0", "v1.8.0-rc1"):
            with self.subTest(installed=installed):
                self.env["TEST_INSTALLED_TAG"] = installed
                result = self.run_cli("verify")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.version_log(), [])
                self.assertIn("Required action: install", result.stdout)
                self.assertIn(
                    "Installation command: make install-foundry release=v2.0.0",
                    result.stdout,
                )
                self.assertNotIn(f"releases/tags/{installed}", self.gh_log())
                (self.log / "gh").unlink(missing_ok=True)

    def test_verify_reports_version_failure(self):
        self.env["TEST_VERSION_FAIL"] = "cast"
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 1)
        self.assertIn("could not read version from", result.stdout)

    def test_only_missing_toolchain_requires_installation(self):
        (self.path_bin / "chisel").unlink()
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Required action: install", result.stdout)
        self.assertEqual(self.version_log(), [])

        self.write_binary(self.path_bin / "chisel", "chisel")
        self.env["TEST_MIXED_BINARY"] = "cast"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Required action: install", result.stdout)
        self.assertEqual(self.version_log(), [])

        self.env.pop("TEST_MIXED_BINARY")
        self.env["TEST_ATTEST_FAIL"] = "cast"
        result = self.run_cli("verify")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Required action: install", result.stdout)
        self.assertEqual(self.version_log(), [])


if __name__ == "__main__":
    unittest.main()
