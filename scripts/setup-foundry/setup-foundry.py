#!/usr/bin/env python3
"""CLI for the repository's verified Foundry setup tooling."""

from __future__ import annotations

import signal
import sys
from collections.abc import Sequence
from pathlib import Path

from commands import install, select, verify
from config import MINIMUM_RELEASE_AGE_DAYS
from runtime import InstallationRequired, SetupError


class UsageError(Exception):
    def __init__(self, message: str, command: str | None = None):
        super().__init__(message)
        self.command = command


def usage(command: str | None = None, *, stream=sys.stdout) -> None:
    """Print the top-level or command-specific manual entry."""
    name = Path(sys.argv[0]).name
    manuals = {
        None: f"""NAME
    {name} - select, verify, or install a policy-compliant Foundry release

SYNOPSIS
    {name} COMMAND [OPTION...]
    {name} --help

DESCRIPTION
    Selects, verifies, or installs immutable stable Foundry releases using the
    repository's release-age and artifact-attestation policy.

COMMANDS
    select
        Select and report a release after archive-attestation availability checks.

    verify
        Verify the Foundry binaries resolved from PATH against an exact release.

    install
        Install an explicitly requested release in $HOME/.foundry/bin, replacing
        any existing Foundry binaries there.

OPTIONS
    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation, policy check, verification, or installation did not
            complete successfully.

EXAMPLES
    {name} select
    {name} install --release v1.7.1
    {name} verify --release v1.7.1
""",
        "select": f"""NAME
    {name} select - select an installable Foundry release

SYNOPSIS
    {name} select [--ignore-age]

DESCRIPTION
    Selects and reports the newest immutable stable Foundry release whose
    supported archives publish SHA-256 digests and SLSA provenance attestations.
    Does not download artifacts or resolve, attest, or execute installed Foundry
    binaries.

OPTIONS
    --ignore-age
        Select the newest immutable stable release without enforcing the
        {MINIMUM_RELEASE_AGE_DAYS}-day cooling period. No other metadata requirement is bypassed.

    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation or policy check did not complete successfully.

EXAMPLES
    {name} select
    {name} select --ignore-age
""",
        "verify": f"""NAME
    {name} verify - verify a policy-compliant Foundry release

SYNOPSIS
    {name} verify --release RELEASE [--ignore-age]

DESCRIPTION
    Verifies the Foundry binaries resolved from PATH against an exact immutable
    stable release.

OPTIONS
    --release RELEASE
        Verify an exact immutable stable release. This option is required. The
        {MINIMUM_RELEASE_AGE_DAYS}-day cooling period remains enforced.

    --ignore-age
        Permit an explicitly requested release younger than {MINIMUM_RELEASE_AGE_DAYS} days.
        Requires --release and does not bypass any other verification.

    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation, policy check, or verification did not complete
            successfully.

EXAMPLES
    {name} verify --release v1.7.0
    {name} verify --release v1.7.1 --ignore-age
""",
        "install": f"""NAME
    {name} install - install a policy-compliant Foundry release

SYNOPSIS
    {name} install --release RELEASE [--ignore-age]

DESCRIPTION
    Downloads and installs an explicitly requested release in $HOME/.foundry/bin,
    replacing any existing Foundry binaries there.

OPTIONS
    --release RELEASE
        Install an exact immutable stable release. This option is required. The
        {MINIMUM_RELEASE_AGE_DAYS}-day cooling period remains enforced.

    --ignore-age
        Permit an explicitly requested release younger than {MINIMUM_RELEASE_AGE_DAYS} days.
        Requires --release and does not bypass any other verification.

    --help
        Display this help and exit.

EXIT STATUS
    0       The command completed successfully, or help was displayed.
    nonzero The invocation, policy check, verification, or installation did not
            complete successfully.

EXAMPLES
    {name} install --release v1.7.1
    {name} install --release v1.7.1 --ignore-age
""",
    }
    print(manuals[command], file=stream, end="")


def parse_arguments(arguments: Sequence[str]):
    if not arguments:
        raise UsageError("command is required")
    if arguments[0] == "--help":
        if len(arguments) != 1:
            raise UsageError("--help cannot be combined with other arguments")
        return None

    command = arguments[0]
    if command not in ("select", "verify", "install"):
        raise UsageError(f"unknown command: {command}")
    remaining = list(arguments[1:])
    if remaining and remaining[0] == "--help":
        if len(remaining) != 1:
            raise UsageError("--help cannot be combined with other arguments", command)
        return command, None, False, True

    release = None
    ignore_age = False
    index = 0
    while index < len(remaining):
        argument = remaining[index]
        if argument == "--ignore-age":
            ignore_age = True
            index += 1
        elif argument == "--release":
            if command == "select":
                raise UsageError("select does not accept --release", command)
            if (
                index + 1 == len(remaining)
                or not remaining[index + 1]
                or remaining[index + 1].startswith("--")
            ):
                raise UsageError("--release requires a value", command)
            release = remaining[index + 1]
            index += 2
        elif argument.startswith("--release="):
            if command == "select":
                raise UsageError("select does not accept --release", command)
            release = argument.removeprefix("--release=")
            if not release:
                raise UsageError("--release requires a value", command)
            index += 1
        elif argument == "--help":
            raise UsageError("--help cannot be combined with other arguments", command)
        elif argument == "--":
            index += 1
            if index < len(remaining):
                raise UsageError(f"unexpected argument: {remaining[index]}", command)
        elif argument.startswith("-"):
            raise UsageError(f"unknown option: {argument}", command)
        else:
            raise UsageError(f"unexpected argument: {argument}", command)

    if command in ("verify", "install") and release is None:
        raise UsageError(f"{command} requires --release", command)
    return command, release, ignore_age, False


def terminate(_signal_number, _frame) -> None:
    raise SetupError("terminated")


def main(arguments: Sequence[str]) -> int:
    try:
        parsed = parse_arguments(arguments)
    except UsageError as error:
        print(f"Error: {error}\n", file=sys.stderr)
        usage(error.command, stream=sys.stderr)
        return 1

    if parsed is None:
        usage()
        return 0
    command, release, ignore_age, help_requested = parsed
    if help_requested:
        usage(command)
        return 0

    previous_sigterm = signal.signal(signal.SIGTERM, terminate)
    try:
        if command == "select":
            return select.handle(ignore_age)
        return {"verify": verify.handle, "install": install.handle}[command](
            release, ignore_age
        )
    except InstallationRequired as error:
        print(f"Error: {error}", file=sys.stderr)
        print("Required action: install", file=sys.stderr)
        command = f"make install-foundry release={error.release}"
        if error.ignore_age:
            command += " ignore-age=1"
        print(f"Installation command: {command}", file=sys.stderr)
        return 1
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
