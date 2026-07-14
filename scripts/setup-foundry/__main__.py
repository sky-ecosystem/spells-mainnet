"""Run the Foundry setup command-line interface as a module."""

import sys

from .cli import main


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
