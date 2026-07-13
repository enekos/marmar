#!/bin/bash
# Build marmar, install it to ~/Applications, and register a launchd login agent
# so it starts automatically at login and relaunches if it crashes.
set -euo pipefail
cd "$(dirname "$0")"

LABEL="com.eneko.marmar"
APP_SRC=".build/marmar.app"
INSTALL_DIR="$HOME/Applications"
APP_DST="$INSTALL_DIR/marmar.app"
PLIST_SRC="packaging/$LABEL.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

echo "→ building"
./build.sh release

echo "→ installing app to $APP_DST"
mkdir -p "$INSTALL_DIR"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

echo "→ writing launch agent to $PLIST_DST"
mkdir -p "$HOME/Library/LaunchAgents"
sed "s|__BINARY__|$APP_DST/Contents/MacOS/marmar|g" "$PLIST_SRC" > "$PLIST_DST"

echo "→ (re)loading launch agent"
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST_DST"
launchctl enable "$DOMAIN/$LABEL"
launchctl kickstart -k "$DOMAIN/$LABEL"

echo
echo "✓ marmar installed and running as a login agent."
echo "  It will start automatically at every login."
echo "  Logs: /tmp/marmar.out.log  /tmp/marmar.err.log"
echo "  Uninstall: ./uninstall.sh"
echo
echo "  NOTE: because the code signature changed, you may need to re-grant"
echo "  Accessibility (and Microphone) to the copy in ~/Applications the first"
echo "  time — System Settings ▸ Privacy & Security."
