"""Verify-command orchestration."""

from pathlib import Path

from ..releases import select_release
from ..reporting import report_selection, report_verification_summary
from ..runtime import collect_source_metadata, validate_environment
from ..toolchain import (
    resolve_path_binaries,
    run_binary_versions,
    validate_installed_release,
    verify_binary_paths,
)


TOOL_ROOT = Path(__file__).resolve().parents[2]


def handle() -> int:
    validate_environment()
    source_commit, tooling_hash = collect_source_metadata(TOOL_ROOT)
    selection = select_release()
    report_selection(selection, source_commit, tooling_hash)
    paths = resolve_path_binaries()
    installed_tag = verify_binary_paths(paths)
    version_status = validate_installed_release(installed_tag, selection)
    run_binary_versions(paths)
    report_verification_summary(
        selection, source_commit, tooling_hash, installed_tag, version_status
    )
    print("\nFoundry verification completed successfully.")
    return 0
