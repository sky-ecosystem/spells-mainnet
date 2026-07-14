#!/usr/bin/env python3
"""Executable wrapper for the repository's verified Foundry setup tooling.

The delegated package pins GitHub and Foundry's release workflow as trust roots
and permits only the newest stable release that has matured for seven days.
"""

import sys
from importlib import import_module
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
main = import_module("setup-foundry.cli").main


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
