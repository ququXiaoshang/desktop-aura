# Hide or show the system desktop icons.
# Usage: powershell -File hide-icons.ps1 <0|1>   (0 = show, 1 = hide)
# Approach: set the HideIcons registry value AND the FWF_NOICONS flag in the
# desktop Shell Bags, then broadcast a settings-change notification so the
# desktop refreshes immediately WITHOUT restarting Explorer. Restarting Explorer
# was the cause of the taskbar flashing and the 2-3s mode-switch delay.
param([Parameter(Mandatory = $true)][int]$Hide)

$advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$bagPath = 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop'

# Read current state to skip work when already at the target state
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

# 2. FWF_NOICONS (0x1000) flag in desktop Shell Bags (persisted for next Explorer start)
if ($bag -and $null -ne $bag.FFlags) {
    $ff = [int]$bag.FFlags
    if ($Hide -eq 1) {
        $newFF = $ff -bor 0x1000          # set FWF_NOICONS
    } else {
        $newFF = $ff -band (-bnot 0x1000) # clear FWF_NOICONS
    }
    Set-ItemProperty -Path $bagPath -Name FFlags -Value $newFF -Type DWord
}

# 3. Refresh the desktop immediately without restarting Explorer
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class RefreshDesktop {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("shell32.dll")] public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
"@

$WM_SETTINGCHANGE    = 0x001A
$HWND_BROADCAST      = [IntPtr]0xFFFF
$SHCNE_ASSOCCHANGED  = 0x08000000
$SHCNF_IDLIST        = 0x0000
$SHCNF_FLUSH         = 0x1000

[RefreshDesktop]::PostMessage($HWND_BROADCAST, $WM_SETTINGCHANGE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
[RefreshDesktop]::SHChangeNotify($SHCNE_ASSOCCHANGED, ($SHCNF_IDLIST -bor $SHCNF_FLUSH), [IntPtr]::Zero, [IntPtr]::Zero)

# Give the shell a moment to apply the notification
Start-Sleep -Milliseconds 300

Write-Output ("HideIcons=" + $Hide)
