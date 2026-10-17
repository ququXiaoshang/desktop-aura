# Dump target + icon location for given .lnk files, one line each (clear output).
param([Parameter(Mandatory = $true)][string]$InputFile)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$raw = Get-Content -Raw -Encoding UTF8 $InputFile
$links = ConvertFrom-Json -InputObject $raw
if ($null -eq $links) { $links = @() }

$sh = New-Object -ComObject WScript.Shell
foreach ($link in $links) {
    $target = ""
    $icon = ""
    try {
        $lnk = $sh.CreateShortcut($link)
        $target = [string]$lnk.TargetPath
        $icon = [string]$lnk.IconLocation
    } catch {}
    Write-Output ("{0}`t| target={1}`t| icon={2}" -f (Split-Path $link -Leaf), $target, $icon)
}
