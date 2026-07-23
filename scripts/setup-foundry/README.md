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
- was published at least 14 days ago.

The verifier checks that the installed `forge`, `cast`, `anvil`, and `chisel` binaries were produced by Foundry's official release workflow and all come from the desired release. If the installed binaries do not match, it reports the exact release and installation command.

Without an explicit release, the installer selects the same newest age-eligible release as the verifier; with a release parameter, it installs only that exact release. Because installation processes a release archive, it additionally requires the archive itself to be attested before extraction. It then verifies the four installed binaries before executing them. If an installation fails after modifying the destination, it restores the previous binaries.

The selected version can change as newer releases satisfy the policy; the verifier enforces the policy rather than permanently pinning one Foundry version.

The 14-day cooling period follows the current executive spell cadence. It provides time for public detection and response, but it is not a guarantee that every upstream compromise will be discovered within that period.

## Security model and limitations

GitHub attestations establish that an artifact was produced by the expected repository workflow. They prevent an externally built binary without that provenance from passing verification, but they do not establish that Foundry's source code, dependencies, release workflow, or GitHub account were uncompromised when the artifact was built.

[Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) prevent a published release's tag and assets from being modified or replaced in place. GitHub permits maintainers to delete the entire release, but the immutable release's tag name cannot be reused after deletion. A compromised immutable release therefore cannot be replaced by different binaries under the same version tag.

If Foundry deletes a malicious release, the verifier will no longer select it, explicit installation will fail because the release metadata is unavailable, and verification of an installed copy will also fail. If Foundry leaves the release published, however, the verifier can continue accepting it once it satisfies the age policy. Publishing a clean newer release does not immediately revoke the malicious release; without an approved age waiver, the newer release becomes eligible only after completing its own 14-day cooling period.

This tool does not maintain a repository-local revocation list or an allowlist of approved Foundry releases. It therefore depends on upstream deletion, or a subsequent change to this repository, to reject a known-malicious release immediately.

## Exact releases and urgent age waivers

Use `release=vMAJOR.MINOR.PATCH` to verify or install an exact immutable stable release while enforcing the normal 14-day cooling period:

```bash
make verify-foundry release=vMAJOR.MINOR.PATCH
make install-foundry release=vMAJOR.MINOR.PATCH
```

For an approved urgent release that is less than 14 days old, add `ignore-age=1`:

```bash
make verify-foundry release=vMAJOR.MINOR.PATCH ignore-age=1
make install-foundry release=vMAJOR.MINOR.PATCH ignore-age=1
```

The corresponding script options are `--release` and `--ignore-age`. They are parsed directly by Bash and do not require GNU `getopt`, including on macOS. `--ignore-age` requires an explicit release and waives only the cooling period. The release must still use an exact stable tag, exist as an immutable release, and satisfy every applicable archive and binary attestation check. Record the upstream security advisory or incident reference, the spell-team approval, and the complete installer and verifier output.

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

Display the built-in command reference without performing environment or network checks:

```bash
./scripts/setup-foundry/setup-foundry.sh --help
```

## CI installation

CI environments are expected to be clean, with no previous Foundry installation. The setup tool requires an authenticated GitHub CLI, and subsequent steps must resolve the installed binaries from `PATH`. In GitHub Actions, expose the workflow token as `GH_TOKEN` and add the installation directory to `GITHUB_PATH` before installing:

```yaml
- name: Add Foundry to PATH
  run: echo "${HOME}/.foundry/bin" >> "${GITHUB_PATH}"

- name: Install Foundry
  run: make install-foundry
  env:
    GH_TOKEN: ${{ github.token }}

- name: Verify Foundry
  run: make verify-foundry
  env:
    GH_TOKEN: ${{ github.token }}
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

The printed command identifies the desired release but does not guarantee that its release archive satisfies the installer's additional attestation requirement. Crafter and reviewer workflows must require all three fields before installing; any other failure must be diagnosed without automatically installing.

## Installation and verification behavior

Verification and installation intentionally have different artifact boundaries. `verify-foundry` validates the installed binaries and can succeed for a release that `install-foundry` cannot install. `install-foundry` must process the upstream archive, so it requires both the archive attestation and the binary attestations.

Foundry v1.7.0 is one example: its four binaries are attested, but its release archive is not. An existing v1.7.0 installation can therefore pass `make verify-foundry release=v1.7.0`, while `make install-foundry release=v1.7.0` fails before extraction. This is expected behavior; selecting an exact release does not weaken either attestation boundary.

Without a release parameter, the verifier and installer select the newest immutable stable release published at least 14 days ago. With a release parameter, they validate only that exact release and enforce the same age requirement. `ignore-age=1` requires an explicit release and waives only that age requirement.

Before downloading an archive, the installer checks `~/.foundry/bin`. It skips installation only when `forge`, `cast`, `anvil`, and `chisel` are executable files whose attestations all match the desired release, the release metadata remains valid, and every version command succeeds. Existing binaries are executed only after their attestations match. If any check fails, the normal transactional installation proceeds.

The installer places the verified binaries in `~/.foundry/bin`. If that directory is not already in `PATH`, either installation path succeeds and prints `Required action: update-path` with the exact `PATH` configuration to apply before rerunning the verifier.

The installer succeeds after installation and verification, including when it reports the `update-path` action. Any nonzero installer result is a failure.

## Test the setup tool

Run the setup tool's test suite with:

```bash
make test-setup-foundry
```

The test harness additionally requires `jq`; the setup tool itself does not.
