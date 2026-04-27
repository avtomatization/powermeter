#!/usr/bin/env bash
# Pushes homebrew-tap/ to a standalone GitHub repo (default: avtomatization/homebrew-tap).
# Clones the remote, copies README + Formula on top of existing history, commits, and pushes
# (avoids "rejected: fetch first" from a fresh git init with an unrelated first commit).
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

git clone "$REMOTE" "$TMP/repo"

cd "$TMP/repo"

resolve_branch() {
  local b
  b="$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)"
  if [[ -n "$b" ]]; then
    echo "$b"
    return
  fi
  for b in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$b"; then
      echo "$b"
      return
    fi
  done
  echo "main"
}

if git rev-parse HEAD >/dev/null 2>&1; then
  BRANCH="$(git branch --show-current)"
  if [[ -z "$BRANCH" ]]; then
    BRANCH="$(resolve_branch)"
    git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH"
  fi
  git pull --rebase origin "$BRANCH"
else
  # Empty clone (no commits on remote yet)
  BRANCH=main
  git checkout -b "$BRANCH"
fi

cp "$TAP_SRC/README.md" README.md
mkdir -p Formula
cp "$TAP_SRC/Formula/powermeter.rb" Formula/powermeter.rb

git add README.md Formula/powermeter.rb

if git diff --cached --quiet; then
  echo "Remote tap already matches local homebrew-tap/ (nothing to commit)."
  exit 0
fi

git commit -m "Sync powermeter formula from avtomatization/powermeter"

git push -u origin "$BRANCH"

echo "Pushed to $REMOTE ($BRANCH)"
