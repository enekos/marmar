#!/bin/bash
# Build marmar, install it to ~/Applications, and enable "start at login" via
# SMAppService (managed from the app itself / the Settings window).
set -euo pipefail
cd "$(dirname "$0")"

LABEL="com.eneko.marmar"
APP_SRC=".build/marmar.app"
INSTALL_DIR="$HOME/Applications"
APP_DST="$INSTALL_DIR/marmar.app"
LEGACY_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

echo "→ building"
./build.sh release

echo "→ installing app to $APP_DST"
mkdir -p "$INSTALL_DIR"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

# Migrate away from the old hand-rolled LaunchAgent, if present, so we don't
# double-launch alongside the SMAppService login item.
if [ -f "$LEGACY_PLIST" ]; then
    echo "→ removing legacy LaunchAgent"
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$LEGACY_PLIST"
fi

echo "→ enabling launch at login"
"$APP_DST/Contents/MacOS/marmar" --register-login || true

echo "→ starting marmar"
open "$APP_DST"

echo
echo "✓ marmar installed, started, and set to launch at login."
echo "  Manage everything from the menu-bar icon ▸ Settings… (⌘,)"
echo "  Uninstall: ./uninstall.sh"
echo
echo "  If macOS shows marmar under Login Items as 'needs approval', enable it"
echo "  in System Settings ▸ General ▸ Login Items. Re-grant Microphone +"
echo "  Accessibility if prompted (the code signature changed)."
