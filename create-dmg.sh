#!/bin/bash
set -e

# Requires: brew install create-dmg
if ! command -v create-dmg &>/dev/null; then
    echo "Error: create-dmg not found. Install with: brew install create-dmg"
    exit 1
fi

if [ ! -d "App-Sweep.app" ]; then
    echo "Error: App-Sweep.app not found."
    exit 1
fi

rm -f App-Sweep.dmg

# Fix DPI for Retina: 1320x800 @ 144 DPI = 660x400 logical pixels
sips -s dpiWidth 144 -s dpiHeight 144 dmg-background.png

create-dmg \
  --volname "App Sweep" \
  --background "dmg-background.png" \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "App-Sweep.app" 160 190 \
  --app-drop-link 500 190 \
  --hdiutil-verbose \
  "App-Sweep.dmg" \
  "App-Sweep.app"

echo ""
echo "Successfully created App-Sweep.dmg with drag-to-install layout!"
