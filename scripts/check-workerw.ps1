# Check visibility of WorkerW windows and DefView.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class CW {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    public delegate bool EP(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
}
"@

$cb = [CW+EP]{
    param($h, $l)
    $def = [CW]::FindWindowEx($h, [IntPtr]::Zero, "SHELLDLL_DefView", $null)
    if ($def -ne [IntPtr]::Zero) {
        Write-Output ("WorkerW=0x{0:X} visible={1}  DefView=0x{2:X} visible={3}" -f $h.ToInt64(), [CW]::IsWindowVisible($h), $def.ToInt64(), [CW]::IsWindowVisible($def))
    }
    return $true
}
[CW]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
