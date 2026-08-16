#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="${1:-${HOME}/bin/repos.json}"
STATE_DIR="${HOME}/.cache/github-release-tracker"

mkdir -p "$STATE_DIR"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

jq -c '.[]' "$CONFIG_FILE" | while read -r entry; do
   
    REPO=$(jq -r '.repo' <<< "$entry")
    ASSET=$(jq -r '.asset' <<< "$entry")
    DEST=$(jq -r '.destination' <<< "$entry")
    RENAME=$(jq -r '.rename' <<< "$entry")
    echo
    echo "=== Checking ${REPO} ==="

    # Try latest stable release first
    RELEASE_JSON=$(curl -fsSL \
        "https://api.github.com/repos/${REPO}/releases/latest" \
        2>/dev/null || true)

    # Fall back to latest release/prerelease
    if [[ -z "$RELEASE_JSON" ]]; then
        echo "No stable release found, using newest release/prerelease"

        RELEASE_JSON=$(
            curl -fsSL \
            "https://api.github.com/repos/${REPO}/releases" |
            jq '.[0]'
        )
    fi

    TAG=$(jq -r '.tag_name // empty' <<< "$RELEASE_JSON")

    if [[ -z "$TAG" ]]; then
        echo "Could not determine release tag"
        continue
    fi

    STATE_FILE="${STATE_DIR}/$(echo "$REPO" | tr '/' '_').version"

    PREVIOUS_TAG=""
    if [[ -f "$STATE_FILE" ]]; then
        PREVIOUS_TAG=$(cat "$STATE_FILE")
    fi

    if [[ "$TAG" == "$PREVIOUS_TAG" ]]; then
        echo "Already up to date (${TAG})"
        continue
    fi

    DOWNLOAD_URL=$(
        jq -r \
            --arg asset "$ASSET" '
                .assets[]
                | select(.name == $asset)
                | .browser_download_url
            ' <<< "$RELEASE_JSON"
    )

    if [[ -z "$DOWNLOAD_URL" ]]; then
        echo "Asset not found: ${ASSET}"
        continue
    fi

    mkdir -p "$DEST"

    echo "Downloading ${ASSET}"
    echo "Release: ${TAG}"
    DOWNLOAD_FILE=${ASSET}
    if [[ ! -z "$RENAME" ]]; then
        DOWNLOAD_FILE=$RENAME
    fi
    
    curl -fL \
        -o "${DEST}/${DOWNLOAD_FILE}" \
        "$DOWNLOAD_URL"

    echo "$TAG" > "$STATE_FILE"
    echo "Updated ${ASSET} -> ${TAG}"
    MESSAGE="Updated ${ASSET} -> ${TAG}"
    notify-send \
      "Archipelago Update" \
      "$MESSAGE" \
      --icon=software-update-available
done
