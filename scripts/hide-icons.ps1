# Hide or show the system desktop icons.
# Usage: powershell -File hide-icons.ps1 <0|1>   (0 = show, 1 = hide)
# Correct approach: set BOTH the HideIcons registry value AND the FWF_NOICONS flag
# in the desktop Shell Bags, then restart Explorer.
param([Parameter(Mandatory = $true)][int]$Hide)

$advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$bagPath = 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop'

# Read current state to skip the Explorer restart when already at the target state
$currentHide = (Get-ItemProperty -Path $advanced -Name HideIcons -ErrorAction SilentlyContinue).HideIcons
$bag = Get-ItemProperty -Path $bagPath -ErrorAction SilentlyContinue
$currentFF = 0
if ($bag -and $null -ne $bag.FFlags) { $currentFF = [int]$bag.FFlags }
$currentNoIcons = (($currentFF -band 0x1000) -ne 0)

$needChange = $false
if ($null -eq $currentHide -or [int]$currentHide -ne $Hide) { $needChange = $true }
if (($Hide -eq 1) -ne $currentNoIcons) { $needChange = $true }

if (-not $needChange) {
    Write-Output ("HideIcons=" + $Hide + " (already)")
    exit 0
}

# 1. HideIcons registry value
Set-ItemProperty -Path $advanced -Name HideIcons -Value $Hide -Type DWord

# 2. FWF_NOICONS (0x1000) flag in desktop Shell Bags
if ($bag -and $null -ne $bag.FFlags) {
    $ff = [int]$bag.FFlags
    if ($Hide -eq 1) {
        $newFF = $ff -bor 0x1000          # set FWF_NOICONS
    } else {
        $newFF = $ff -band (-bnot 0x1000) # clear FWF_NOICONS
    }
    Set-ItemProperty -Path $bagPath -Name FFlags -Value $newFF -Type DWord
}

# 3. Restart Explorer so both settings take effect correctly
Stop-Process -Name explorer -Force

# 4. Wait for Explorer to come back, so the caller can display the window immediately after
$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 200
    if (Get-Process explorer -ErrorAction SilentlyContinue) {
        Start-Sleep -Milliseconds 400
        break
    }
}

Write-Output ("HideIcons=" + $Hide)
