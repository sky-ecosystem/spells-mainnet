# Verified Foundry setup

## Why this exists

[Foundry's standard installation procedure](https://getfoundry.sh/getting-started/installation) bootstraps `foundryup` by piping a remotely hosted script directly into Bash:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

The executed script is not pinned to this repository or reviewable as part of its history. Running `foundryup` then installs the release currently labeled stable without the release-age and provenance safeguards introduced by this setup tool.

Foundry is part of the toolchain used to build, test, and deploy executive spells. This repository therefore keeps its installation and verification logic under source control instead of relying on the remote bootstrap script.

This script provides one auditable process for installing and verifying Foundry. It selects the newest release that:

- uses an exact stable tag in the form `vMAJOR.MINOR.PATCH`;
- is neither a draft nor a prerelease;
- is immutable;
- was published at least 14 days ago; and
- was produced by Foundry's official release workflow, as proven by GitHub attestations.

The script verifies the downloaded archive before extracting it, verifies `forge`, `cast`, `anvil`, and `chisel` before executing them, and requires all four binaries to come from the same release. If an installation fails after modifying the destination, it restores the previous binaries.

The selected version can change as newer releases satisfy the policy; this tool enforces the policy rather than permanently pinning one Foundry version.

The 14-day cooling period follows the current executive spell cadence. It provides time for public detection and response, but it is not a guarantee that every upstream compromise will be discovered within that period.

## Security model and limitations

GitHub attestations establish that an artifact was produced by the expected repository workflow. They prevent an externally built binary without that provenance from passing verification, but they do not establish that Foundry's source code, dependencies, release workflow, or GitHub account were uncompromised when the artifact was built.

[Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) prevent a published release's tag and assets from being modified or replaced in place. GitHub permits maintainers to delete the entire release, but the immutable release's tag name cannot be reused after deletion. A compromised immutable release therefore cannot be replaced by different binaries under the same version tag.

If Foundry deletes a malicious release, this tool will no longer select it for installation, and verification of an installed copy will fail because the release metadata is unavailable. If Foundry leaves the release published, however, this tool can continue accepting it once it satisfies the age policy. Publishing a clean newer release does not immediately revoke the malicious release; without an approved override, the newer release becomes eligible only after completing its own 14-day cooling period.

This tool does not maintain a repository-local revocation list or an allowlist of approved Foundry releases. It therefore depends on upstream deletion, or a subsequent change to this repository, to reject a known-malicious release immediately.

## Urgent security releases

When a Foundry security fix cannot wait for the cooling period, the spell team can explicitly approve an immutable stable release that is less than 14 days old. The override waives only the release-age requirement; tag format, release metadata, workflow provenance, and binary attestation checks remain mandatory.

Install and verify the exact approved release with:

```bash
make install-foundry release=vMAJOR.MINOR.PATCH
make verify-foundry release=vMAJOR.MINOR.PATCH
```

The override is rejected after the release completes the cooling period, preventing it from being used as a general version pin or downgrade mechanism. Record the upstream security advisory or incident reference, the spell-team approval, and the complete installer and verifier output.

## Supported platforms

The `install` command supports these operating-system and architecture combinations:

| Operating system | Reported architecture | Installed release asset |
| --- | --- | --- |
| Linux | `x86_64` or `amd64` | `linux_amd64` |
| Linux | `arm64` or `aarch64` | `linux_arm64` |
| macOS on Intel | `x86_64` | `darwin_amd64` |
| macOS on Apple Silicon | `arm64`, `aarch64`, or an `x86_64` shell under Rosetta | `darwin_arm64` |

Native Windows, other operating systems, and other architectures are not supported.

## Prerequisites

Run the tool from this Git checkout in a Bash environment with:

- `gh`, authenticated to `github.com`;
- `git`;
- `sha256sum` or `shasum`; and
- standard utilities including `tar`, `install`, `mktemp`, `sort`, and `sed`.

## Install Foundry

From the repository root, run:

```bash
make install-foundry
```

The command installs the verified binaries in `~/.foundry/bin`. If that directory is not already in `PATH`, the installation succeeds but exits with status 2 and prints the required `PATH` configuration.

## Verify Foundry

To verify the Foundry binaries currently resolved from `PATH` against the same release policy and attestations, run:

```bash
make verify-foundry
```

## Test the setup tool

Run the setup tool's test suite with:

```bash
make test-setup-foundry
```

The test harness additionally requires `jq`; the setup tool itself does not.
