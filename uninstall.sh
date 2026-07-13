#!/bin/bash
# Stop and remove the marmar login agent and the installed app.
set -euo pipefail

LABEL="com.eneko.marmar"
APP_DST="$HOME/Applications/marmar.app"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

echo "→ stopping launch agent"
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true

echo "→ removing files"
rm -f "$PLIST_DST"
rm -rf "$APP_DST"

echo "✓ marmar uninstalled."
