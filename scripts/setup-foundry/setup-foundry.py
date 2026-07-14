#!/usr/bin/env python3
"""CLI for the repository's verified Foundry setup tooling.

The delegated package pins GitHub and Foundry's release workflow as trust roots
and permits only the newest stable release that has matured for seven days.
"""

import signal
import sys
from pathlib import Path

from setup_foundry.commands import install, verify
from setup_foundry.runtime import SetupError


def usage():
    print(f"Usage: {Path(sys.argv[0]).name} {{verify|install}}", file=sys.stderr)


def terminate(_signal_number, _frame):
    raise SetupError("terminated")


def main(arguments):
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


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
