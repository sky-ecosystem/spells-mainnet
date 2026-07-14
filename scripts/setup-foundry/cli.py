"""Command-line interface for the Foundry setup package."""

import signal
import sys
from collections.abc import Sequence
from pathlib import Path

from .commands import install, verify
from .runtime import SetupError


def usage() -> None:
    """Print command usage to standard error."""
    print(f"Usage: {Path(sys.argv[0]).name} {{verify|install}}", file=sys.stderr)


def terminate(_signal_number, _frame) -> None:
    """Normalize process termination to a user-facing setup error."""
    raise SetupError("terminated")


def main(arguments: Sequence[str]) -> int:
    """Dispatch a setup command and return its process exit code."""
    if len(arguments) != 1 or arguments[0] not in ("verify", "install"):
        usage()
        return 1

    previous_sigterm = signal.signal(signal.SIGTERM, terminate)
    try:
        return {"verify": verify.handle, "install": install.handle}[arguments[0]]()
    except SetupError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Error: interrupted", file=sys.stderr)
        return 1
    finally:
        signal.signal(signal.SIGTERM, previous_sigterm)
