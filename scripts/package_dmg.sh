#!/bin/bash
# ==============================================================================
# PhantomKnob - Branded DMG Packaging Script
# ==============================================================================
set -euo pipefail

APP_NAME="PhantomKnob"
VOLUME_NAME="${APP_NAME}"
SRC_APP="${1:-build/Exported/PhantomKnob.app}"
OUT_DMG="${2:-dist/PhantomKnob.dmg}"

SCRIPTS_DIR="$(dirname "$0")"
BUILD_DIR="$(pwd)/build"
TEMP_DMG_PATH="${BUILD_DIR}/temp_pack.dmg"
MOUNT_DIR="${BUILD_DIR}/mount_dmg"

# Check source app
if [ ! -d "${SRC_APP}" ]; then
    echo "[ERROR] Source App not found at: ${SRC_APP}" >&2
    exit 1
fi

# Clean old outputs
rm -f "${OUT_DMG}" "${TEMP_DMG_PATH}"

echo "[INFO] Generating branded background image..."
BACKGROUND_PNG="${BUILD_DIR}/dmg_background.png"
swift "${SCRIPTS_DIR}/generate_dmg_background.swift" "${BACKGROUND_PNG}"

echo "[INFO] Creating temporary writeable DMG..."
# Allocate 60MB for the temporary writable DMG
hdiutil create -size 60m -fs HFS+ -volname "${VOLUME_NAME}" "${TEMP_DMG_PATH}"

echo "[INFO] Mounting temporary DMG..."
hdiutil detach "/Volumes/${VOLUME_NAME}" -force 2>/dev/null || true
hdiutil attach "${TEMP_DMG_PATH}"
MOUNT_DIR="/Volumes/${VOLUME_NAME}"

echo "[INFO] Copying Application and creating Applications symlink..."
cp -R "${SRC_APP}" "${MOUNT_DIR}/"
ln -s /Applications "${MOUNT_DIR}/Applications"

echo "[INFO] Copying background image..."
mkdir -p "${MOUNT_DIR}/.background"
cp "${BACKGROUND_PNG}" "${MOUNT_DIR}/.background/background.png"

echo "[INFO] Applying Finder visual styling via AppleScript..."
set +e
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 600, 430}
        set theViewOptions to icon view options of container window
        set label position of theViewOptions to bottom
        set icon size of theViewOptions to 72
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Align icons to custom coordinate positions on background
        set position of item "${APP_NAME}.app" of container window to {150, 160}
        set position of item "Applications" of container window to {350, 160}
        
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF
APPLESCRIPT_STATUS=$?
set -e

if [ $APPLESCRIPT_STATUS -ne 0 ]; then
    echo "[WARNING] Finder customization script returned non-zero status. Proceeding with standard DMG layout."
fi

echo "[INFO] Detaching volume..."
hdiutil detach "${MOUNT_DIR}"

echo "[INFO] Converting temporary DMG to final read-only compressed format (UDZO)..."
mkdir -p "$(dirname "${OUT_DMG}")"
hdiutil convert "${TEMP_DMG_PATH}" -format UDZO -imagekey zlib-level=9 -o "${OUT_DMG}"

# Clean up temp files
rm -f "${TEMP_DMG_PATH}" "${BACKGROUND_PNG}"

echo "[INFO] Branded DMG created successfully at: ${OUT_DMG}"
