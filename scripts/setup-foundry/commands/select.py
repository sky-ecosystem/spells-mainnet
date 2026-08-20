"""Select-command orchestration."""

from pathlib import Path

from releases import select_release
from reporting import report_selection
from runtime import collect_source_metadata, validate_environment


TOOL_ROOT = Path(__file__).resolve().parents[1]


def handle(ignore_age: bool) -> int:
    validate_environment()
    source_commit, tooling_hash = collect_source_metadata(TOOL_ROOT)
    selection = select_release(ignore_age)
    report_selection(selection, source_commit, tooling_hash)
    print("\nFoundry release selection completed successfully.")
    return 0
