# Diagnose window/desktop structure.
param([string]$Hwnd = "0x90928")

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Diag {
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string n);
    public delegate bool EP(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
}
"@

$h = [IntPtr]::new([Int64]::Parse($Hwnd.Replace("0x", ""), [System.Globalization.NumberStyles]::HexNumber))
"IsWindow = $([Diag]::IsWindow($h))"
"IsWindowVisible = $([Diag]::IsWindowVisible($h))"
"GetParent = 0x$([Diag]::GetParent($h).ToString('X'))"

$progman = [Diag]::FindWindow("Progman", $null)
"Progman = 0x$($progman.ToString('X'))"

$all = New-Object System.Collections.ArrayList
$cb = [Diag+EP]{ param($w, $l); $null = $all.Add($w); return $true }
[Diag]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null

foreach ($w in $all) {
    $def = [Diag]::FindWindowEx($w, [IntPtr]::Zero, "SHELLDLL_DefView", $null)
    $mark = ""
    if ($def -ne [IntPtr]::Zero) { $mark = "  <- has DefView" }
    Write-Output ("0x{0:X}{1}" -f $w.ToInt64(), $mark)
}
