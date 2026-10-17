# Restore every system change Aura made, and put the Windows desktop back to normal.
# Safe to run repeatedly. Works even if the Aura app is NOT running -- this is the escape hatch.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File restore-all.ps1
# ASCII-only on purpose: powershell.exe 5.1 reads no-BOM .ps1 files as the ANSI codepage.
$ErrorActionPreference = 'Continue'

$advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$bagPath  = 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop'
$runKey   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

# 1) Show the system desktop icons again
try {
    if (-not (Test-Path $advanced)) { New-Item -Path $advanced -Force | Out-Null }
    Set-ItemProperty -Path $advanced -Name HideIcons -Value 0 -Type DWord
    Write-Output 'HideIcons=0'
} catch {
    Write-Output ('[warn] HideIcons: ' + $_.Exception.Message)
}

# 2) Clear the FWF_NOICONS (0x1000) flag in the desktop Shell Bags
try {
    $bag = Get-ItemProperty -Path $bagPath -ErrorAction Stop
    if ($null -ne $bag.FFlags) {
        $ff = [int]$bag.FFlags -band (-bnot 0x1000)
        Set-ItemProperty -Path $bagPath -Name FFlags -Value $ff -Type DWord
        Write-Output 'FWF_NOICONS cleared'
    }
} catch {
    Write-Output '[warn] desktop Shell Bags FFlags not found (skipped)'
}

# 3) Remove the auto-start entry
try {
    $has = Get-ItemProperty -Path $runKey -Name DesktopAura -ErrorAction SilentlyContinue
    if ($has) {
        Remove-ItemProperty -Path $runKey -Name DesktopAura -ErrorAction SilentlyContinue
        Write-Output 'autostart removed'
    } else {
        Write-Output 'autostart absent'
    }
} catch {
    Write-Output ('[warn] autostart: ' + $_.Exception.Message)
}

# 4) Restart Explorer so the desktop picks up the change
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 200
    if (Get-Process explorer -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 400; break }
}

# 5) If Explorer somehow did not come back, start it manually
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer
    Start-Sleep -Milliseconds 600
}

Write-Output 'DONE'
