# Installer Script Comment Design

## Communication situation

- **Audience:** Spell crafters, reviewers, and maintainers reading `scripts/install-foundry.sh`, including readers who understand shell but have not reconstructed its security model.
- **Purpose:** Make the installer's policy, trust boundaries, recovery behavior, evidence output, and exit contract understandable before readers inspect individual commands.
- **Setting:** A security-sensitive repository script that downloads and executes developer tooling on Linux and macOS.
- **Document:** Short Bash comments embedded in the script. They must remain scannable and must not duplicate obvious syntax.
- **Process:** Add comments only, then verify that executable content and behavior are unchanged.

## Design

Add one compact header after the shebang. It will state that the script installs an age-eligible stable Foundry release, pins GitHub and the official Foundry release workflow as trust roots, verifies artifacts before execution, restores the previous installation on failure, and uses exit status `2` only for successful installation with incomplete PATH setup.

Add five short section comments before:

1. Dependency and platform validation.
2. Seven-day stable-release selection.
3. Temporary-state and rollback handling.
4. Download, archive verification, installation, and installed-binary verification.
5. Evidence reporting and PATH result handling.

Comments will explain intent and ordering constraints. They will not narrate assignments, loops, or commands whose purpose is already evident from their names.

## Non-goals

- No executable behavior changes.
- No new options, dependencies, or output.
- No README or checklist changes.
- No detailed shell tutorial.

## Acceptance criteria

- A reader can identify the release policy, trust roots, verification order, rollback guarantee, evidence output, and exit-code meanings from comments alone.
- Existing stub tests, `bash -n`, and `git diff --check` pass.
- A whitespace-insensitive comparison confirms that all non-comment shell content is unchanged.
