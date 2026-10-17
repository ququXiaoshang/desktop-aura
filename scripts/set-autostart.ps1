# Enable/disable auto-start via HKCU Run key.
# Usage: set-autostart.ps1 <1|0> <exePath> <appPath>
param([Parameter(Mandatory = $true)][int]$Enable,
      [Parameter(Mandatory = $true)][string]$ExePath,
      [Parameter(Mandatory = $true)][string]$AppPath)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$name = 'DesktopAura'

if ($Enable -eq 1) {
    $cmd = '"' + $ExePath + '" "' + $AppPath + '"'
    Set-ItemProperty -Path $runKey -Name $name -Value $cmd
    Write-Output "AUTOSTART=ON"
} else {
    Remove-ItemProperty -Path $runKey -Name $name -ErrorAction SilentlyContinue
    Write-Output "AUTOSTART=OFF"
}
