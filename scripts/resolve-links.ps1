# Resolve .lnk shortcut targets (and icon locations) in bulk.
# Input: path to a JSON file containing an array of .lnk paths.
# Output: JSON array of { path, target, icon }.
param([Parameter(Mandatory = $true)][string]$InputFile)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$raw = Get-Content -Raw -Encoding UTF8 $InputFile
$links = ConvertFrom-Json -InputObject $raw
if ($null -eq $links) { $links = @() }
$sh = New-Object -ComObject WScript.Shell
$results = @()

foreach ($link in $links) {
    $target = ""
    $icon = ""
    try {
        $lnk = $sh.CreateShortcut($link)
        $target = [string]$lnk.TargetPath
        $icon = [string]$lnk.IconLocation
    } catch {}
    $results += [pscustomobject]@{
        path   = [string]$link
        target = $target
        icon   = $icon
    }
}

$results | ConvertTo-Json -Compress
