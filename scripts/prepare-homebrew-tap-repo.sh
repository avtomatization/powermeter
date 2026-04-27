#!/usr/bin/env bash
# Copies root Formula/powermeter.rb into homebrew-tap/ (default) for publishing
# as GitHub repo avtomatization/homebrew-tap → brew tap avtomatization/tap
# Optional first argument: alternate destination directory.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$ROOT/homebrew-tap}"

mkdir -p "$DEST/Formula"
cp "$ROOT/Formula/powermeter.rb" "$DEST/Formula/powermeter.rb"

cat > "$DEST/README.md" << 'EOF'
# Homebrew tap: avtomatization/tap

```bash
brew tap avtomatization/tap
brew install --HEAD powermeter
```

Reinstall / upgrade: **`brew reinstall powermeter`** (not `reinstall --HEAD`; verbose: **`-v`**). **`post_install`** loads a **one-time `launchd` user agent** that runs **`open -n`** in the GUI session (see **`~/Library/Logs/Powermeter/brew-autostart-once.log`**). **`brew uninstall`** removes that plist, login plist, logs, `~/.local/bin` copies, etc.

Formulas live under `Formula/`. Source: [Powermeter](https://github.com/avtomatization/powermeter).

This directory is a mirror of the tap layout kept in the main Powermeter repo. After editing the root `Formula/powermeter.rb`, run `bash scripts/prepare-homebrew-tap-repo.sh` to refresh `homebrew-tap/Formula/`.
EOF

echo "Synced: $DEST"
echo "Publish: create empty https://github.com/avtomatization/homebrew-tap if needed, then:"
echo "  bash scripts/push-homebrew-tap.sh"
