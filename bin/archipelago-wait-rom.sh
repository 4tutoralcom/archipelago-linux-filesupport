#!/usr/bin/env bash

FILE="$1"
SCRIPT_DIR=$(readlink -f "${HOME}/bin/pack_scripts")

echo "${SCRIPT_DIR}"
# Start Archipelago (server or generator)
APP=$(readlink -f "${HOME}/AppImages/archipelago.appimage")
echo "Starting Archipelago..."
if [ -z "$FILE" ]; then
  env DESKTOPINTEGRATION=1 "${APP}"
  sleep infinity
  exit
fi
extension="${FILE##*.}"
ADITIONAL_SCRIPT="${SCRIPT_DIR}/${extension}.sh"
echo "$ADITIONAL_SCRIPT"
if [ -f "${SCRIPT_DIR}/${extension}.sh" ]; then
  "$ADITIONAL_SCRIPT"
fi

# Run and capture output
env DESKTOPINTEGRATION=1 "$APP" "$FILE" 2>&1 | while IFS= read -r line; do

echo "$line"

  # Detect ROM write line
  if echo "$line" | grep -q "wrote rom file to"; then
    ROM_PATH=$(echo "$line" | sed -n 's/.*wrote rom file to //p')
    
    # Clean quotes if any
    ROM_PATH=$(echo "$ROM_PATH" | tr -d '\r"')

    echo ""
    echo "ROM detected: $ROM_PATH"
    echo "Launching ROM..."

    if [ "${extension}" = "apfirered" ]; then
      "${HOME}/Applications/BizHawk-2.11.1-linux-x64/EmuHawkMono.sh" "${ROM_PATH}" --lua= "${HOME}/.local/share/Archipelago/data/lua/connector_bizhawk_generic.lua"
    else
      xdg-open "$ROM_PATH"
    fi

  fi

done