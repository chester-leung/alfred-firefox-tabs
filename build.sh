#!/bin/sh
# Builds Firefox Tabs into dist/Firefox-Tabs.alfredworkflow.
#   ./build.sh           build and package
#   ./build.sh install   also copy straight into Alfred's preferences
set -e
cd "$(dirname "$0")"
mkdir -p build workflow dist
swiftc -O -target arm64-apple-macos12 fftabs.swift -o build/fftabs-arm64
swiftc -O -target x86_64-apple-macos12 fftabs.swift -o build/fftabs-x86_64
lipo -create build/fftabs-arm64 build/fftabs-x86_64 -output workflow/fftabs
codesign -s - -f workflow/fftabs 2>/dev/null
python3 make_workflow.py

# Icon comes from the local Firefox install (not redistributed in the repo).
ICNS=/Applications/Firefox.app/Contents/Resources/firefox.icns
[ -f "$ICNS" ] && sips -s format png -Z 256 "$ICNS" --out workflow/icon.png >/dev/null

rm -f dist/Firefox-Tabs.alfredworkflow
(cd workflow && zip -q ../dist/Firefox-Tabs.alfredworkflow fftabs info.plist)
echo "built dist/Firefox-Tabs.alfredworkflow"

if [ "$1" = install ]; then
  PREFS=$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder 2>/dev/null | sed "s|^~|$HOME|")
  DEST="${PREFS:-$HOME/Library/Application Support/Alfred}/Alfred.alfredpreferences/workflows/user.workflow.firefox-tabs"
  mkdir -p "$DEST"
  cp workflow/* "$DEST/"
  echo "installed to $DEST"
fi
