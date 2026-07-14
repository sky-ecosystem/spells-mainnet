"""Install-command orchestration."""

from pathlib import Path

from ..installation import foundry_destination, install_selected_release
from ..releases import select_release
from ..reporting import (
    report_installation_path_status,
    report_installation_summary,
    report_selection,
)
from ..runtime import collect_source_metadata, validate_environment


TOOL_ROOT = Path(__file__).resolve().parents[1]


def handle() -> int:
    validate_environment()
    source_commit, tooling_hash = collect_source_metadata(TOOL_ROOT)
    selection = select_release()
    destination = foundry_destination()
    report_selection(selection, source_commit, tooling_hash)
    install_selected_release(selection, destination)
    report_installation_summary(selection, source_commit, tooling_hash)
    return report_installation_path_status(destination)
