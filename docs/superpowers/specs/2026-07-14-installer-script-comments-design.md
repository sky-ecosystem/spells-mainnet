# Installer Script Comment Design

## Communication situation

- **Audience:** Spell crafters, reviewers, and maintainers reading `scripts/install-foundry.sh`, including readers who understand shell but have not reconstructed its security model.
- **Purpose:** Make the installer's policy, trust boundaries, recovery behavior, evidence output, and exit contract understandable before readers inspect individual commands.
- **Setting:** A security-sensitive repository script that downloads and executes developer tooling on Linux and macOS.
- **Document:** Short Bash comments embedded in the script. They must remain scannable and must not duplicate obvious syntax.
- **Process:** Add comments only, then verify that executable content and behavior are unchanged.

## Design

Add one compact header after the shebang. It will state that the script installs an age-eligible stable Foundry release, pins GitHub and the official Foundry release workflow as trust roots, verifies artifacts before execution, restores the previous installation when a failure occurs after destination mutation begins, and reserves its explicit `exit 2` for successful installation with incomplete PATH setup.

Add five short section comments at these anchors:

1. Before the required-command loop: dependency, authentication, and supported-platform validation.
2. Before `LATEST_RECORD`: seven-day stable-release selection.
3. Before `TEMP_DIR`: temporary-state cleanup and rollback after destination mutation begins.
4. Before the first release-detail `printf`: early provenance reporting, archive verification before extraction, and installed-binary verification before execution.
5. Before `Evidence summary`: consolidated evidence reporting and the script's explicit PATH-related `exit 2`.

Comments will explain intent and ordering constraints. They will not narrate assignments, loops, or commands whose purpose is already evident from their names.

## Non-goals

- No executable behavior changes.
- No new options, dependencies, or output.
- No README or checklist changes.
- No detailed shell tutorial.

## Acceptance criteria

- A reader can identify the release policy, trust roots, verification order, rollback boundary, evidence output, and the meaning of the script's explicit PATH-related `exit 2` from comments alone.
- Existing stub tests, `bash -n`, and `git diff --check` pass.
- A whitespace-insensitive comparison confirms that all non-comment shell content is unchanged.
