#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="${POWERMETER_BIN_DIR:-$HOME/.local/bin}"
LOG_DIR="$HOME/Library/Logs/Powermeter"
PLIST="$HOME/Library/LaunchAgents/com.powermeter.menu.plist"
BIN="$BIN_DIR/Powermeter"

echo "Powermeter installer"
echo "Project: $ROOT"
echo

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift was not found. Install Xcode Command Line Tools first:"
  echo "  xcode-select --install"
  exit 1
fi

echo "1/4 Building release binary..."
cd "$ROOT"
swift build -c release

echo "2/4 Installing binary and SwiftPM resource bundle to $BIN_DIR"
mkdir -p "$BIN_DIR" "$LOG_DIR" "$HOME/Library/LaunchAgents"
cp "$ROOT/.build/release/Powermeter" "$BIN"
chmod +x "$BIN"
rm -rf "$BIN_DIR/Powermeter_Powermeter.bundle"
cp -R "$ROOT/.build/release/Powermeter_Powermeter.bundle" "$BIN_DIR/"

echo "3/4 Creating LaunchAgent..."
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.powermeter.menu</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/stderr.log</string>
</dict>
</plist>
EOF

echo "4/4 Starting Powermeter..."
pkill -x Powermeter 2>/dev/null || true
launchctl bootout "gui/$UID" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST"
launchctl kickstart -k "gui/$UID/com.powermeter.menu"

echo
echo "Done. Powermeter is installed and will start at login."
echo "If macOS blocks the first launch, open System Settings > Privacy & Security and allow it."
