# Check whether a window (by HWND) still has a parent (i.e. still attached to the desktop layer).
# Usage: powershell -File is-attached.ps1 <hwnd>
param([Parameter(Mandatory = $true)][string]$Hwnd)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class AttachCheck {
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr hWnd);
}
"@

$h = [IntPtr]::new([Int64]::Parse($Hwnd))
$p = [AttachCheck]::GetParent($h)
if ($p -eq [IntPtr]::Zero) {
    Write-Output "DETACHED"
} else {
    Write-Output ("ATTACHED 0x{0:X}" -f $p.ToInt64())
}
