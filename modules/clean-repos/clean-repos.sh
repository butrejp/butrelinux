#!/usr/bin/env bash
set -euo pipefail

# 1. Define your allowed/used repository IDs (Space-separated)
# Any repository NOT in this list will be forcefully disabled.
ALLOWED_REPOS=("appstream" "baseos" "crb" "epel" "extras-common")

echo "=== Processing EL10 Repositories ==="

# 2. Extract all currently active repository IDs using dnf
ACTIVE_REPOS=$(dnf repolist -q | awk 'NR>1 {print $1}')

# 3. Loop through discovered repos and disable unlisted ones
for repo in $ACTIVE_REPOS; do
    # Skip checking if empty
    [ -z "$repo" ] && continue
    
    # Check if the repo is in our allowlist
    if [[ ! " ${ALLOWED_REPOS[@]} " =~ " ${repo} " ]]; then
        echo "Disabling unused upstream repository: $repo"
        dnf config-manager --set-disabled "$repo" -y
    else
        echo "Keeping allowed repository: $repo"
    fi
done

# 4. Flush the metadata cache so subsequent modules don't pull from disabled repos
dnf autoremove -y
dnf clean all
