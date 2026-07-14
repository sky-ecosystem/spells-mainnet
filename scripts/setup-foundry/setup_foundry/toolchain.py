import os
import shutil
import subprocess
from pathlib import Path

from .config import BINARIES
from .releases import attest_path, parse_timestamp, release_metadata
from .runtime import SetupError


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
        result = subprocess.run([str(path), "--version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
        if result.returncode:
            raise SetupError(f"could not read version from {path}")
        output = result.stdout.strip()
        if not output:
            raise SetupError(f"empty version output from {path}")
        outputs.append(output)
        print(output)
    return outputs


def validate_installed_release(installed_tag, selection):
    metadata = release_metadata(installed_tag)
    if metadata.get("draft") is not False or metadata.get("prerelease") is not False:
        raise SetupError(f"installed Foundry release is not stable: {installed_tag}")
    if installed_tag == selection["version"]:
        return f"installed release matches eligible stable {selection['version']}"
    installed_published = parse_timestamp(metadata.get("published_at"))
    if installed_published > selection["published_time"]:
        raise SetupError(
            f"installed Foundry release {installed_tag} violates the seven-day policy; eligible release is {selection['version']}"
        )
    raise SetupError(
        f"installed Foundry release {installed_tag} does not match newest eligible stable {selection['version']}; run make install-foundry"
    )
