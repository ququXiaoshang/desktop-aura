# Check HideIcons registry value and whether the desktop icon layer (DefView) is actually visible.
$hide = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name HideIcons -ErrorAction SilentlyContinue).HideIcons
"HideIcons = $hide"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class CD {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    public delegate bool EP(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
}
"@

$script:def = [IntPtr]::Zero
$script:defParent = [IntPtr]::Zero
$cb = [CD+EP]{
    param($h, $l)
    $d = [CD]::FindWindowEx($h, [IntPtr]::Zero, "SHELLDLL_DefView", $null)
    if ($d -ne [IntPtr]::Zero) {
        $script:def = $d
        $script:defParent = $h
        return $false
    }
    return $true
}
[CD]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null

if ($script:def -eq [IntPtr]::Zero) {
    "DefView: NOT FOUND"
} else {
    "DefView = 0x$($script:def.ToInt64().ToString('X'))  parent=0x$($script:defParent.ToInt64().ToString('X'))"
    "DefView visible = $([CD]::IsWindowVisible($script:def))"
}
