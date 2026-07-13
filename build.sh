#!/bin/bash
# Build marmar and assemble a minimal .app bundle (no Xcode required).
# The bundle is needed so macOS TCC can attach the microphone + accessibility
# permissions to a stable identity, and so the Info.plist usage string exists.
set -euo pipefail

APP="marmar"
BUNDLE_ID="com.eneko.marmar"
VERSION="0.1.0"
CONFIG="${1:-release}"

cd "$(dirname "$0")"

echo "→ swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/$APP"

APPDIR=".build/$APP.app"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/Contents/MacOS" "$APPDIR/Contents/Resources"

cp "$BIN" "$APPDIR/Contents/MacOS/$APP"

cat > "$APPDIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP</string>
    <key>CFBundleDisplayName</key>     <string>marmar</string>
    <key>CFBundleExecutable</key>      <string>$APP</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>         <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>  <string>26.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>marmar transcribes your speech on-device while you hold the dictation key.</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so TCC has a stable code identity to hang permissions on.
codesign --force --sign - "$APPDIR" >/dev/null 2>&1 || true

echo "✓ Built $APPDIR"
echo "  Run:  open $APPDIR      (or: $APPDIR/Contents/MacOS/$APP for logs)"
