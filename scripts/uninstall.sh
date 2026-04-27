#!/usr/bin/env bash
set -euo pipefail

BIN="${POWERMETER_BIN:-$HOME/.local/bin/Powermeter}"
BUNDLE="$(dirname "$BIN")/Powermeter_Powermeter.bundle"
PLIST="$HOME/Library/LaunchAgents/com.powermeter.menu.plist"

echo "Stopping Powermeter..."
launchctl bootout "gui/$UID" "$PLIST" 2>/dev/null || true
pkill -x Powermeter 2>/dev/null || true

echo "Removing LaunchAgent, binary, and resource bundle..."
rm -f "$PLIST" "$BIN"
rm -rf "$BUNDLE"

echo "Done. Preferences are left in UserDefaults."
