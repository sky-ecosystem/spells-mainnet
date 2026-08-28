"""Foundry release policy, archive preflight, and attestation validation."""

import hashlib
import json
import math
import re
import sys
from datetime import datetime, timezone

from config import (
    GITHUB_HOST,
    MINIMUM_RELEASE_AGE_DAYS,
    MINIMUM_RELEASE_AGE_SECONDS,
    REPOSITORY,
    SIGNER_PREFIX,
    SIGNER_WORKFLOW,
    SOURCE_REPOSITORY,
    SUPPORTED_ARCHIVE_TARGETS,
)
from runtime import SetupError, run


STABLE_TAG = re.compile(r"^v[0-9]+\.[0-9]+\.[0-9]+$")
ARCHIVE_PREFLIGHT_STATUS = (
    "SHA-256 digests and SLSA attestations published for all supported archives"
)


def parse_timestamp(value):
    try:
        normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
        parsed = datetime.fromisoformat(normalized)
        if parsed.tzinfo is None:
            raise ValueError("timestamp has no timezone")
        return parsed.astimezone(timezone.utc)
    except (AttributeError, TypeError, ValueError) as error:
        raise SetupError(f"invalid GitHub release timestamp: {value}") from error


def parse_json(output, description):
    try:
        return json.loads(output)
    except (TypeError, ValueError) as error:
        raise SetupError(f"could not parse {description}") from error


def release_age_seconds(published_at):
    return math.floor(
        datetime.now(timezone.utc).timestamp()
        - parse_timestamp(published_at).timestamp()
    )


def release_metadata(tag):
    output = run(
        [
            "gh",
            "api",
            f"repos/{REPOSITORY}/releases/tags/{tag}",
            "--hostname",
            GITHUB_HOST,
        ],
        f"could not find Foundry release metadata for {tag}",
    )
    metadata = parse_json(output, f"Foundry release metadata for {tag}")
    if not isinstance(metadata, dict):
        raise SetupError(f"could not parse Foundry release metadata for {tag}")
    return metadata


def _selection(metadata, reason, *, archive_preflight=False):
    try:
        selection = {
            "version": metadata["tag_name"],
            "published_at": metadata["published_at"],
            "release_url": metadata["html_url"],
            "selection_reason": reason,
        }
    except (KeyError, TypeError) as error:
        raise SetupError("could not parse Foundry release metadata") from error
    if archive_preflight:
        selection["archive_preflight_status"] = ARCHIVE_PREFLIGHT_STATUS
    return selection


def preflight_release_archives(version):
    try:
        metadata = release_metadata(version)
        assets = metadata.get("assets")
        if not isinstance(assets, list):
            raise SetupError("could not load release assets")
        for target in SUPPORTED_ARCHIVE_TARGETS:
            name = f"foundry_{version}_{target}.tar.gz"
            matches = [asset for asset in assets if asset.get("name") == name]
            if len(matches) != 1:
                raise SetupError(f"expected exactly one release asset named {name}")
            digest = matches[0].get("digest")
            if (
                not isinstance(digest, str)
                or re.fullmatch(r"sha256:[0-9a-f]{64}", digest) is None
            ):
                raise SetupError(f"release asset has no valid SHA-256 digest: {name}")
            output = run(
                [
                    "gh",
                    "api",
                    f"repos/{REPOSITORY}/attestations/{digest}?per_page=1&predicate_type=https%3A%2F%2Fslsa.dev%2Fprovenance%2Fv1",
                    "--hostname",
                    GITHUB_HOST,
                ],
                f"could not load SLSA attestations for {name}",
            )
            records = parse_json(output, f"SLSA attestations for {name}")
            if not isinstance(records, dict) or not records.get("attestations"):
                raise SetupError(f"no SLSA attestation is published for {name}")
    except (AttributeError, SetupError) as error:
        print(f"Skipping Foundry release {version}: {error}", file=sys.stderr)
        return False
    return True


def select_release(ignore_age=False):
    output = run(
        [
            "gh",
            "api",
            "--paginate",
            "--slurp",
            f"repos/{REPOSITORY}/releases?per_page=100",
            "--hostname",
            GITHUB_HOST,
        ],
        "could not load stable Foundry release metadata",
    )
    pages = parse_json(output, "Foundry release list")
    if not isinstance(pages, list) or any(not isinstance(page, list) for page in pages):
        raise SetupError("could not parse Foundry release list")

    candidates = []
    for metadata in (item for page in pages for item in page):
        if (
            not isinstance(metadata, dict)
            or metadata.get("draft") is not False
            or metadata.get("prerelease") is not False
            or metadata.get("immutable") is not True
            or not isinstance(metadata.get("tag_name"), str)
            or STABLE_TAG.fullmatch(metadata["tag_name"]) is None
        ):
            continue
        age = release_age_seconds(metadata.get("published_at"))
        if age < 0 or (age < MINIMUM_RELEASE_AGE_SECONDS and not ignore_age):
            continue
        if not isinstance(metadata.get("html_url"), str):
            raise SetupError("could not parse Foundry release list")
        candidates.append((parse_timestamp(metadata["published_at"]), metadata, age))

    if not candidates:
        if ignore_age:
            raise SetupError("no immutable stable Foundry release was found")
        raise SetupError(
            f"no immutable stable Foundry release published at least {MINIMUM_RELEASE_AGE_DAYS} days ago was found"
        )

    for _, metadata, age in sorted(candidates, key=lambda item: item[0], reverse=True):
        if not preflight_release_archives(metadata["tag_name"]):
            continue
        if age < MINIMUM_RELEASE_AGE_SECONDS:
            reason = (
                f"newest immutable stable release; {MINIMUM_RELEASE_AGE_DAYS}-day "
                "cooling period waived with --ignore-age"
            )
        else:
            reason = "newest immutable stable release; release is age-eligible"
        return _selection(metadata, reason, archive_preflight=True)
    raise SetupError("no immutable stable Foundry release passed archive preflight")


def load_requested_release(requested_release, ignore_age=False):
    if STABLE_TAG.fullmatch(requested_release) is None:
        raise SetupError(
            f"requested Foundry release does not use a stable version tag: {requested_release}"
        )
    metadata = release_metadata(requested_release)
    if metadata.get("tag_name") != requested_release:
        raise SetupError(
            f"requested Foundry release metadata does not match {requested_release}"
        )
    if metadata.get("draft") is not False or metadata.get("prerelease") is not False:
        raise SetupError(
            f"requested Foundry release is not stable: {requested_release}"
        )
    if metadata.get("immutable") is not True:
        raise SetupError(
            f"requested Foundry release is not immutable: {requested_release}"
        )
    age = release_age_seconds(metadata.get("published_at"))
    if age < 0:
        raise SetupError(
            f"requested Foundry release has a future publication date: {requested_release}"
        )
    if age < MINIMUM_RELEASE_AGE_SECONDS and not ignore_age:
        raise SetupError(
            f"release is less than {MINIMUM_RELEASE_AGE_DAYS} days old; use --ignore-age only for an approved release"
        )
    if age < MINIMUM_RELEASE_AGE_SECONDS:
        reason = (
            f"explicitly requested immutable stable {requested_release}; "
            f"{MINIMUM_RELEASE_AGE_DAYS}-day cooling period waived with --ignore-age"
        )
    else:
        reason = (
            f"explicitly requested immutable stable {requested_release}; "
            "release is age-eligible"
        )
    return _selection(metadata, reason)


def attest_path(path):
    path = path.absolute()
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    output = run(
        [
            "gh",
            "attestation",
            "verify",
            str(path),
            "--repo",
            REPOSITORY,
            "--hostname",
            GITHUB_HOST,
            "--signer-workflow",
            SIGNER_WORKFLOW,
            "--format",
            "json",
        ],
        f"could not verify attestation for {path}",
    )
    records = parse_json(output, f"attestation for {path}")
    try:
        result = records[0]["verificationResult"]
        certificate = result["signature"]["certificate"]
        signer = certificate["buildSignerURI"]
        source = certificate["sourceRepositoryURI"]
        matching = [
            subject
            for subject in result["statement"]["subject"]
            if subject.get("digest", {}).get("sha256") == digest
        ]
        if len(matching) != 1:
            raise KeyError("matching subject")
        subject = matching[0]["name"]
    except (IndexError, KeyError, TypeError) as error:
        raise SetupError(f"could not parse attestation for {path}") from error
    if not isinstance(signer, str) or not signer.startswith(SIGNER_PREFIX):
        raise SetupError(f"unexpected attestation signer for {path}: {signer}")
    if source != SOURCE_REPOSITORY:
        raise SetupError(f"unexpected attestation source for {path}: {source}")
    tag = signer[len(SIGNER_PREFIX) :]
    if not tag:
        raise SetupError(f"unexpected attestation signer for {path}: {signer}")
    if str(path) != subject and not str(path).endswith(f"/{subject}"):
        raise SetupError(f"attestation subject does not match path: {subject} ({path})")
    print(f"  Subject: {subject}\n  Signer: {signer}\n  Source: {source}")
    return tag
