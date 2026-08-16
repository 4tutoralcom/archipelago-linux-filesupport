#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="${1:-${HOME}/bin/repos.json}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/github-releases"

get_github_release() {
    local REPO="$1"
    local CACHE_FILE="${CACHE_DIR}/${REPO//\//_}.json"
    local CACHE_MAX_AGE=3600

    mkdir -p "$CACHE_DIR"

    # Use cached release information if it is still fresh
    if [[ -f "$CACHE_FILE" ]] && \
       (( $(date +%s) - $(stat -c %Y "$CACHE_FILE") < CACHE_MAX_AGE )); then
        cat "$CACHE_FILE"
        return 0
    fi

    echo "Fetching release information for ${REPO}..." >&2

    # Build curl authentication arguments.
    # Only send Authorization if GITHUB_TOKEN is set.
    local CURL_AUTH=()

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        CURL_AUTH+=(
            -H "Authorization: Bearer ${GITHUB_TOKEN}"
        )
    fi

    local CURL_COMMON_ARGS=(
        -fsSL
        "${CURL_AUTH[@]}"
        -H "Accept: application/vnd.github+json"
        -H "X-GitHub-Api-Version: 2026-03-10"
    )

    local NEW_RELEASE_JSON=""

    # Try latest stable release first
    NEW_RELEASE_JSON=$(
        curl "${CURL_COMMON_ARGS[@]}" \
            "https://api.github.com/repos/${REPO}/releases/latest" \
            2>/dev/null
    ) || NEW_RELEASE_JSON=""

    # Fall back to newest release/prerelease
    if [[ -z "$NEW_RELEASE_JSON" ]]; then
        echo "No stable release found, using newest release/prerelease" >&2

        NEW_RELEASE_JSON=$(
            curl "${CURL_COMMON_ARGS[@]}" \
                "https://api.github.com/repos/${REPO}/releases" \
                2>/dev/null |
            jq '.[0]' 2>/dev/null
        ) || NEW_RELEASE_JSON=""

        # jq returns "null" when there are no releases
        if [[ "$NEW_RELEASE_JSON" == "null" ]]; then
            NEW_RELEASE_JSON=""
        fi
    fi

    # GitHub succeeded -- update cache and return it
    if [[ -n "$NEW_RELEASE_JSON" ]]; then
        local TMP_CACHE="${CACHE_FILE}.tmp"

        printf '%s\n' "$NEW_RELEASE_JSON" > "$TMP_CACHE"
        mv "$TMP_CACHE" "$CACHE_FILE"

        printf '%s\n' "$NEW_RELEASE_JSON"
        return 0
    fi

    # GitHub failed -- use stale cache if available
    if [[ -f "$CACHE_FILE" ]]; then
        echo "GitHub request failed, using cached release information." >&2
        cat "$CACHE_FILE"
        return 0
    fi

    echo "Failed to retrieve GitHub release information for ${REPO} and no cache exists." >&2
    return 1
}


mkdir -p "$CACHE_DIR"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

jq -c '.[]' "$CONFIG_FILE" | while read -r entry; do
   
    REPO=$(jq -r '.repo' <<< "$entry")
    ASSET=$(jq -r '.asset' <<< "$entry")
    DEST=$(jq -r '.destination' <<< "$entry" | envsubst ) 
    RENAME=$(jq -r '.rename' <<< "$entry")
    echo
    echo "=== Checking ${REPO} ==="

    RELEASE_JSON=$(get_github_release "$REPO") || exit 1

    TAG=$(jq -r '.tag_name // empty' <<< "$RELEASE_JSON")

    if [[ -z "$TAG" ]]; then
        echo "Could not determine release tag"
        continue
    fi

    STATE_FILE="${CACHE_DIR}/$(echo "$REPO" | tr '/' '_').version"

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


    if [[ -z "$DOWNLOAD_URL"] && ["$asset" == "Source code" ]]; then
        DOWNLOAD_URL=$(echo $RELEASE_JSON | jq -r .zipball_url)
    fi
    echo $DOWNLOAD_URL
    if [[ -z "$DOWNLOAD_URL" ]]; then
        jq -r '.assets[].name'<<< "$RELEASE_JSON"
        echo "Asset not found: ${ASSET}"
        continue
    fi
    echo $DEST
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
    echo "Saved ${DEST}/${DOWNLOAD_FILE} to $DOWNLOAD_URL"
    echo "$TAG" > "$STATE_FILE"
    echo "Updated ${ASSET} -> ${TAG}"
    MESSAGE="Updated ${ASSET} -> ${TAG}"
    notify-send \
      "Archipelago Update" \
      "$MESSAGE" \
      --icon=software-update-available
done
