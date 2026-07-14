"""Select policy-eligible releases and validate GitHub attestations.

Callers must attest a release asset before inspecting its archive and attest
installed binaries before executing them.
"""

import json
from datetime import datetime, timezone

from .config import (
    GITHUB_HOST, MINIMUM_RELEASE_AGE_SECONDS, REPOSITORY, SIGNER_PREFIX,
    SIGNER_WORKFLOW, SOURCE_REPOSITORY,
)
from .runtime import SetupError, run


def parse_timestamp(value):
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except (AttributeError, TypeError, ValueError) as error:
        raise SetupError(f"invalid GitHub release timestamp: {value}") from error


def parse_json(output, description):
    try:
        return json.loads(output)
    except (TypeError, ValueError) as error:
        raise SetupError(f"could not parse {description}") from error


def select_release():
    output = run(
        ["gh", "api", "--paginate", "--slurp", f"repos/{REPOSITORY}/releases?per_page=100", "--hostname", GITHUB_HOST],
        "could not list Foundry releases",
    )
    pages = parse_json(output, "Foundry release list")
    if not isinstance(pages, list) or any(not isinstance(page, list) for page in pages):
        raise SetupError("could not parse Foundry release list")
    cutoff = datetime.now(timezone.utc).timestamp() - MINIMUM_RELEASE_AGE_SECONDS
    eligible = []
    for release in (release for page in pages for release in page):
        if not isinstance(release, dict) or release.get("draft") is not False or release.get("prerelease") is not False:
            continue
        published = parse_timestamp(release.get("published_at"))
        if published.timestamp() <= cutoff:
            try:
                eligible.append((published, release["tag_name"], release["published_at"], release["html_url"]))
            except KeyError as error:
                raise SetupError("could not parse Foundry release list") from error
    if not eligible:
        raise SetupError("no stable Foundry release published at least seven days ago was found")
    _, version, published_at, release_url = max(eligible, key=lambda item: item[0])
    return {
        "version": version, "published_at": published_at,
        "published_time": parse_timestamp(published_at), "release_url": release_url,
        "selection_reason": "newest stable release published at least seven days ago",
    }


def release_metadata(tag):
    output = run(
        ["gh", "api", f"repos/{REPOSITORY}/releases/tags/{tag}", "--hostname", GITHUB_HOST],
        f"could not find Foundry release metadata for {tag}",
    )
    metadata = parse_json(output, f"Foundry release metadata for {tag}")
    if not isinstance(metadata, dict):
        raise SetupError(f"could not parse Foundry release metadata for {tag}")
    return metadata


def attest_path(path):
    output = run(
        ["gh", "attestation", "verify", str(path), "--repo", REPOSITORY, "--hostname", GITHUB_HOST,
         "--signer-workflow", SIGNER_WORKFLOW, "--format", "json"],
        f"attestation verification failed for {path}",
    )
    records = parse_json(output, f"attestation for {path}")
    try:
        result = records[0]["verificationResult"]
        certificate = result["signature"]["certificate"]
        signer = certificate["buildSignerURI"]
        source = certificate["sourceRepositoryURI"]
        subjects = ",".join(subject["name"] for subject in result["statement"]["subject"])
    except (IndexError, KeyError, TypeError) as error:
        raise SetupError(f"could not parse attestation for {path}") from error
    if not isinstance(signer, str) or not signer.startswith(SIGNER_PREFIX):
        raise SetupError(f"unexpected attestation signer for {path}: {signer}")
    if source != SOURCE_REPOSITORY:
        raise SetupError(f"unexpected attestation source for {path}: {source}")
    tag = signer[len(SIGNER_PREFIX):]
    if not tag:
        raise SetupError(f"unexpected attestation signer for {path}: {signer}")
    print(f"  Subjects: {subjects}\n  Signer: {signer}\n  Source: {source}")
    return tag
