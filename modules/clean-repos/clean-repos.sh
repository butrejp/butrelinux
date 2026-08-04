#!/usr/bin/env bash
set -euo pipefail

echo "=== Processing EL10 Repositories ==="

# 1. Define allowed repository IDs
ALLOWED_REPOS=("appstream" "baseos" "crb" "epel" "extras-common")

# 2. Safely extract unique, valid repo IDs directly from file definitions
# This bypasses DNF entirely to look at what is physically on disk
ACTIVE_REPOS=$(grep -h "^\[.*\]" /etc/yum.repos.d/*.repo 2>/dev/null | tr -d '[]' | sort -u)

# 3. Handle duplicates or unallowed repos by physically stripping them
for repo in $ACTIVE_REPOS; do
    [ -z "$repo" ] && continue
    
    # If the repo ID is not in our allowlist, remove its definition entirely
    if [[ ! " ${ALLOWED_REPOS[@]} " =~ " ${repo} " ]]; then
        echo "Physically purging unallowed/duplicate repository configuration: $repo"
        
        # Use sed to delete the specific repository block from all files
        # It matches from the [repo] header to the next empty line or next header
        sed -i "/^\[${repo}\]/,/^$/d" /etc/yum.repos.d/*.repo 2>/dev/null || true
    else
        echo "Keeping allowed repository: $repo"
    fi
done

dnf clean all
