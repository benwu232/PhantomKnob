#!/bin/bash
set -e

# PhantomKnob Sparkle 2 Release Helper Script
# Usage: ./scripts/release_update.sh <version> <private_key_path>

VERSION=$1
PRIVATE_KEY_PATH=$2

if [ -z "$VERSION" ] || [ -z "$PRIVATE_KEY_PATH" ]; then
    echo "Usage: $0 <version> <private_key_path>"
    exit 1
fi

echo "==> Building PhantomKnob Release v${VERSION}..."
xcodebuild -scheme PhantomKnob -configuration Release clean archive -archivePath "build/PhantomKnob.xcarchive"
xcodebuild -archivePath "build/PhantomKnob.xcarchive" -exportArchive -exportOptionsPlist "build/exportOptions.plist" -exportPath "build/Exported"

ZIP_PATH="build/Exported/PhantomKnob_v${VERSION}.zip"
ditto -c -k --sequesterRsrc --keepParent "build/Exported/PhantomKnob.app" "$ZIP_PATH"

echo "==> Signing Update Package with Sparkle Key..."
./bin/sign_update "$ZIP_PATH" -f "$PRIVATE_KEY_PATH"

echo "==> Updating Appcast XML..."
./bin/generate_appcast "build/Exported"

echo "==> Release Package Ready at $ZIP_PATH"
