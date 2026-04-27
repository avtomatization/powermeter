#!/usr/bin/env bash
# Called from Formula/powermeter.rb after `swift build`. Lays out the keg so the logic
# tracks `main` even when the tap formula file (avtomatization/homebrew-tap) lags.
# Usage: homebrew-install.sh PREFIX BUILDPATH
set -euo pipefail

PREFIX="${1:?prefix}"
BUILDPATH="${2:?buildpath}"

die() { echo "homebrew-install.sh: $*" >&2; exit 1; }

release_bin=""
while IFS= read -r -d '' f; do
  if [[ -x "$f" ]]; then
    release_bin="$f"
    break
  fi
done < <(find "$BUILDPATH/.build" -path '*/release/Powermeter' -type f -print0 2>/dev/null || true)

if [[ -z "$release_bin" && -x "$BUILDPATH/.build/release/Powermeter" ]]; then
  release_bin="$BUILDPATH/.build/release/Powermeter"
fi
[[ -n "$release_bin" && -x "$release_bin" ]] || die "release binary Powermeter not found under .build"

bundle_src=""
while IFS= read -r -d '' d; do
  if [[ -d "$d" ]]; then
    bundle_src="$d"
    break
  fi
done < <(find "$BUILDPATH/.build" -path '*/release/Powermeter_Powermeter.bundle' -type d -print0 2>/dev/null || true)

if [[ -z "$bundle_src" && -d "$BUILDPATH/.build/release/Powermeter_Powermeter.bundle" ]]; then
  bundle_src="$BUILDPATH/.build/release/Powermeter_Powermeter.bundle"
fi
[[ -n "$bundle_src" && -d "$bundle_src" ]] || die "Powermeter_Powermeter.bundle not found under .build"

mkdir -p "$PREFIX/bin" "$PREFIX/libexec" "$PREFIX/share/powermeter"
/usr/bin/install -m 0755 "$release_bin" "$PREFIX/bin/Powermeter"
/bin/rm -rf "$PREFIX/libexec/Powermeter_Powermeter.bundle" "$PREFIX/share/powermeter/Powermeter_Powermeter.bundle"
/usr/bin/ditto "$bundle_src" "$PREFIX/libexec/Powermeter_Powermeter.bundle"
/usr/bin/ditto "$bundle_src" "$PREFIX/share/powermeter/Powermeter_Powermeter.bundle"

[[ -d "$PREFIX/libexec/Powermeter_Powermeter.bundle" ]] || die "failed to install bundle under libexec"
[[ -d "$PREFIX/share/powermeter/Powermeter_Powermeter.bundle" ]] || die "failed to install bundle under share/powermeter"

cat > "$PREFIX/libexec/powermeter-brew-autostart-once.sh" <<'SH'
#!/bin/bash
# One-shot job: runs in the per-user GUI launchd domain so `open` can attach to WindowServer.
set -u
KEG_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXE="${KEG_ROOT}/bin/Powermeter"
PLIST="${HOME}/Library/LaunchAgents/com.powermeter.brew-autostart-once.plist"
LOG="${HOME}/Library/Logs/Powermeter/brew-autostart-once.log"
mkdir -p "${HOME}/Library/Logs/Powermeter"
exec >>"${LOG}" 2>&1
echo "=== $(/bin/date) autostart-once EXE=${EXE} ==="
cleanup() {
  /usr/bin/launchctl bootout "gui/$(id -u)" "${PLIST}" 2>/dev/null || true
  /bin/rm -f "${PLIST}"
  echo "=== $(/bin/date) removed one-shot plist ==="
}
trap cleanup EXIT
/usr/bin/pkill -x Powermeter 2>/dev/null || true
sleep 0.5
if /usr/bin/open -n "${EXE}"; then
  echo "open -n ok"
else
  echo "open -n failed, nohup fallback"
  /usr/bin/nohup "${EXE}" </dev/null >/dev/null 2>&1 &
fi
sleep 2
/usr/bin/pgrep -lx Powermeter || echo "pgrep: Powermeter not running"
SH
/bin/chmod 0755 "$PREFIX/libexec/powermeter-brew-autostart-once.sh"
