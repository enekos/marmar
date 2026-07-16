#!/bin/bash
# Stop marmar, disable launch-at-login, and remove the installed app.
set -euo pipefail

LABEL="com.eneko.marmar"
APP_DST="$HOME/Applications/marmar.app"
LEGACY_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

echo "→ disabling launch at login"
[ -x "$APP_DST/Contents/MacOS/marmar" ] && "$APP_DST/Contents/MacOS/marmar" --unregister-login || true

echo "→ removing legacy LaunchAgent (if any)"
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
rm -f "$LEGACY_PLIST"

echo "→ quitting + removing app"
pkill -f "Applications/marmar.app/Contents/MacOS/marmar" 2>/dev/null || true
rm -rf "$APP_DST"

echo "✓ marmar uninstalled."
