"""Process, environment, and source-metadata utilities."""

import hashlib
import shutil
import subprocess
from pathlib import Path

from config import GITHUB_HOST


class SetupError(Exception):
    """A user-facing setup failure."""


class InstallationRequired(SetupError):
    """A verification failure recoverable by installing the requested release."""

    def __init__(self, message, release, ignore_age):
        super().__init__(message)
        self.release = release
        self.ignore_age = ignore_age


def run(command, failure_message):
    result = subprocess.run(command, capture_output=True, text=True, check=False)
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
    digest = hashlib.sha256()
    for path in _runtime_paths(tool_root):
        digest.update(path.relative_to(tool_root).as_posix().encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def _is_runtime_path(relative_path):
    return (
        relative_path.suffix == ".py"
        and "__pycache__" not in relative_path.parts
        and relative_path.parts[0] != "mocks"
        and not relative_path.name.endswith("_test.py")
    )


def _runtime_paths(tool_root):
    return sorted(
        (
            path
            for path in tool_root.rglob("*.py")
            if _is_runtime_path(path.relative_to(tool_root))
        ),
        key=lambda item: item.relative_to(tool_root).as_posix(),
    )


def _committed_tooling_sha256(repository_root, source_commit, tool_root):
    relative_root = tool_root.relative_to(repository_root)
    output = run(
        [
            "git",
            "-C",
            str(repository_root),
            "ls-tree",
            "-r",
            "--name-only",
            source_commit,
            "--",
            relative_root.as_posix(),
        ],
        "could not list setup tooling in HEAD",
    )
    committed = []
    for value in output.splitlines():
        repository_path = Path(value)
        try:
            relative_path = repository_path.relative_to(relative_root)
        except ValueError:
            continue
        if _is_runtime_path(relative_path):
            committed.append((relative_path, repository_path))

    digest = hashlib.sha256()
    for relative_path, repository_path in sorted(
        committed, key=lambda item: item[0].as_posix()
    ):
        result = subprocess.run(
            [
                "git",
                "-C",
                str(repository_root),
                "show",
                f"{source_commit}:{repository_path.as_posix()}",
            ],
            capture_output=True,
            check=False,
        )
        if result.returncode:
            raise SetupError("could not read setup tooling from HEAD")
        digest.update(relative_path.as_posix().encode())
        digest.update(b"\0")
        digest.update(result.stdout)
        digest.update(b"\0")
    return digest.hexdigest(), {path for path, _ in committed}


def collect_source_metadata(tool_root):
    tool_root = Path(tool_root).resolve()
    repository_root = run(
        ["git", "-C", str(tool_root.parent), "rev-parse", "--show-toplevel"],
        "setup tooling is not in a Git checkout",
    ).strip()
    source_commit = run(
        ["git", "-C", repository_root, "rev-parse", "HEAD"],
        "could not read spells-mainnet source commit",
    ).strip()
    if not tool_root.is_relative_to(repository_root):
        raise SetupError("setup tooling is outside its Git checkout")
    local_paths = {path.relative_to(tool_root) for path in _runtime_paths(tool_root)}
    local_hash = tooling_sha256(tool_root)
    committed_hash, committed_paths = _committed_tooling_sha256(
        Path(repository_root), source_commit, tool_root
    )
    if local_paths != committed_paths or local_hash != committed_hash:
        raise SetupError(
            "setup tooling differs from HEAD; commit or restore it before continuing"
        )
    return source_commit, local_hash
