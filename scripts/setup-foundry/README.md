# Verified Foundry setup

## Why this exists

[Foundry's standard installation procedure](https://getfoundry.sh/getting-started/installation) bootstraps `foundryup` by piping a remotely hosted script directly into Bash:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

The executed script is not pinned to this repository or reviewable as part of its history. Running `foundryup` then installs the release currently labeled stable without the release-age and provenance safeguards introduced by this setup tool.

Foundry is part of the toolchain used to build, test, and deploy executive spells. This repository therefore keeps its installation and verification logic under source control instead of relying on the remote bootstrap script.

This script provides one auditable process for selecting, installing, and verifying Foundry. The selector chooses the newest release that:

- uses an exact stable tag in the form `vMAJOR.MINOR.PATCH`;
- is neither a draft nor a prerelease;
- is immutable;
- was published at least 14 days ago; and
- publishes the four supported Linux and macOS archives with SHA-256 digests and SLSA provenance attestations.

Selection checks archive and attestation availability through GitHub metadata without downloading an artifact. This is a preflight, not cryptographic verification: the installer still verifies the downloaded archive and the extracted binaries before installation succeeds.

Before reporting its source commit and CLI SHA-256, the tool confirms that the executed setup script has the same bytes as that file in the reported commit. A locally modified or untracked copy is rejected; unrelated working-tree changes do not block the tool.

After the selected release has been reviewed and installed, the verifier checks that the `forge`, `cast`, `anvil`, and `chisel` binaries resolved from `PATH` were produced by Foundry's official release workflow and all come from that exact release. If the installed binaries do not match, it reports the exact installation command.

The installer requires an explicit release and installs only that exact version. Developer Foundry binaries installed by another method are not trusted, even when they match the requested release, so the installer always replaces the four binaries in `~/.foundry/bin`. Because installation processes a release archive, it requires the archive itself to be attested before extraction. It then verifies the four installed binaries before executing them. If an installation fails after modifying the destination, it restores the previous binaries.

The selected version can change as newer releases satisfy the policy. Verification therefore requires the exact version accepted after reviewing the selector output.

The 14-day cooling period follows the current executive spell cadence. It provides time for public detection and response, but it is not a guarantee that every upstream compromise will be discovered within that period.

## Security model and limitations

GitHub attestations establish that an artifact was produced by the expected repository workflow. They prevent an externally built binary without that provenance from passing verification, but they do not establish that Foundry's source code, dependencies, release workflow, or GitHub account were uncompromised when the artifact was built.

[Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) prevent a published release's tag and assets from being modified or replaced in place. GitHub permits maintainers to delete the entire release, but the immutable release's tag name cannot be reused after deletion. A compromised immutable release therefore cannot be replaced by different binaries under the same version tag.

If Foundry deletes a malicious release, the selector will no longer choose it, explicit installation will fail because the release metadata is unavailable, and verification of an installed copy will also fail. If Foundry leaves the release published, however, the selector can continue choosing it once it satisfies the age policy, and exact verification can continue accepting it. Publishing a clean newer release does not immediately revoke the malicious release; without an approved age waiver, the newer release becomes eligible only after completing its own 14-day cooling period.

This tool does not maintain a repository-local revocation list or an allowlist of approved Foundry releases. It therefore depends on upstream deletion, or a subsequent change to this repository, to reject a known-malicious release immediately.

Selection, installation, and verification depend on GitHub for release metadata, assets, authentication, and attestations. They fail closed when the required GitHub service is unavailable. This is a development and deployment tooling dependency; it does not add a GitHub dependency to deployed spells.

## Exact releases and urgent age waivers

Select the newest immutable stable release that satisfies the normal 14-day cooling period and archive preflight:

```bash
make select-foundry
```

Verification and installation require `release=vMAJOR.MINOR.PATCH` and enforce the same cooling period:

```bash
make verify-foundry release=vMAJOR.MINOR.PATCH
make install-foundry release=vMAJOR.MINOR.PATCH
```

To select the newest immutable stable release without the cooling-period filter, use:

```bash
make select-foundry ignore-age=1
```

For an approved exact release that is less than 14 days old, add `ignore-age=1` when verifying or installing it:

```bash
make verify-foundry release=vMAJOR.MINOR.PATCH ignore-age=1
make install-foundry release=vMAJOR.MINOR.PATCH ignore-age=1
```

The Make `ignore-age` setting defaults to `0` when omitted, accepts only `0` or `1`, and passes `--ignore-age` only for `1`. The corresponding script options are `--release` and `--ignore-age`. They are parsed directly by Bash and do not require GNU `getopt`, including on macOS. The selector does not accept `--release`; verification and installation require it. `--ignore-age` waives only the cooling period. The release must still use an exact stable tag, exist as an immutable release, and satisfy every applicable metadata, archive-preflight, or attestation-verification check. Record the upstream security advisory or incident reference, the spell-team approval, and the complete selector, installer, and verifier output.

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

CI environments are expected to be clean, with no previous Foundry installation. The setup tool requires an authenticated GitHub CLI, and subsequent steps must resolve the installed binaries from `PATH`. Define the pinned release and age-waiver setting at workflow level:

```yaml
env:
  FOUNDRY_RELEASE: vMAJOR.MINOR.PATCH
  FOUNDRY_IGNORE_AGE: "0"
```

Expose the workflow token as `GH_TOKEN` and add the installation directory to `GITHUB_PATH` before installing:

```yaml
- name: Add Foundry to PATH
  run: echo "${HOME}/.foundry/bin" >> "${GITHUB_PATH}"

- name: Install Foundry
  run: make install-foundry release="${FOUNDRY_RELEASE}" ignore-age="${FOUNDRY_IGNORE_AGE}"
  env:
    GH_TOKEN: ${{ github.token }}

- name: Verify Foundry
  run: make verify-foundry release="${FOUNDRY_RELEASE}" ignore-age="${FOUNDRY_IGNORE_AGE}"
  env:
    GH_TOKEN: ${{ github.token }}
```

Keep `FOUNDRY_IGNORE_AGE` set to `"0"` to enforce the 14-day cooling period. Set it to `"1"` only when the pinned release has an approved cooling-period waiver. Any other value fails before the setup script runs.

## Developer machine setup

Engineers will usually already have Foundry installed. Select and report the desired installable release without resolving or invoking those binaries:

```bash
make select-foundry
```

Review the reported release, then install that exact release:

```bash
make install-foundry release=vMAJOR.MINOR.PATCH
```

The installer always replaces `forge`, `cast`, `anvil`, and `chisel` in `~/.foundry/bin`; it does not attest or execute the pre-existing destination binaries. It first attests the release archive, then extracts and installs the replacements transactionally, attests the four installed binaries, and executes their version commands. Any nonzero installer result is a failure.

If the installer prints `Required action: update-path`, apply the printed `PATH` configuration and start a new shell.

Regardless of whether a `PATH` update was required, verify the same exact release:

```bash
make verify-foundry release=vMAJOR.MINOR.PATCH
```

The verifier succeeds when the installed release is valid. Any nonzero result is a failure and must be diagnosed.

## Installation and verification behavior

Verification and installation intentionally have different artifact boundaries. `verify-foundry` validates the installed binaries and can succeed for a release that `install-foundry` cannot install. `install-foundry` must process the upstream archive, so it requires both the archive attestation and the binary attestations.

A release can have attested binaries while one or more supported archives lack a published digest or attestation. The selector skips such releases. Its API preflight establishes availability only; the installer remains responsible for cryptographically verifying the downloaded archive's digest, signer, source, subject, and release tag.

The selector examines metadata-eligible releases from newest to oldest and chooses the first whose `linux_amd64`, `linux_arm64`, `darwin_amd64`, and `darwin_arm64` archives publish valid SHA-256 digests and at least one SLSA provenance attestation record. It does not download artifacts or resolve, attest, or invoke installed Foundry binaries. Without `ignore-age=1`, it considers immutable stable releases published at least 14 days ago. With `ignore-age=1`, it also considers younger immutable stable releases.

The verifier and installer require a release parameter, validate only that exact release, and enforce the same age requirement. For these commands, `ignore-age=1` accompanies the exact release and waives only that age requirement.

The installer does not trust, attest, or execute pre-existing binaries in `~/.foundry/bin`. After validating the exact release metadata, it always downloads and attests the release archive, backs up any existing destination binaries for rollback, installs all four replacements, attests the installed replacements, and only then executes their version commands.

The installer places the verified binaries in `~/.foundry/bin`. If that directory is not already in `PATH`, installation succeeds and prints `Required action: update-path` with the exact `PATH` configuration to apply before rerunning the verifier.

The installer succeeds after installation and verification, including when it reports the `update-path` action. Any nonzero installer result is a failure.

## Test the setup tool

Run the setup tool's test suite with:

```bash
make test-setup-foundry
```

The test harness additionally requires `jq`; the setup tool itself does not.
