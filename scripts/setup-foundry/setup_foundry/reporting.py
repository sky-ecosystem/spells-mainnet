import os
import sys

from .config import SIGNER_WORKFLOW


def report_selection(selection, source_commit, tooling_hash):
    print(f"Eligible Foundry release: {selection['version']}")
    print(f"Published at: {selection['published_at']}")
    print(f"Release URL: {selection['release_url']}")
    print(f"Selection policy: {selection['selection_reason']}")
    print(f"spells-mainnet commit: {source_commit}")
    print(f"Setup tooling SHA-256: {tooling_hash}")


def report_verification_summary(selection, source_commit, tooling_hash, installed_tag, version_status):
    print("\nEvidence summary:")
    print(f"  Source: spells-mainnet {source_commit}; setup tooling SHA-256 {tooling_hash}")
    print(f"  Eligible release: {selection['version']}; {selection['published_at']}; {selection['release_url']}")
    print(f"  Policy decision: {selection['selection_reason']}")
    print(f"  Installed release: {installed_tag}; {version_status}")
    print(f"  Binary attestations: forge, cast, anvil, and chisel verified against {SIGNER_WORKFLOW}")


def report_installation_summary(selection, source_commit, tooling_hash):
    print("\nEvidence summary:")
    print(f"  Source: spells-mainnet {source_commit}; setup tooling SHA-256 {tooling_hash}")
    print(f"  Release: {selection['version']}; {selection['published_at']}; {selection['release_url']}")
    print(f"  Policy decision: {selection['selection_reason']}")
    print(f"  Release asset attestation: verified against {SIGNER_WORKFLOW}")
    print(f"  Binary attestations: forge, cast, anvil, and chisel verified against {SIGNER_WORKFLOW}")


def report_installation_path_status(destination):
    if str(destination) not in os.environ.get("PATH", "").split(os.pathsep):
        print(f"\nFoundry was installed and verified, but {destination} is not in PATH.", file=sys.stderr)
        print('Run: export PATH="$HOME/.foundry/bin:$PATH"', file=sys.stderr)
        print("Add the same export to your shell profile, then start a new shell before continuing.", file=sys.stderr)
        return 2
    print("\nFoundry installation and verification completed successfully.")
    return 0
