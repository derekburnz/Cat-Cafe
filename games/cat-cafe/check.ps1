# Done gate for Purr Pot. Run from games/cat-cafe in PowerShell: ./check.ps1
# Steps: Rojo sourcemap -> luau-lsp type check -> Selene lint -> StyLua format check.
# Exit code is non-zero if any step fails, so agents can tell pass from fail.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Step($name, $block) {
  Write-Host "== $name" -ForegroundColor Cyan
  & $block
  if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $name" -ForegroundColor Red; exit 1 }
}

Step "rojo sourcemap" { rojo sourcemap default.project.json -o sourcemap.json }

$types = "globalTypes.None.d.luau"
if (-not (Test-Path $types)) {
  Write-Host "Downloading Roblox API types for luau-lsp (one time)..."
  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau" -OutFile $types
}

Step "luau-lsp analyze" {
  luau-lsp analyze --sourcemap=sourcemap.json --definitions=$types --ignore "Packages/**" --ignore "ServerPackages/**" --ignore "src/server/Vendor/**" src
}
Step "selene" { selene src }
Step "stylua --check" { stylua --check src }

Write-Host "All checks passed." -ForegroundColor Green
