#!/bin/sh
# Builds a universal fftabs binary into ./workflow.
set -e
cd "$(dirname "$0")"
mkdir -p build workflow
swiftc -O -target arm64-apple-macos12 fftabs.swift -o build/fftabs-arm64
swiftc -O -target x86_64-apple-macos12 fftabs.swift -o build/fftabs-x86_64
lipo -create build/fftabs-arm64 build/fftabs-x86_64 -output workflow/fftabs
codesign -s - -f workflow/fftabs
python3 make_workflow.py
# Install into Alfred's (Dropbox-synced) preferences.
PREFS=$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder 2>/dev/null | sed "s|^~|$HOME|")
DEST="${PREFS:-$HOME/Library/Application Support/Alfred}/Alfred.alfredpreferences/workflows/user.workflow.firefox-tabs"
mkdir -p "$DEST"
cp workflow/fftabs workflow/info.plist workflow/icon.png "$DEST/"
echo "installed to $DEST"
