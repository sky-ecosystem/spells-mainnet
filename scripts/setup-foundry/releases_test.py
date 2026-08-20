import contextlib
import hashlib
import io
import json
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

import releases
from config import (
    MINIMUM_RELEASE_AGE_DAYS,
    SIGNER_PREFIX,
    SOURCE_REPOSITORY,
    SUPPORTED_ARCHIVE_TARGETS,
)
from runtime import SetupError


def published_at(days_ago):
    return (
        (datetime.now(timezone.utc) - timedelta(days=days_ago))
        .isoformat()
        .replace("+00:00", "Z")
    )


def release(tag, days_ago, *, draft=False, prerelease=False, immutable=True):
    return {
        "tag_name": tag,
        "published_at": published_at(days_ago),
        "html_url": f"https://example.test/{tag}",
        "draft": draft,
        "prerelease": prerelease,
        "immutable": immutable,
    }


def attestation(signer, source, subjects):
    return json.dumps(
        [
            {
                "verificationResult": {
                    "statement": {"subject": subjects},
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
    def test_release_timestamp_requires_a_valid_timezone(self):
        self.assertEqual(
            releases.parse_timestamp("2026-01-01T00:00:00Z").tzinfo,
            timezone.utc,
        )
        for value in (None, "invalid", "2026-01-01T00:00:00"):
            with self.subTest(value=value):
                with self.assertRaisesRegex(
                    SetupError, "invalid GitHub release timestamp"
                ):
                    releases.parse_timestamp(value)

    def test_selects_newest_installable_immutable_stable_release(self):
        newest = release("v2.0.0", 20)
        fallback = release("v1.9.0", 30)
        response = [
            [
                release("v2.1.0", 1),
                release("v3.0.0-rc1", 20, prerelease=True),
                release("v9.0.0", 20, draft=True),
                release("v8.0.0", 20, immutable=False),
                release("nightly", 20),
                newest,
                fallback,
            ]
        ]
        with (
            mock.patch.object(releases, "run", return_value=json.dumps(response)),
            mock.patch.object(
                releases,
                "preflight_release_archives",
                side_effect=[False, True],
                create=True,
            ) as preflight,
        ):
            selection = releases.select_release(False)

        self.assertEqual(selection["version"], fallback["tag_name"])
        self.assertEqual(preflight.call_count, 2)
        self.assertEqual(
            selection["selection_reason"],
            "newest immutable stable release; release is age-eligible",
        )
        self.assertIn("archive_preflight_status", selection)

    def test_select_ignore_age_can_choose_a_young_release(self):
        selected = release("v2.1.0", 1)
        with (
            mock.patch.object(releases, "run", return_value=json.dumps([[selected]])),
            mock.patch.object(
                releases,
                "preflight_release_archives",
                return_value=True,
                create=True,
            ),
        ):
            selection = releases.select_release(True)
        self.assertEqual(selection["version"], "v2.1.0")
        self.assertEqual(
            selection["selection_reason"],
            f"newest immutable stable release; {MINIMUM_RELEASE_AGE_DAYS}-day cooling period waived with --ignore-age",
        )

    def test_select_fails_when_no_candidate_passes_policy_or_preflight(self):
        with mock.patch.object(
            releases,
            "run",
            return_value=json.dumps([[release("v2.1.0", 1)]]),
        ):
            with self.assertRaisesRegex(SetupError, "at least 14 days ago"):
                releases.select_release(False)

        with (
            mock.patch.object(
                releases,
                "run",
                return_value=json.dumps([[release("v2.0.0", 20)]]),
            ),
            mock.patch.object(
                releases, "preflight_release_archives", return_value=False
            ),
        ):
            with self.assertRaisesRegex(SetupError, "passed archive preflight"):
                releases.select_release(False)

    def test_requested_release_enforces_exact_stable_immutable_age_policy(self):
        eligible = release("v2.0.0", 20)
        with mock.patch.object(releases, "release_metadata", return_value=eligible):
            selection = releases.load_requested_release("v2.0.0", False)
        self.assertEqual(selection["version"], "v2.0.0")
        self.assertEqual(
            selection["selection_reason"],
            "explicitly requested immutable stable v2.0.0; release is age-eligible",
        )

        young = release("v2.1.0", 1)
        with mock.patch.object(releases, "release_metadata", return_value=young):
            with self.assertRaisesRegex(SetupError, "less than 14 days old"):
                releases.load_requested_release("v2.1.0", False)
            waived = releases.load_requested_release("v2.1.0", True)
        self.assertIn("cooling period waived", waived["selection_reason"])

        invalid = (
            ("v2.0", eligible, "stable version tag"),
            ("v2.0.0-rc1", eligible, "stable version tag"),
            ("v2.0.0", {**eligible, "tag_name": "v1.0.0"}, "does not match"),
            ("v2.0.0", {**eligible, "draft": True}, "not stable"),
            ("v2.0.0", {**eligible, "immutable": False}, "not immutable"),
            ("v2.0.0", release("v2.0.0", -1), "future publication date"),
        )
        for requested, metadata, message in invalid:
            with self.subTest(message=message):
                with mock.patch.object(
                    releases, "release_metadata", return_value=metadata
                ):
                    with self.assertRaisesRegex(SetupError, message):
                        releases.load_requested_release(requested, False)

    def test_archive_preflight_requires_every_supported_digest_and_attestation(self):
        version = "v2.0.0"
        assets = [
            {
                "name": f"foundry_{version}_{target}.tar.gz",
                "digest": f"sha256:{index:064x}",
            }
            for index, target in enumerate(SUPPORTED_ARCHIVE_TARGETS, 1)
        ]
        metadata = {"assets": assets}
        attestation_response = json.dumps({"attestations": [{}]})
        with mock.patch.object(
            releases,
            "run",
            side_effect=[json.dumps(metadata)]
            + [attestation_response] * len(SUPPORTED_ARCHIVE_TARGETS),
        ):
            self.assertTrue(releases.preflight_release_archives(version))

        for mutation in ("missing", "duplicate", "digest", "attestation"):
            with self.subTest(mutation=mutation):
                changed = [dict(asset) for asset in assets]
                if mutation == "missing":
                    changed.pop()
                elif mutation == "duplicate":
                    changed.append(dict(changed[0]))
                elif mutation == "digest":
                    changed[0]["digest"] = ""
                responses = [json.dumps({"assets": changed})] + [
                    attestation_response
                ] * len(SUPPORTED_ARCHIVE_TARGETS)
                if mutation == "attestation":
                    responses[1] = json.dumps({"attestations": []})
                with mock.patch.object(releases, "run", side_effect=responses):
                    with contextlib.redirect_stderr(io.StringIO()):
                        self.assertFalse(releases.preflight_release_archives(version))

    def test_attestation_selects_the_matching_digest_and_path_subject(self):
        signer = f"{SIGNER_PREFIX}v2.0.0"
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "forge"
            path.write_bytes(b"verified forge")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            response = attestation(
                signer,
                SOURCE_REPOSITORY,
                [
                    {"name": "unrelated", "digest": {"sha256": "0" * 64}},
                    {"name": "forge", "digest": {"sha256": digest}},
                ],
            )
            output = io.StringIO()
            with mock.patch.object(releases, "run", return_value=response):
                with contextlib.redirect_stdout(output):
                    tag = releases.attest_path(path)
        self.assertEqual(tag, "v2.0.0")
        self.assertEqual(
            output.getvalue(),
            f"  Subject: forge\n  Signer: {signer}\n  Source: {SOURCE_REPOSITORY}\n",
        )

    def test_attestation_rejects_missing_digest_or_wrong_subject(self):
        signer = f"{SIGNER_PREFIX}v2.0.0"
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "forge"
            path.write_bytes(b"verified forge")
            cases = (
                ([{"name": "forge", "digest": {"sha256": "0" * 64}}], "parse"),
                (
                    [
                        {
                            "name": "renamed-forge",
                            "digest": {
                                "sha256": hashlib.sha256(path.read_bytes()).hexdigest()
                            },
                        }
                    ],
                    "subject does not match path",
                ),
            )
            for subjects, message in cases:
                with self.subTest(message=message):
                    response = attestation(signer, SOURCE_REPOSITORY, subjects)
                    with mock.patch.object(releases, "run", return_value=response):
                        with self.assertRaisesRegex(SetupError, message):
                            releases.attest_path(path)


if __name__ == "__main__":
    unittest.main()
