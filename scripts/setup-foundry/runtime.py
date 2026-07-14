"""Process, environment, and source-metadata utilities."""

import hashlib
import shutil
import subprocess
from pathlib import Path

from config import GITHUB_HOST


class SetupError(Exception):
    """A user-facing setup failure."""


def run(command, failure_message):
    result = subprocess.run(
        command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise SetupError(
            failure_message if not detail else f"{failure_message}: {detail}"
        )
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


def tooling_sha256(tool_root):
    tool_root = Path(tool_root)
    mocks_root = tool_root / "mocks"
    paths = [
        path
        for path in tool_root.rglob("*.py")
        if "__pycache__" not in path.parts
        and mocks_root not in path.parents
        and not path.name.endswith("_test.py")
    ]
    digest = hashlib.sha256()
    for path in sorted(paths, key=lambda item: item.relative_to(tool_root).as_posix()):
        digest.update(path.relative_to(tool_root).as_posix().encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def collect_source_metadata(tool_root):
    tool_root = Path(tool_root).resolve()
    candidate_root = tool_root.parent
    repository_root = run(
        ["git", "-C", str(candidate_root), "rev-parse", "--show-toplevel"],
        "setup tooling is not in a Git checkout",
    ).strip()
    source_commit = run(
        ["git", "-C", repository_root, "rev-parse", "HEAD"],
        "could not read spells-mainnet source commit",
    ).strip()
    return source_commit, tooling_sha256(tool_root)
