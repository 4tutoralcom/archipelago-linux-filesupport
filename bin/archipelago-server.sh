#!/usr/bin/env bash

FILE="$1"
FILE="${1#\'}"
FILE="${FILE%\'}"

if [ -z "$FILE" ]; then
    echo "No .archipelago file provided"
    exit 1
fi

"${HOME}/AppImages/archipelago.appimage" "$FILE"
