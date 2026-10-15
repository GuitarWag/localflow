#!/bin/sh
# Builds LocalFlow.app next to this script. Pass a signing identity to sign for sharing:
#   ./build.sh "Developer ID Application: Your Name (TEAMID)"
set -e
cd "$(dirname "$0")"

swift build -c release
bin=$(swift build -c release --show-bin-path)

app=LocalFlow.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/"
cp "$bin/LocalFlow" "$app/Contents/MacOS/"
cp -R "$bin"/*.bundle "$app/Contents/Resources/"

codesign --force --deep --options runtime --entitlements LocalFlow.entitlements --sign "${1:--}" "$app"
echo "built $PWD/$app"
