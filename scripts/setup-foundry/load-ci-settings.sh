#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ] || [ -z "${GITHUB_ENV:-}" ]; then
    printf 'Usage: GITHUB_ENV=path bash %s path/to/tests.yaml\n' "$0" >&2
    exit 1
fi

settings=$(awk '
    /^env:$/ { env_count++; in_env = 1; next }
    in_env && /^[^[:space:]#]/ { in_env = 0 }
    in_env && /^  FOUNDRY_RELEASE:/ {
        release_count++
        if ($0 !~ /^  FOUNDRY_RELEASE: v[0-9]+\.[0-9]+\.[0-9]+$/) invalid = 1
        sub(/^  FOUNDRY_RELEASE: /, "")
        release = $0
    }
    in_env && /^  FOUNDRY_IGNORE_AGE:/ {
        age_count++
        if ($0 !~ /^  FOUNDRY_IGNORE_AGE: "[01]"$/) invalid = 1
        sub(/^  FOUNDRY_IGNORE_AGE: "/, "")
        sub(/"$/, "")
        age = $0
    }
    END {
        if (env_count != 1 || release_count != 1 || age_count != 1 || invalid) exit 1
        print "FOUNDRY_RELEASE=" release
        print "FOUNDRY_IGNORE_AGE=" age
    }
' "$1") || {
    printf 'Invalid workflow-level Foundry settings in %s\n' "$1" >&2
    exit 1
}

printf '%s\n' "$settings" >> "$GITHUB_ENV"
