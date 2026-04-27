#!/usr/bin/env bash
set -euo pipefail

BIN="${POWERMETER_BIN:-$HOME/.local/bin/Powermeter}"
PLIST="$HOME/Library/LaunchAgents/com.powermeter.menu.plist"

echo "Stopping Powermeter..."
launchctl bootout "gui/$UID" "$PLIST" 2>/dev/null || true
pkill -x Powermeter 2>/dev/null || true

echo "Removing LaunchAgent and binary..."
rm -f "$PLIST" "$BIN"

echo "Done. Preferences are left in UserDefaults."
