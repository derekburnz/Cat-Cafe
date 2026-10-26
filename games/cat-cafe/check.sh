#!/usr/bin/env bash
# Done gate for Purr Pot (macOS/Linux/Git Bash). Run from games/cat-cafe: ./check.sh
set -euo pipefail
cd "$(dirname "$0")"

step() { echo "== $1"; shift; "$@"; }

step "rojo sourcemap" rojo sourcemap default.project.json -o sourcemap.json

TYPES=globalTypes.None.d.luau
if [ ! -f "$TYPES" ]; then
  echo "Downloading Roblox API types for luau-lsp (one time)..."
  curl -fsSL -o "$TYPES" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau
fi

step "luau-lsp analyze" luau-lsp analyze --sourcemap=sourcemap.json --definitions="$TYPES" --ignore "Packages/**" --ignore "ServerPackages/**" src
step "selene" selene src
step "stylua --check" stylua --check src
echo "All checks passed."
