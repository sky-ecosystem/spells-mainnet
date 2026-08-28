"""Install-command orchestration."""

from pathlib import Path

from installation import install_selected_release, validate_install_platform
from releases import load_requested_release
from reporting import (
    report_installation_path_status,
    report_installation_summary,
    report_selection,
)
from runtime import collect_source_metadata, validate_environment


TOOL_ROOT = Path(__file__).resolve().parents[1]


def handle(release: str, ignore_age: bool) -> int:
    validate_environment()
    platform_target = validate_install_platform()
    source_commit, tooling_hash = collect_source_metadata(TOOL_ROOT)
    selection = load_requested_release(release, ignore_age)
    destination = Path.home() / ".foundry" / "bin"
    report_selection(selection, source_commit, tooling_hash)
    install_selected_release(selection, destination, platform_target)
    report_installation_summary(selection, source_commit, tooling_hash)
    return report_installation_path_status(destination)
