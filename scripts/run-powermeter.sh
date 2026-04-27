#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
pkill -x Powermeter 2>/dev/null || true
sleep 0.25
nohup "$ROOT/.build/release/Powermeter" >> /tmp/powermeter.log 2>&1 &
sleep 0.4
pgrep -lx Powermeter || { echo "Powermeter failed to start" >&2; exit 1; }
