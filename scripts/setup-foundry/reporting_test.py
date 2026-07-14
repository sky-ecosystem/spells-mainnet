import contextlib
import io
import os
import unittest
from pathlib import Path
from unittest import mock

import reporting
from config import SIGNER_WORKFLOW


SELECTION = {
    "version": "v2.0.0",
    "published_at": "2026-01-01T00:00:00Z",
    "release_url": "https://example.test/v2.0.0",
    "selection_reason": "newest stable release published at least seven days ago",
}


def capture_stdout(function, *args):
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        result = function(*args)
    return result, output.getvalue()


class ReportingTests(unittest.TestCase):
    def test_reports_evidence(self):
        cases = (
            (
                reporting.report_selection,
                (SELECTION, "source-commit", "tooling-hash"),
                "Eligible Foundry release: v2.0.0\n"
                "Published at: 2026-01-01T00:00:00Z\n"
                "Release URL: https://example.test/v2.0.0\n"
                "Selection policy: newest stable release published at least seven days ago\n"
                "spells-mainnet commit: source-commit\n"
                "Setup tooling SHA-256: tooling-hash\n",
            ),
            (
                reporting.report_verification_summary,
                (
                    SELECTION,
                    "source-commit",
                    "tooling-hash",
                    "v2.0.0",
                    "matches newest eligible stable v2.0.0",
                ),
                "\nEvidence summary:\n"
                "  Source: spells-mainnet source-commit; setup tooling SHA-256 tooling-hash\n"
                "  Eligible release: v2.0.0; 2026-01-01T00:00:00Z; https://example.test/v2.0.0\n"
                "  Policy decision: newest stable release published at least seven days ago\n"
                "  Installed release: v2.0.0; matches newest eligible stable v2.0.0\n"
                "  Binary attestations: forge, cast, anvil, and chisel verified against "
                f"{SIGNER_WORKFLOW}\n",
            ),
            (
                reporting.report_installation_summary,
                (SELECTION, "source-commit", "tooling-hash"),
                "\nEvidence summary:\n"
                "  Source: spells-mainnet source-commit; setup tooling SHA-256 tooling-hash\n"
                "  Release: v2.0.0; 2026-01-01T00:00:00Z; https://example.test/v2.0.0\n"
                "  Policy decision: newest stable release published at least seven days ago\n"
                f"  Release asset attestation: verified against {SIGNER_WORKFLOW}\n"
                "  Binary attestations: forge, cast, anvil, and chisel verified against "
                f"{SIGNER_WORKFLOW}\n",
            ),
        )
        for function, arguments, expected in cases:
            with self.subTest(report=function.__name__):
                _, output = capture_stdout(function, *arguments)
                self.assertEqual(output, expected)

    def test_reports_whether_installation_destination_is_in_path(self):
        destination = Path("/home/test/.foundry/bin")
        with mock.patch.dict(
            os.environ,
            {"PATH": f"/usr/bin{os.pathsep}{destination}"},
            clear=True,
        ):
            result, output = capture_stdout(
                reporting.report_installation_path_status, destination
            )
        self.assertEqual(result, 0)
        self.assertEqual(
            output, "\nFoundry installation and verification completed successfully.\n"
        )

        error = io.StringIO()
        with mock.patch.dict(os.environ, {"PATH": "/usr/bin"}, clear=True):
            with contextlib.redirect_stderr(error):
                result = reporting.report_installation_path_status(destination)
        self.assertEqual(result, 2)
        self.assertEqual(
            error.getvalue(),
            f"\nFoundry was installed and verified, but {destination} is not in PATH.\n"
            'Run: export PATH="$HOME/.foundry/bin:$PATH"\n'
            "Add the same export to your shell profile, then start a new shell before continuing.\n",
        )


if __name__ == "__main__":
    unittest.main()
