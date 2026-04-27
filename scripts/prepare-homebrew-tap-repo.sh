#!/usr/bin/env bash
# Copies Formula/powermeter.rb into a sibling (or given) folder suitable for
# GitHub repo avtomatization/homebrew-tap → brew tap avtomatization/tap
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$ROOT/../homebrew-tap}"

mkdir -p "$DEST/Formula"
cp "$ROOT/Formula/powermeter.rb" "$DEST/Formula/powermeter.rb"

cat > "$DEST/README.md" << 'EOF'
# Homebrew tap: avtomatization/tap

```bash
brew tap avtomatization/tap
brew install powermeter
```

Formulas live under `Formula/`. Source: [Powermeter](https://github.com/avtomatization/powermeter).
EOF

echo "Prepared: $DEST"
echo "Next: cd \"$DEST\" && git init && git add . && git commit -m \"Add powermeter formula\""
echo "Create empty GitHub repo: https://github.com/avtomatization/homebrew-tap"
echo "Then: git remote add origin git@github.com:avtomatization/homebrew-tap.git && git push -u origin main"
