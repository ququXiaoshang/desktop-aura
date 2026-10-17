# Attach a window (by HWND) to the desktop layer (above icons, below normal windows).
# Usage: powershell -File attach-to-desktop.ps1 <hwnd>
param([Parameter(Mandatory = $true)][string]$Hwnd)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DesktopWin32 {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);
    [DllImport("user32.dll")]
    public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

$child = [IntPtr]::new([Int64]::Parse($Hwnd))

# 1. Enumerate WorkerW windows, find the one hosting SHELLDLL_DefView (the icon layer)
$script:targetWorker = [IntPtr]::Zero
$cb = [DesktopWin32+EnumWindowsProc]{
    param($hWnd, $lParam)
    if ([DesktopWin32]::FindWindowEx($hWnd, [IntPtr]::Zero, "SHELLDLL_DefView", $null) -ne [IntPtr]::Zero) {
        $script:targetWorker = $hWnd
        return $false
    }
    return $true
}
[DesktopWin32]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null

# 2. Only if not found, nudge Progman (0x052C) to create the WorkerW, then retry once.
if ($script:targetWorker -eq [IntPtr]::Zero) {
    $progman = [DesktopWin32]::FindWindow("Progman", $null)
    if ($progman -ne [IntPtr]::Zero) {
        $dummy = [IntPtr]::Zero
        [DesktopWin32]::SendMessageTimeout($progman, 0x052C, [IntPtr]::Zero, [IntPtr]::Zero, 0x0002, 1000, [ref]$dummy) | Out-Null
        Start-Sleep -Milliseconds 300
        $script:targetWorker = [IntPtr]::Zero
        $cb2 = [DesktopWin32+EnumWindowsProc]{
            param($hWnd, $lParam)
            if ([DesktopWin32]::FindWindowEx($hWnd, [IntPtr]::Zero, "SHELLDLL_DefView", $null) -ne [IntPtr]::Zero) {
                $script:targetWorker = $hWnd
                return $false
            }
            return $true
        }
        [DesktopWin32]::EnumWindows($cb2, [IntPtr]::Zero) | Out-Null
    }
}

$parent = $script:targetWorker
if ($parent -eq [IntPtr]::Zero) {
    Write-Output "NO_WORKERW"
    exit 1
}

[DesktopWin32]::SetParent($child, $parent) | Out-Null

# 3. Reposition and resize to the parent's client area (handles DPI scaling)
$rect = [DesktopWin32+RECT]::new()
[DesktopWin32]::GetClientRect($parent, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
# SWP_SHOWWINDOW = 0x0040
[DesktopWin32]::SetWindowPos($child, [IntPtr]::Zero, 0, 0, $w, $h, 0x0040) | Out-Null

Write-Output ("ATTACHED child=0x{0:X} parent=0x{1:X} size={2}x{3}" -f $child.ToInt64(), $parent.ToInt64(), $w, $h)
