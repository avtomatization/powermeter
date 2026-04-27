#!/usr/bin/env bash
# Сравнение Powermeter с референсной программой в трее: 60 с выборки по умолчанию.
# Референс не читается автоматически — на полноэкранных снимках видны оба индикатора;
# числа Powermeter дополнительно вытягиваются из /tmp/powermeter-debug.log.
#
# Переменные окружения:
#   COMPARE_DURATION       — длительность, с (по умолчанию 60)
#   COMPARE_SHOT_INTERVAL  — интервал скриншотов, с (по умолчанию 5)
#   COMPARE_OUT            — каталог вывода (по умолчанию /tmp/powermeter-compare/run_<timestamp>)
#
# Перед запуском: запущены Powermeter и референсное приложение, иконки рядом в меню.
set -euo pipefail

DURATION="${COMPARE_DURATION:-60}"
INTERVAL="${COMPARE_SHOT_INTERVAL:-5}"
LOG_SRC="${COMPARE_LOG_SRC:-/tmp/powermeter-debug.log}"

if [[ -n "${COMPARE_OUT:-}" ]]; then
  OUT="$COMPARE_OUT"
else
  OUT="/tmp/powermeter-compare/run_$(date +%Y%m%d_%H%M%S)"
fi

mkdir -p "$OUT"

echo "=== Powermeter vs reference tray ==="
echo "Duration: ${DURATION}s  Screenshot interval: ${INTERVAL}s"
echo "Output: $OUT"
echo "Log source: $LOG_SRC"
echo "Place both tray apps visibly; starting in 2s..."
sleep 2

TIMELINE="$OUT/powermeter-debug-timeline.log"
touch "$TIMELINE"

# Новые строки лога за сессию (без старого хвоста файла)
tail -n 0 -f "$LOG_SRC" >>"$TIMELINE" 2>/dev/null &
LOGPID=$!

cleanup() {
  kill "$LOGPID" 2>/dev/null || true
}
trap cleanup EXIT

START_TS=$(date +%s)
N=0
while true; do
  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TS))
  if [[ "$ELAPSED" -ge "$DURATION" ]]; then
    break
  fi
  N=$((N + 1))
  screencapture -x "$OUT/shot_$(printf '%03d' "$N")_$(date +%H%M%S).png"
  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TS))
  REMAIN=$((DURATION - ELAPSED))
  if [[ "$REMAIN" -le 0 ]]; then
    break
  fi
  if [[ "$REMAIN" -lt "$INTERVAL" ]]; then
    sleep "$REMAIN"
    break
  fi
  sleep "$INTERVAL"
done

sleep 0.3
cleanup
trap - EXIT
wait "$LOGPID" 2>/dev/null || true

SUMMARY="$OUT/SUMMARY.txt"
WATTS_RAW="$OUT/powermeter-watts-from-log.txt"

perl -ne 'print "$1\n" if /runSample race winner: watts\(([0-9.]+)W/' "$TIMELINE" >"$WATTS_RAW" || true

{
  echo "Powermeter tray vs reference — session summary"
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Duration: ${DURATION}s  Shot interval: ${INTERVAL}s"
  echo "Screenshots: $(find "$OUT" -maxdepth 1 -name 'shot_*.png' 2>/dev/null | wc -l | tr -d ' ')"
  echo ""
  echo "Reference app: compare visually on shots (menu bar). This script does not read the reference value."
  echo ""
  echo "Powermeter — raw watt samples from log (race winner):"
  if [[ ! -s "$WATTS_RAW" ]]; then
    echo "  (no lines matched — is Powermeter running and logging to $LOG_SRC ?)"
  else
    CNT=$(wc -l <"$WATTS_RAW" | tr -d ' ')
    UNIQ=$(sort -u "$WATTS_RAW" | wc -l | tr -d ' ')
    MIN=$(sort -n "$WATTS_RAW" | head -1)
    MAX=$(sort -n "$WATTS_RAW" | tail -1)
    echo "  count=$CNT unique=$UNIQ min=${MIN} max=${MAX}"
    echo "  values (all):"
    cat "$WATTS_RAW" | sed 's/^/    /'
  fi
  echo ""
  echo "Files:"
  echo "  timeline: $TIMELINE"
  echo "  watts list: $WATTS_RAW"
} | tee "$SUMMARY"

echo ""
echo "Done. Open $OUT and SUMMARY.txt"
