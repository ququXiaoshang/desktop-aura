# Zip the portable (green) build into a single distributable archive.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/zip-release.ps1
# NOTE: keep this script ASCII-only (no Chinese literals). It is invoked by
# powershell.exe 5.1, which reads no-BOM .ps1 files as the ANSI codepage.
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'dist\win-unpacked'
$pkg = Get-Content (Join-Path $root 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$ver = $pkg.version
$outDir = Join-Path $root 'release'
$folderName = "desktop-aura-$ver-win-x64"
$zipPath = Join-Path $outDir "$folderName.zip"

if (-not (Test-Path $src)) {
  Write-Error "Missing $src. Run 'pnpm dist' first to build the portable version."
  exit 1
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Stage into a temp dir under a friendly folder name, then compress that folder.
$staging = Join-Path $env:TEMP "aura-release-$ver"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
$stagingApp = Join-Path $staging $folderName
New-Item -ItemType Directory -Force -Path $staging | Out-Null
Copy-Item -Path $src -Destination $stagingApp -Recurse -Force

# Ship the one-click restore helper at the archive root (works even if the app cannot start).
Get-ChildItem -Path $root -File -Filter *.bat | ForEach-Object { Copy-Item $_.FullName -Destination $stagingApp -Force }
$restoreSrc = Join-Path $root 'scripts\restore-all.ps1'
if (Test-Path $restoreSrc) { Copy-Item $restoreSrc -Destination $stagingApp -Force }

# Ship the end-user manual at the archive root (skip developer docs).
Get-ChildItem -Path $root -File -Filter *.md | Where-Object { $_.Name -notmatch '^(README|AGENTS|HANDOFF)' } | ForEach-Object { Copy-Item $_.FullName -Destination $stagingApp -Force }

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $stagingApp -DestinationPath $zipPath -CompressionLevel Optimal

Remove-Item $staging -Recurse -Force

$mb = '{0:N1}' -f ((Get-Item $zipPath).Length / 1MB)
Write-Output "OK: $zipPath ($mb MB)"
