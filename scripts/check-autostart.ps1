# Check whether auto-start is enabled.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$val = (Get-ItemProperty -Path $runKey -Name 'DesktopAura' -ErrorAction SilentlyContinue).DesktopAura
if ($val) { Write-Output "ON" } else { Write-Output "OFF" }
