# Read Windows desktop icon layout metrics and output as compact JSON.
$wm = Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -ErrorAction SilentlyContinue
$bag = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop' -ErrorAction SilentlyContinue

$spacingX = 75.0
$spacingY = 75.0
$iconSize = 48
$titleWrap = $false

if ($wm -and $wm.IconSpacing) {
    $v = [int]$wm.IconSpacing
    if ($v -lt 0) { $spacingX = [math]::Abs($v) / 15.0 }
}
if ($wm -and $wm.IconVerticalSpacing) {
    $v = [int]$wm.IconVerticalSpacing
    if ($v -lt 0) { $spacingY = [math]::Abs($v) / 15.0 }
}
if ($bag -and $bag.IconSize) {
    $iconSize = [int]$bag.IconSize
}
if ($wm -and $wm.IconTitleWrap) {
    $titleWrap = $true
}

[pscustomobject]@{
    spacingX = [math]::Round($spacingX, 1)
    spacingY = [math]::Round($spacingY, 1)
    iconSize = $iconSize
    titleWrap = $titleWrap
} | ConvertTo-Json -Compress
