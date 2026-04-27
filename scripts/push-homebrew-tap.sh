#!/usr/bin/env bash
# Pushes homebrew-tap/ to a standalone GitHub repo (default: avtomatization/homebrew-tap).
# Create an empty repo on GitHub first if it does not exist (gh token may lack repo:create).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAP_SRC="$ROOT/homebrew-tap"
REMOTE="${TAP_REMOTE:-git@github.com:avtomatization/homebrew-tap.git}"

if [[ ! -f "$TAP_SRC/Formula/powermeter.rb" ]]; then
  echo "Missing $TAP_SRC/Formula/powermeter.rb — run: bash scripts/prepare-homebrew-tap-repo.sh" >&2
  exit 1
fi

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

cp "$TAP_SRC/README.md" "$TMP/"
mkdir -p "$TMP/Formula"
cp "$TAP_SRC/Formula/powermeter.rb" "$TMP/Formula/powermeter.rb"

cd "$TMP"
git init -q
git add README.md Formula/powermeter.rb
if git diff --cached --quiet; then
  echo "Nothing to commit." >&2
  exit 1
fi
git commit -q -m "Add powermeter formula"
git branch -M main
git remote add origin "$REMOTE"
git push -u origin main

echo "Pushed to $REMOTE"
