#!/usr/bin/env bash

set -euo pipefail

RELEASEVER=$(jq -r 'try .["releasever"] // empty' <<< "$1")

if [[ -z "${RELEASEVER}" ]]; then
    echo "Error: releasever is required"
    exit 1
fi

get_json_array REPOS 'try .["repos"][]' "$1"

if [[ ${#REPOS[@]} -gt 0 ]]; then
    echo "Adding repositories"

    for REPO in "${REPOS[@]}"; do
        REPO="${REPO//%RELEASEVER%/${RELEASEVER}}"
        REPO="${REPO//[$'\t\r\n ']}"

        REPO_FILE="/etc/yum.repos.d/$(basename "${REPO}")"

        echo "Downloading repo file ${REPO}"

        curl -fLsS --retry 5 \
            "${REPO}" \
            -o "${REPO_FILE}"

        # Replace Fedora release placeholders only in this repo.
        # Do not change the system-wide DNF releasever because this
        # image is based on EL and has EL repositories enabled.
        sed -i \
            "s/\$releasever/${RELEASEVER}/g" \
            "${REPO_FILE}"

        echo "Downloaded repo file ${REPO_FILE}"
    done
fi

get_json_array KEYS 'try .["keys"][]' "$1"

if [[ ${#KEYS[@]} -gt 0 ]]; then
    echo "Importing keys"

    for KEY in "${KEYS[@]}"; do
        KEY="${KEY//%RELEASEVER%/${RELEASEVER}}"
        KEY="${KEY//[$'\t\r\n ']}"

        rpm --import "${KEY}"
    done
fi

get_json_array INSTALL_PKGS 'try .["install"][]' "$1"

if [[ ${#INSTALL_PKGS[@]} -gt 0 ]]; then
    echo "Installing Fedora RPMs:"
    echo "${INSTALL_PKGS[*]}"

    dnf install -y "${INSTALL_PKGS[@]}"
fi

dnf clean all