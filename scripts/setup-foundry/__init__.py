"""Install and verify Foundry against repository-defined trust policy.

GitHub.com and foundry-rs/foundry/.github/workflows/release.yml are the pinned
trust roots. The tooling selects the newest non-draft, non-prerelease release
that is at least seven days old, then verifies provenance before trusting any
downloaded or installed executable.
"""
