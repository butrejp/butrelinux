#!/usr/bin/env bash
set -euo pipefail

echo "=== Processing EL10 Repositories ==="

# 1. Define allowed repository IDs
ALLOWED_REPOS=("appstream" "baseos" "crb" "epel" "extras-common")

# 2. Safely extract unique, valid repo IDs directly from file definitions
# This bypasses DNF entirely to look at what is physically on disk
ACTIVE_REPOS=$(grep -h "^\[.*\]" /etc/yum.repos.d/*.repo 2>/dev/null | tr -d '[]' | sort -u)

# 3. Handle unallowed repositories by physically stripping their definitions
for repo in $ACTIVE_REPOS; do
    [ -z "$repo" ] && continue

    # Check whether the repository is in the allowlist.
    # Spaces around each entry prevent partial matches.
    case " ${ALLOWED_REPOS[*]} " in
        *" $repo "*)
            echo "Keeping allowed repository: $repo"
            ;;
        *)
            echo "Physically purging unallowed/duplicate repository configuration: $repo"

            # Delete the repository block from all repo files.
            # Matches from the [repo] header through the next blank line.
            sed -i "/^\[${repo}\]/,/^$/d" /etc/yum.repos.d/*.repo 2>/dev/null || true
            ;;
    esac
done

dnf clean all