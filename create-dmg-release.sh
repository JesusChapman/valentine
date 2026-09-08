#!/bin/bash
set -e

# ==============================================================================
# Script to create a custom DMG installer for Valentine using 'create-dmg'
# - Light Theme + Liquid Glass design
# - EULA License Agreement Popup (Accept/Disagree)
# - Default output: ./dist/valentine_(version)_(build)_(arquitectura).dmg
# ==============================================================================

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "❌ Error: 'create-dmg' is not installed."
    echo "Please install it using Homebrew:"
    echo "    brew install create-dmg"
    exit 1
fi

INPUT_APP="${1:-Valentine.app}"

# If default app path was not found in current directory, search DerivedData
if [ ! -d "$INPUT_APP" ]; then
    DERIVED_APP=$(find ~/Library/Developer/Xcode/DerivedData/Valentine-*/Build/Products -name "Valentine.app" 2>/dev/null | head -n 1)
    if [ -n "$DERIVED_APP" ] && [ -d "$DERIVED_APP" ]; then
        echo "ℹ️  Found application in DerivedData: $DERIVED_APP"
        INPUT_APP="$DERIVED_APP"
    fi
fi

if [ ! -d "$INPUT_APP" ]; then
    echo "❌ Error: Input app not found at '$INPUT_APP'"
    echo "Usage: ./create-dmg-release.sh [path-to-app] [path-to-output-dmg]"
    echo "Example: ./create-dmg-release.sh ./Valentine.app"
    exit 1
fi

APP_NAME="$(basename "$INPUT_APP")"
VOLUME_NAME="${APP_NAME%.app}"

# Extract App Version and Build Number from Info.plist
INFO_PLIST="$INPUT_APP/Contents/Info.plist"
VERSION="1.0"
BUILD="1"
if [ -f "$INFO_PLIST" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0")
    BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "1")
    EXEC_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST" 2>/dev/null || echo "$VOLUME_NAME")
else
    EXEC_NAME="$VOLUME_NAME"
fi

# Detect Architecture from binary
APP_EXEC="$INPUT_APP/Contents/MacOS/$EXEC_NAME"
ARCH="$(uname -m)"
if [ -f "$APP_EXEC" ]; then
    ARCH_RAW=$(lipo -archs "$APP_EXEC" 2>/dev/null || echo "$ARCH")
    if echo "$ARCH_RAW" | grep -q "arm64" && echo "$ARCH_RAW" | grep -q "x86_64"; then
        ARCH="universal"
    elif echo "$ARCH_RAW" | grep -q "arm64"; then
        ARCH="arm64"
    elif echo "$ARCH_RAW" | grep -q "x86_64"; then
        ARCH="x86_64"
    else
        ARCH="$(uname -m)"
    fi
fi

# Determine output DMG path
DEFAULT_OUTPUT="dist/valentine_${VERSION}_${BUILD}_${ARCH}.dmg"
OUTPUT_DMG="${2:-$DEFAULT_OUTPUT}"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_DMG")"

# Check for License file to attach as interactive EULA popup
EULA_ARGS=()
if [ -f "LICENSE" ]; then
    echo "📜 Found LICENSE file. Attaching EULA agreement popup..."
    EULA_ARGS=(--eula "LICENSE")
elif [ -f "LICENSE.txt" ]; then
    echo "📜 Found LICENSE.txt file. Attaching EULA agreement popup..."
    EULA_ARGS=(--eula "LICENSE.txt")
fi

echo "=================================================="
echo " Packaging:    $APP_NAME"
echo " Version:      $VERSION (build $BUILD)"
echo " Architecture: $ARCH"
echo " Output DMG:   $OUTPUT_DMG"
echo " Volume Name:  $VOLUME_NAME"
echo " Theme:        Light Liquid Glass"
echo " EULA Popup:   $([ ${#EULA_ARGS[@]} -gt 0 ] && echo 'Enabled (Agree/Disagree)' || echo 'Disabled')"
echo "=================================================="

# Ensure multi-resolution TIFF background image exists, otherwise generate it
BG_IMAGE="preview/dmg_background.tiff"
if [ ! -f "$BG_IMAGE" ]; then
    echo "🎨 Generating Light Liquid Glass DMG background images..."
    python3 scripts/generate_dmg_background.py
fi

# Create clean temporary staging directory
TMP_DIR=$(mktemp -d -t "dmg_staging_XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

echo "1. Staging $APP_NAME..."
cp -R "$INPUT_APP" "$TMP_DIR/$APP_NAME"

# Check for volume icon
VOLICON_ARGS=()
if [ -f "$INPUT_APP/Contents/Resources/appicon.icns" ]; then
    VOLICON_ARGS=(--volicon "$INPUT_APP/Contents/Resources/appicon.icns")
elif [ -f "$INPUT_APP/Contents/Resources/AppIcon.icns" ]; then
    VOLICON_ARGS=(--volicon "$INPUT_APP/Contents/Resources/AppIcon.icns")
fi

echo "2. Building DMG using create-dmg..."
create-dmg \
  --volname "$VOLUME_NAME" \
  "${VOLICON_ARGS[@]}" \
  "${EULA_ARGS[@]}" \
  --background "$BG_IMAGE" \
  --window-pos 200 120 \
  --window-size 660 440 \
  --icon-size 110 \
  --text-size 13 \
  --icon "$APP_NAME" 175 215 \
  --hide-extension "$APP_NAME" \
  --app-drop-link 485 215 \
  --app-drop-link-name "Applications" \
  --no-internet-enable \
  --format UDZO \
  --overwrite \
  "$OUTPUT_DMG" \
  "$TMP_DIR"

echo "=================================================="
echo "✅ Successfully generated: $OUTPUT_DMG"
echo "=================================================="
