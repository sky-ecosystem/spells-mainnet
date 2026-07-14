import contextlib
import io
import json
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

import releases
from config import SIGNER_PREFIX, SOURCE_REPOSITORY
from runtime import SetupError


def published_at(days_ago):
    return (
        (datetime.now(timezone.utc) - timedelta(days=days_ago))
        .isoformat()
        .replace("+00:00", "Z")
    )


def release(tag, days_ago, *, draft=False, prerelease=False):
    return {
        "tag_name": tag,
        "published_at": published_at(days_ago),
        "html_url": f"https://example.test/{tag}",
        "draft": draft,
        "prerelease": prerelease,
    }


def attestation(signer, source=SOURCE_REPOSITORY):
    return json.dumps(
        [
            {
                "verificationResult": {
                    "statement": {"subject": [{"name": "forge"}, {"name": "cast"}]},
                    "signature": {
                        "certificate": {
                            "buildSignerURI": signer,
                            "sourceRepositoryURI": source,
                        }
                    },
                }
            }
        ]
    )


class ReleaseTests(unittest.TestCase):
    def test_selects_newest_stable_release_at_least_seven_days_old(self):
        selected = release("v2.0.0", 8)
        response = [
            [
                release("v2.1.0", 1),
                release("v3.0.0-rc1", 9, prerelease=True),
                release("v9.0.0", 9, draft=True),
                selected,
                release("v1.9.0", 30),
            ]
        ]
        with mock.patch.object(releases, "run", return_value=json.dumps(response)):
            selection = releases.select_release()

        self.assertEqual(selection["version"], selected["tag_name"])
        self.assertEqual(selection["published_at"], selected["published_at"])
        self.assertEqual(selection["release_url"], selected["html_url"])
        self.assertEqual(
            selection["selection_reason"],
            "newest stable release published at least seven days ago",
        )

    def test_rejects_invalid_or_ineligible_release_lists(self):
        eligible = release("v2.0.0", 8)
        cases = (
            ("not JSON", "could not parse Foundry release list"),
            (json.dumps({}), "could not parse Foundry release list"),
            (
                json.dumps([[{**eligible, "published_at": "not-a-timestamp"}]]),
                "invalid GitHub release timestamp",
            ),
            (
                json.dumps(
                    [
                        [
                            {
                                key: value
                                for key, value in eligible.items()
                                if key != "html_url"
                            }
                        ]
                    ]
                ),
                "could not parse Foundry release list",
            ),
            (
                json.dumps([[release("v2.1.0", 1)]]),
                "no stable Foundry release published at least seven days ago was found",
            ),
        )
        for response, message in cases:
            with self.subTest(message=message):
                with mock.patch.object(releases, "run", return_value=response):
                    with self.assertRaisesRegex(SetupError, message):
                        releases.select_release()

    def test_release_metadata_requires_an_object(self):
        metadata = {"tag_name": "v2.0.0", "draft": False, "prerelease": False}
        with mock.patch.object(releases, "run", return_value=json.dumps(metadata)):
            self.assertEqual(releases.release_metadata("v2.0.0"), metadata)

        with mock.patch.object(releases, "run", return_value=json.dumps([])):
            with self.assertRaisesRegex(
                SetupError, "could not parse Foundry release metadata for v2.0.0"
            ):
                releases.release_metadata("v2.0.0")

    def test_attestation_returns_tag_and_reports_provenance(self):
        signer = f"{SIGNER_PREFIX}v2.0.0"
        output = io.StringIO()
        with mock.patch.object(releases, "run", return_value=attestation(signer)):
            with contextlib.redirect_stdout(output):
                tag = releases.attest_path(Path("forge"))

        self.assertEqual(tag, "v2.0.0")
        self.assertEqual(
            output.getvalue(),
            f"  Subjects: forge,cast\n  Signer: {signer}\n  Source: {SOURCE_REPOSITORY}\n",
        )

    def test_attestation_rejects_malformed_or_untrusted_provenance(self):
        cases = (
            ("[]", "could not parse attestation for forge"),
            (
                attestation("https://github.com/attacker/release.yml@refs/tags/v2.0.0"),
                "unexpected attestation signer for forge",
            ),
            (
                attestation(
                    f"{SIGNER_PREFIX}v2.0.0", "https://github.com/attacker/repo"
                ),
                "unexpected attestation source for forge",
            ),
            (attestation(SIGNER_PREFIX), "unexpected attestation signer for forge"),
        )
        for response, message in cases:
            with self.subTest(message=message):
                with mock.patch.object(releases, "run", return_value=response):
                    with self.assertRaisesRegex(SetupError, message):
                        releases.attest_path(Path("forge"))


if __name__ == "__main__":
    unittest.main()
