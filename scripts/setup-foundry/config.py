"""Repository-defined Foundry release and attestation policy."""

GITHUB_HOST = "github.com"
REPOSITORY = "foundry-rs/foundry"
QUALIFIED_REPOSITORY = f"{GITHUB_HOST}/{REPOSITORY}"
SIGNER_WORKFLOW = f"{REPOSITORY}/.github/workflows/release.yml"
SIGNER_PREFIX = f"https://{GITHUB_HOST}/{SIGNER_WORKFLOW}@refs/tags/"
SOURCE_REPOSITORY = f"https://{GITHUB_HOST}/{REPOSITORY}"
MINIMUM_RELEASE_AGE_SECONDS = 1209600
MINIMUM_RELEASE_AGE_DAYS = MINIMUM_RELEASE_AGE_SECONDS // 86400
BINARIES = ("forge", "cast", "anvil", "chisel")
SUPPORTED_ARCHIVE_TARGETS = (
    "linux_amd64",
    "linux_arm64",
    "darwin_amd64",
    "darwin_arm64",
)
