# Verified Foundry setup

## Why this exists

[Foundry's standard installation procedure](https://getfoundry.sh/getting-started/installation) bootstraps `foundryup` by piping a remotely hosted script directly into Bash:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

The executed script is not pinned to this repository or reviewable as part of its history. Running `foundryup` then installs the release currently labeled stable without the release-age and provenance safeguards introduced by this setup tool.

Foundry is part of the toolchain used to build, test, and deploy executive spells. This repository therefore keeps its installation and verification logic under source control instead of relying on the remote bootstrap script.

This script provides one auditable process for installing and verifying Foundry. The verifier selects the newest release that:

- uses an exact stable tag in the form `vMAJOR.MINOR.PATCH`;
- is neither a draft nor a prerelease;
- is immutable;
- was published at least 14 days ago; and
- was produced by Foundry's official release workflow, as proven by GitHub attestations.

If the installed binaries do not match the desired release, the verifier reports the exact release and installation command. Without an explicit release, the installer selects the same newest age-eligible release as the verifier; with a release parameter, it installs only that exact release. It verifies the downloaded archive before extracting it, verifies `forge`, `cast`, `anvil`, and `chisel` before executing them, and requires all four binaries to come from the same release. If an installation fails after modifying the destination, it restores the previous binaries.

The selected version can change as newer releases satisfy the policy; the verifier enforces the policy rather than permanently pinning one Foundry version.

The 14-day cooling period follows the current executive spell cadence. It provides time for public detection and response, but it is not a guarantee that every upstream compromise will be discovered within that period.

## Security model and limitations

GitHub attestations establish that an artifact was produced by the expected repository workflow. They prevent an externally built binary without that provenance from passing verification, but they do not establish that Foundry's source code, dependencies, release workflow, or GitHub account were uncompromised when the artifact was built.

[Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) prevent a published release's tag and assets from being modified or replaced in place. GitHub permits maintainers to delete the entire release, but the immutable release's tag name cannot be reused after deletion. A compromised immutable release therefore cannot be replaced by different binaries under the same version tag.

If Foundry deletes a malicious release, the verifier will no longer select it, explicit installation will fail because the release metadata is unavailable, and verification of an installed copy will also fail. If Foundry leaves the release published, however, the verifier can continue accepting it once it satisfies the age policy. Publishing a clean newer release does not immediately revoke the malicious release; without an approved force override, the newer release becomes eligible only after completing its own 14-day cooling period.

This tool does not maintain a repository-local revocation list or an allowlist of approved Foundry releases. It therefore depends on upstream deletion, or a subsequent change to this repository, to reject a known-malicious release immediately.

## Urgent security releases

The spell team can force an exact immutable stable release when the automatically selected release cannot be used. Force bypasses automatic release selection and, when necessary, the release-age requirement; tag format, release metadata, workflow provenance, and binary attestation checks remain mandatory.

Use `force=1` to install and verify the exact approved release:

```bash
make install-foundry release=vMAJOR.MINOR.PATCH force=1
make verify-foundry release=vMAJOR.MINOR.PATCH force=1
```

The `-f` CLI flag, exposed only as `force=1` by the Make targets, stands for force. It selects the exact approved release regardless of age, including when that release is older than the normal policy selection. Record the upstream security advisory or incident reference, the spell-team approval, and the complete installer and verifier output.

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

## CI installation

CI environments are expected to be clean, with no previous Foundry installation. Install the policy-selected release and then verify that it is resolved from `PATH`:

```bash
make install-foundry
make verify-foundry
```

## Developer machine setup

Engineers will usually already have Foundry installed. Run the verifier first to check the binaries currently resolved from `PATH` against the release policy and attestations:

```bash
make verify-foundry
```

The verifier succeeds when the installed release is valid. Any nonzero result is a failure. Install another release only when the output includes all three of these fields:

- `Required action: install`;
- `Desired Foundry release:`; and
- `Installation command:`.

Review the desired release, run the exact installation command printed by the verifier, and then rerun `make verify-foundry`:

```bash
make install-foundry release=vMAJOR.MINOR.PATCH
make verify-foundry
```

Crafter and reviewer workflows must require all three fields before installing. Any other failure must be diagnosed without automatically installing.

## Installation and verification behavior

Without a release parameter, the installer selects the newest immutable stable release published at least 14 days ago. With a release parameter, it validates and installs only that exact age-eligible release. `force=1` requires an explicit release. The command installs the verified binaries in `~/.foundry/bin`. If that directory is not already in `PATH`, the installation succeeds and prints `Required action: update-path` with the exact `PATH` configuration to apply before rerunning the verifier.

The installer succeeds after installation and verification, including when it reports the `update-path` action. Any nonzero installer result is a failure.

## Test the setup tool

Run the setup tool's test suite with:

```bash
make test-setup-foundry
```

The test harness additionally requires `jq`; the setup tool itself does not.
