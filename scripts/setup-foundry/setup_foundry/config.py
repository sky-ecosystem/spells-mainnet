GITHUB_HOST = "github.com"
REPOSITORY = "foundry-rs/foundry"
QUALIFIED_REPOSITORY = f"{GITHUB_HOST}/{REPOSITORY}"
SIGNER_WORKFLOW = f"{REPOSITORY}/.github/workflows/release.yml"
SIGNER_PREFIX = f"https://{GITHUB_HOST}/{SIGNER_WORKFLOW}@refs/tags/"
SOURCE_REPOSITORY = f"https://{GITHUB_HOST}/{REPOSITORY}"
MINIMUM_RELEASE_AGE_SECONDS = 604800
BINARIES = ("forge", "cast", "anvil", "chisel")
