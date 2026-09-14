#!/bin/bash
# Produces the only Mac file students download: Anime Study Tools Installer.app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$ROOT/installer"
APP="$ROOT/dist/Anime Study Tools Installer.app"
ZIP="$ROOT/dist/Anime-Study-Tools-Installer-mac.zip"
[[ -x "$INSTALLER/macos/Resources/yomitan-api-host" ]] || "$INSTALLER/helper/build-macos-host.sh"
rm -rf "$APP" "$ZIP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ROOT/dist"
TEMP_BUILD="$(mktemp -d "${TMPDIR:-/tmp}/anime-study-tools-app.XXXXXX")"
trap 'rm -rf "$TEMP_BUILD"' EXIT
swiftc -target arm64-apple-macos12.0 "$INSTALLER/macos/Sources/main.swift" -o "$TEMP_BUILD/app-arm64" -framework Cocoa -framework Network
swiftc -target x86_64-apple-macos12.0 "$INSTALLER/macos/Sources/main.swift" -o "$TEMP_BUILD/app-x86_64" -framework Cocoa -framework Network
lipo -create "$TEMP_BUILD/app-arm64" "$TEMP_BUILD/app-x86_64" -output "$APP/Contents/MacOS/Anime Study Tools Installer"
ditto "$INSTALLER/payload" "$APP/Contents/Resources/payload"
cp "$INSTALLER/macos/Resources/yomitan-api-host" "$APP/Contents/Resources/yomitan-api-host"
cp "$INSTALLER/helper/yomitan_api.py" "$APP/Contents/Resources/yomitan_api.py"
cp "$INSTALLER/helper/LICENSE.yomitan-api.txt" "$APP/Contents/Resources/LICENSE.yomitan-api.txt"
chmod 755 "$APP/Contents/Resources/yomitan-api-host"
cp "$INSTALLER/macos/Info.plist" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
(cd "$ROOT/dist" && ditto -c -k --sequesterRsrc --keepParent "Anime Study Tools Installer.app" "$(basename "$ZIP")")
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$ZIP")" > SHA256SUMS-mac.txt)
echo "Built: $ZIP"
