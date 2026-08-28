"""Inspect and verify an installed Foundry toolchain."""

import shutil
import subprocess
from pathlib import Path

from config import BINARIES
from releases import attest_path
from runtime import InstallationRequired, SetupError


def resolve_path_binaries(release, ignore_age):
    paths = []
    for binary in BINARIES:
        resolved = shutil.which(binary)
        if resolved is None:
            raise InstallationRequired(
                f"Foundry binary not found in PATH: {binary}", release, ignore_age
            )
        path = Path(resolved)
        if not path.is_file() or not path.stat().st_mode & 0o111:
            raise SetupError(f"Foundry command is not an executable file: {path}")
        paths.append(path)
    return paths


def verify_binary_paths(paths, expected_tag=None):
    print("\nBinary attestations:")
    installed_tag = None
    for binary, path in zip(BINARIES, paths):
        print(f"{binary} ({path}):")
        tag = attest_path(path)
        if installed_tag is None:
            installed_tag = tag
        elif tag != installed_tag:
            raise SetupError(
                f"Foundry binaries come from different releases: {installed_tag} and {tag}"
            )
    if expected_tag is not None and installed_tag != expected_tag:
        raise SetupError(
            f"installed Foundry release {installed_tag} does not match expected release {expected_tag}"
        )
    return installed_tag


def run_binary_versions(paths):
    print("\nInstalled versions:")
    for path in paths:
        result = subprocess.run(
            [str(path), "--version"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode:
            raise SetupError(f"could not read version from {path}")
        output = result.stdout.strip()
        if not output:
            raise SetupError(f"empty version output from {path}")
        print(output)


def validate_installed_release(installed_tag, selection, ignore_age):
    if installed_tag != selection["version"]:
        raise InstallationRequired(
            f"installed Foundry release {installed_tag} does not match requested release {selection['version']}",
            selection["version"],
            ignore_age,
        )
    return (
        "installed release matches explicitly requested immutable stable "
        f"{selection['version']}"
    )
