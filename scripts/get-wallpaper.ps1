# Output the current wallpaper file path, or empty if not found.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$wp = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallPaper -ErrorAction SilentlyContinue).WallPaper
if ($wp -and (Test-Path $wp)) {
    Write-Output $wp
} else {
    Write-Output ""
}
