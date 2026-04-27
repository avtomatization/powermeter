#!/usr/bin/env bash
# Серия полноэкранных снимков для сравнения индикаторов в трее (например раз в 5 с).
set -euo pipefail
INTERVAL="${1:-5}"
COUNT="${2:-6}"
OUT="${3:-/tmp/powermeter-tray}"
mkdir -p "$OUT"
echo "Saving $COUNT shots every ${INTERVAL}s -> $OUT"
for i in $(seq 1 "$COUNT"); do
  f="$OUT/tray_${i}_$(date +%H%M%S).png"
  screencapture -x "$f"
  echo "  $f"
  [ "$i" -lt "$COUNT" ] && sleep "$INTERVAL"
done
echo "Done."
