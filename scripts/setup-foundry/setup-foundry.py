#!/usr/bin/env python3
"""Verify or install an age-eligible stable Foundry release from GitHub.com."""

import hashlib
import json
import os
import platform
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
from datetime import datetime, timezone
from pathlib import Path


GITHUB_HOST = "github.com"
REPOSITORY = "foundry-rs/foundry"
QUALIFIED_REPOSITORY = f"{GITHUB_HOST}/{REPOSITORY}"
SIGNER_WORKFLOW = f"{REPOSITORY}/.github/workflows/release.yml"
SIGNER_PREFIX = f"https://{GITHUB_HOST}/{SIGNER_WORKFLOW}@refs/tags/"
SOURCE_REPOSITORY = f"https://{GITHUB_HOST}/{REPOSITORY}"
MINIMUM_RELEASE_AGE_SECONDS = 604800
BINARIES = ("forge", "cast", "anvil", "chisel")


class SetupError(Exception):
    pass


def usage():
    print(f"Usage: {Path(sys.argv[0]).name} {{verify|install}}", file=sys.stderr)


def run(command, failure_message):
    result = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        message = failure_message if not detail else f"{failure_message}: {detail}"
        raise SetupError(message)
    return result.stdout


def validate_environment():
    for command in ("gh", "git"):
        if shutil.which(command) is None:
            raise SetupError(f"required command not found: {command}")
    result = subprocess.run(
        ["gh", "auth", "status", "--hostname", GITHUB_HOST],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode:
        raise SetupError(f"GitHub CLI is not authenticated for {GITHUB_HOST}")


def validate_install_platform():
    systems = {"Linux": "linux", "Darwin": "darwin"}
    architectures = {
        "x86_64": "amd64",
        "amd64": "amd64",
        "arm64": "arm64",
        "aarch64": "arm64",
    }
    system = platform.system()
    machine = platform.machine()
    if system not in systems:
        raise SetupError(f"unsupported operating system: {system}")
    if machine not in architectures:
        raise SetupError(f"unsupported architecture: {machine}")
    return systems[system], architectures[machine]


def collect_source_metadata():
    script_path = Path(__file__).resolve()
    candidate_root = script_path.parents[2]
    repository_root = run(
        ["git", "-C", str(candidate_root), "rev-parse", "--show-toplevel"],
        "setup CLI is not in a Git checkout",
    ).strip()
    source_commit = run(
        ["git", "-C", repository_root, "rev-parse", "HEAD"],
        "could not read spells-mainnet source commit",
    ).strip()
    cli_sha256 = hashlib.sha256(script_path.read_bytes()).hexdigest()
    return source_commit, cli_sha256


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
        [
            "gh", "api", "--paginate", "--slurp",
            f"repos/{REPOSITORY}/releases?per_page=100",
            "--hostname", GITHUB_HOST,
        ],
        "could not list Foundry releases",
    )
    pages = parse_json(output, "Foundry release list")
    if not isinstance(pages, list):
        raise SetupError("could not parse Foundry release list")
    releases = []
    for page in pages:
        if not isinstance(page, list):
            raise SetupError("could not parse Foundry release list")
        releases.extend(page)

    cutoff = datetime.now(timezone.utc).timestamp() - MINIMUM_RELEASE_AGE_SECONDS
    eligible = []
    for release in releases:
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
        "version": version,
        "published_at": published_at,
        "published_time": parse_timestamp(published_at),
        "release_url": release_url,
        "selection_reason": "newest stable release published at least seven days ago",
    }


def attest_path(path):
    output = run(
        [
            "gh", "attestation", "verify", str(path),
            "--repo", REPOSITORY,
            "--hostname", GITHUB_HOST,
            "--signer-workflow", SIGNER_WORKFLOW,
            "--format", "json",
        ],
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
    print(f"  Subjects: {subjects}")
    print(f"  Signer: {signer}")
    print(f"  Source: {source}")
    return tag


def verify_binary_paths(paths, expected_tag=None):
    print("\nBinary attestations:")
    installed_tag = None
    for binary, path in zip(BINARIES, paths):
        print(f"{binary} ({path}):")
        tag = attest_path(path)
        if installed_tag is None:
            installed_tag = tag
        elif tag != installed_tag:
            raise SetupError(f"Foundry binaries come from different releases: {installed_tag} and {tag}")
    if expected_tag is not None and installed_tag != expected_tag:
        raise SetupError(f"installed Foundry release {installed_tag} does not match expected release {expected_tag}")
    return installed_tag


def run_binary_versions(paths):
    outputs = []
    print("\nInstalled versions:")
    for path in paths:
        result = subprocess.run(
            [str(path), "--version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if result.returncode:
            raise SetupError(f"could not read version from {path}")
        output = result.stdout.strip()
        if not output:
            raise SetupError(f"empty version output from {path}")
        outputs.append(output)
        print(output)
    return outputs


def resolve_path_binaries():
    paths = []
    for binary in BINARIES:
        resolved = shutil.which(binary)
        if resolved is None:
            raise SetupError(f"Foundry binary not found in PATH: {binary}")
        path = Path(resolved)
        if not path.is_file() or not os.access(path, os.X_OK):
            raise SetupError(f"Foundry command is not an executable file: {path}")
        paths.append(path)
    return paths


def release_metadata(tag):
    output = run(
        ["gh", "api", f"repos/{REPOSITORY}/releases/tags/{tag}", "--hostname", GITHUB_HOST],
        f"could not find Foundry release metadata for {tag}",
    )
    metadata = parse_json(output, f"Foundry release metadata for {tag}")
    if not isinstance(metadata, dict):
        raise SetupError(f"could not parse Foundry release metadata for {tag}")
    return metadata


def validate_installed_release(installed_tag, selection):
    metadata = release_metadata(installed_tag)
    if metadata.get("draft") is not False or metadata.get("prerelease") is not False:
        raise SetupError(f"installed Foundry release is not stable: {installed_tag}")
    if installed_tag == selection["version"]:
        return f"installed release matches eligible stable {selection['version']}"
    installed_published = parse_timestamp(metadata.get("published_at"))
    if installed_published > selection["published_time"]:
        raise SetupError(
            f"installed Foundry release {installed_tag} violates the seven-day policy; "
            f"eligible release is {selection['version']}"
        )
    raise SetupError(
        f"installed Foundry release {installed_tag} does not match newest eligible stable "
        f"{selection['version']}; run make install-foundry"
    )


def report_selection(selection, source_commit, cli_sha256):
    print(f"Eligible Foundry release: {selection['version']}")
    print(f"Published at: {selection['published_at']}")
    print(f"Release URL: {selection['release_url']}")
    print(f"Selection policy: {selection['selection_reason']}")
    print(f"spells-mainnet commit: {source_commit}")
    print(f"Setup CLI SHA-256: {cli_sha256}")


def report_verification_summary(selection, source_commit, cli_sha256, installed_tag, version_status):
    print("\nEvidence summary:")
    print(f"  Source: spells-mainnet {source_commit}; setup CLI SHA-256 {cli_sha256}")
    print(f"  Eligible release: {selection['version']}; {selection['published_at']}; {selection['release_url']}")
    print(f"  Policy decision: {selection['selection_reason']}")
    print(f"  Installed release: {installed_tag}; {version_status}")
    print(f"  Binary attestations: forge, cast, anvil, and chisel verified against {SIGNER_WORKFLOW}")


def extract_release_archive(archive, extracted_directory):
    expected = sorted(BINARIES)
    try:
        with tarfile.open(archive, "r:gz") as source:
            members = source.getmembers()
            if sorted(member.name for member in members) != expected or any(not member.isfile() for member in members):
                raise SetupError(
                    "archive must contain only regular files named forge, cast, anvil, and chisel"
                )
            extracted_directory.mkdir()
            for member in members:
                input_file = source.extractfile(member)
                if input_file is None:
                    raise SetupError(f"could not read archive member: {member.name}")
                output_path = extracted_directory / member.name
                with input_file, output_path.open("xb") as output_file:
                    shutil.copyfileobj(input_file, output_file)
                output_path.chmod(0o755)
    except SetupError:
        raise
    except (OSError, tarfile.TarError) as error:
        raise SetupError(f"could not read Foundry release archive: {error}") from error


def path_exists(path):
    return os.path.lexists(path)


def terminate_installation(_signal_number, _frame):
    raise SetupError("terminated")


def copy_entry(source, destination):
    if source.is_symlink():
        destination.symlink_to(os.readlink(source))
    else:
        shutil.copy2(source, destination, follow_symlinks=False)


class Installation:
    def __init__(self, destination, backup_directory):
        self.destination = destination
        self.backup_directory = backup_directory
        self.destination_created = False
        self.rollback_required = False

    def prepare(self):
        if path_exists(self.destination):
            if not self.destination.is_dir():
                raise SetupError(f"installation destination is not a directory: {self.destination}")
        else:
            self.destination_created = True
        self.backup_directory.mkdir(mode=0o700)
        for binary in BINARIES:
            current = self.destination / binary
            if not path_exists(current):
                continue
            if not current.is_file() and not current.is_symlink():
                raise SetupError(f"existing Foundry path is not a file or symbolic link: {current}")
            copy_entry(current, self.backup_directory / binary)

    def install(self, extracted_directory):
        self.rollback_required = True
        if self.destination_created:
            self.destination.mkdir(parents=True, mode=0o755)
            self.destination.chmod(0o755)
        for binary in BINARIES:
            descriptor, temporary_name = tempfile.mkstemp(
                dir=self.destination,
                prefix=f".{binary}.setup-foundry.",
            )
            os.close(descriptor)
            temporary = Path(temporary_name)
            try:
                shutil.copyfile(extracted_directory / binary, temporary)
                temporary.chmod(0o755)
                os.replace(temporary, self.destination / binary)
            finally:
                if path_exists(temporary):
                    temporary.unlink()

    def commit(self):
        self.rollback_required = False

    def rollback(self):
        if not self.rollback_required:
            return
        print("\nInstallation did not complete; restoring the previous Foundry binaries.", file=sys.stderr)
        rollback_failed = False
        for binary in BINARIES:
            current = self.destination / binary
            backup = self.backup_directory / binary
            try:
                if path_exists(current):
                    current.unlink()
                if path_exists(backup):
                    copy_entry(backup, current)
            except OSError as error:
                print(f"Rollback error: could not restore {current}: {error}", file=sys.stderr)
                rollback_failed = True
        if self.destination_created and path_exists(self.destination):
            try:
                self.destination.rmdir()
            except OSError as error:
                print(f"Rollback error: could not remove newly created directory {self.destination}: {error}", file=sys.stderr)
                rollback_failed = True
        if rollback_failed:
            print(f"Error: Foundry rollback was incomplete; inspect {self.destination} before continuing.", file=sys.stderr)
        else:
            print("Previous Foundry installation restored.", file=sys.stderr)
        self.rollback_required = False


def verify_foundry():
    validate_environment()
    source_commit, cli_sha256 = collect_source_metadata()
    selection = select_release()
    report_selection(selection, source_commit, cli_sha256)
    paths = resolve_path_binaries()
    installed_tag = verify_binary_paths(paths)
    version_status = validate_installed_release(installed_tag, selection)
    run_binary_versions(paths)
    report_verification_summary(selection, source_commit, cli_sha256, installed_tag, version_status)
    print("\nFoundry verification completed successfully.")


def install_foundry():
    validate_environment()
    system, architecture = validate_install_platform()
    source_commit, cli_sha256 = collect_source_metadata()
    selection = select_release()
    asset = f"foundry_{selection['version']}_{system}_{architecture}.tar.gz"
    destination = Path.home() / ".foundry" / "bin"

    with tempfile.TemporaryDirectory() as temporary_name:
        temporary_directory = Path(temporary_name)
        archive = temporary_directory / asset
        extracted_directory = temporary_directory / "extracted"
        backup_directory = temporary_directory / "previous-installation"
        report_selection(selection, source_commit, cli_sha256)
        run(
            [
                "gh", "release", "download", selection["version"],
                "--repo", QUALIFIED_REPOSITORY,
                "--pattern", asset,
                "--dir", str(temporary_directory),
            ],
            f"could not download Foundry release asset {asset}",
        )
        print("\nRelease asset attestation:")
        asset_tag = attest_path(archive)
        if asset_tag != selection["version"]:
            raise SetupError(
                f"release asset attestation tag {asset_tag} does not match {selection['version']}"
            )
        extract_release_archive(archive, extracted_directory)

        installation = Installation(destination, backup_directory)
        installation.prepare()
        try:
            installation.install(extracted_directory)
            paths = [destination / binary for binary in BINARIES]
            verify_binary_paths(paths, selection["version"])
            run_binary_versions(paths)
            installation.commit()
        except BaseException:
            installation.rollback()
            raise

    print("\nEvidence summary:")
    print(f"  Source: spells-mainnet {source_commit}; setup CLI SHA-256 {cli_sha256}")
    print(f"  Release: {selection['version']}; {selection['published_at']}; {selection['release_url']}")
    print(f"  Policy decision: {selection['selection_reason']}")
    print(f"  Release asset attestation: verified against {SIGNER_WORKFLOW}")
    print(f"  Binary attestations: forge, cast, anvil, and chisel verified against {SIGNER_WORKFLOW}")

    if str(destination) not in os.environ.get("PATH", "").split(os.pathsep):
        print(f"\nFoundry was installed and verified, but {destination} is not in PATH.", file=sys.stderr)
        print('Run: export PATH="$HOME/.foundry/bin:$PATH"', file=sys.stderr)
        print("Add the same export to your shell profile, then start a new shell before continuing.", file=sys.stderr)
        return 2
    print("\nFoundry installation and verification completed successfully.")
    return 0


def main(arguments):
    if len(arguments) != 1 or arguments[0] not in ("verify", "install"):
        usage()
        return 1
    previous_sigterm = signal.signal(signal.SIGTERM, terminate_installation)
    try:
        if arguments[0] == "verify":
            verify_foundry()
            return 0
        return install_foundry()
    except SetupError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Error: interrupted", file=sys.stderr)
        return 1
    finally:
        signal.signal(signal.SIGTERM, previous_sigterm)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
