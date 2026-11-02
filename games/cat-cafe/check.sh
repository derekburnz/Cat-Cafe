#!/usr/bin/env bash
# Done gate for Cat Cafe (macOS/Linux/Git Bash). Run from games/cat-cafe: ./check.sh
set -euo pipefail
cd "$(dirname "$0")"

step() { echo "== $1"; shift; "$@"; }

step "rojo sourcemap" rojo sourcemap default.project.json -o sourcemap.json

# Roblox API types must come from the same luau-lsp version that parses them (newer files use syntax
# older releases reject), so they are fetched from the tag matching `luau-lsp --version`.
TYPES=globalTypes.None.d.luau
LSP_VERSION=$(luau-lsp --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
if [ ! -f "$TYPES" ] || [ "$(cat .types-version 2>/dev/null)" != "$LSP_VERSION" ]; then
  echo "Downloading Roblox API types for luau-lsp $LSP_VERSION (once per version)..."
  curl -fsSL -o "$TYPES" "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$LSP_VERSION/scripts/globalTypes.None.d.luau"
  echo "$LSP_VERSION" > .types-version
fi

step "luau-lsp analyze" luau-lsp analyze --sourcemap=sourcemap.json --definitions="$TYPES" --ignore "Packages/**" --ignore "ServerPackages/**" --ignore "src/server/Vendor/**" src
step "selene" selene src
step "stylua --check" stylua --check src
echo "All checks passed."
