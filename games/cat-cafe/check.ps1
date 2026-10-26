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

# Roblox API types must come from the same luau-lsp version that parses them (newer files use syntax
# older releases reject), so they are fetched from the tag matching `luau-lsp --version`.
$types = "globalTypes.None.d.luau"
$lspVersion = ((luau-lsp --version) | Select-String -Pattern '\d+\.\d+\.\d+').Matches[0].Value
$haveVersion = if (Test-Path .types-version) { (Get-Content .types-version -Raw).Trim() } else { "" }
if (-not (Test-Path $types) -or $haveVersion -ne $lspVersion) {
  Write-Host "Downloading Roblox API types for luau-lsp $lspVersion (once per version)..."
  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$lspVersion/scripts/globalTypes.None.d.luau" -OutFile $types
  Set-Content -Path .types-version -Value $lspVersion
}

Step "luau-lsp analyze" {
  luau-lsp analyze --sourcemap=sourcemap.json --definitions=$types --ignore "Packages/**" --ignore "ServerPackages/**" --ignore "src/server/Vendor/**" src
}
Step "selene" { selene src }
Step "stylua --check" { stylua --check src }

Write-Host "All checks passed." -ForegroundColor Green
