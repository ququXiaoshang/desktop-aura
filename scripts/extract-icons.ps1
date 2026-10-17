# Extract real icons (exe/dll/ico) in bulk using System.Drawing.
# Input: JSON file = [{ key, source }]
# Output: JSON = [{ key, png }] where png is the saved PNG path (or empty).
param([Parameter(Mandatory = $true)][string]$InputFile,
      [Parameter(Mandatory = $true)][string]$OutDir)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing

$raw = Get-Content -Raw -Encoding UTF8 $InputFile
$items = ConvertFrom-Json -InputObject $raw
if ($null -eq $items) { $items = @() }

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$results = @()
foreach ($it in $items) {
    $src = [string]$it.source
    $pngPath = ""
    if ($src -and (Test-Path $src)) {
        try {
            $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($src)
            if ($null -ne $icon) {
                $bmp = $icon.ToBitmap()
                $bmp64 = New-Object System.Drawing.Bitmap($bmp, 64, 64)
                $pngPath = Join-Path $OutDir ("icon-" + [string]$it.key + ".png")
                $bmp64.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
                $bmp64.Dispose()
                $bmp.Dispose()
                $icon.Dispose()
            }
        } catch {}
    }
    $results += [pscustomobject]@{ key = [string]$it.key; png = $pngPath }
}

$results | ConvertTo-Json -Compress
