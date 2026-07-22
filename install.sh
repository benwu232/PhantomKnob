#!/bin/bash
# ==============================================================================
# PhantomKnob - One-Click Installer Script for macOS
# Automatically downloads latest release, installs to /Applications, and bypasses Gatekeeper quarantine.
# ==============================================================================
set -euo pipefail

echo -e "\033[1;34m==>\033[0m Installing PhantomKnob..."

DOWNLOAD_URL=$(curl -s https://api.github.com/repos/benwu232/PhantomKnob/releases/latest | grep "browser_download_url.*\.dmg" | head -n 1 | cut -d '"' -f 4 || echo "")
if [ -z "$DOWNLOAD_URL" ]; then
    DOWNLOAD_URL="https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob_v0.8.1.dmg"
fi

TMP_DMG="/tmp/PhantomKnob_latest.dmg"
MOUNT_POINT="/tmp/PhantomKnobMount"

# 1. Download latest DMG
echo -e "\033[1;34m==>\033[0m Downloading latest release package from $DOWNLOAD_URL ..."
curl -fsSL -L "$DOWNLOAD_URL" -o "$TMP_DMG"

# Cleanup existing mount point if any
if [ -d "$MOUNT_POINT" ]; then
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    rm -rf "$MOUNT_POINT"
fi

# 2. Mount DMG
echo -e "\033[1;34m==>\033[0m Mounting installation package..."
hdiutil attach "$TMP_DMG" -nobrowse -mountpoint "$MOUNT_POINT" -quiet

# 3. Copy to /Applications
echo -e "\033[1;34m==>\033[0m Copying PhantomKnob.app to /Applications..."
if [ -d "/Applications/PhantomKnob.app" ]; then
    rm -rf "/Applications/PhantomKnob.app"
fi
cp -R "$MOUNT_POINT/PhantomKnob.app" /Applications/

# 4. Remove Gatekeeper Quarantine flag
echo -e "\033[1;34m==>\033[0m Bypassing Gatekeeper quarantine security check..."
xattr -cr /Applications/PhantomKnob.app 2>/dev/null || true

# 5. Unmount and cleanup
echo -e "\033[1;34m==>\033[0m Cleaning up installation files..."
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
rm -f "$TMP_DMG"

echo -e "\033[1;32m🎉 PhantomKnob installed successfully!\033[0m"
echo "Launching PhantomKnob..."
open /Applications/PhantomKnob.app
