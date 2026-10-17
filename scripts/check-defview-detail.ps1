# Detailed check of the desktop icon list (DefView and its SysListView32 child).
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class CDD {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    public delegate bool EP(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
}
"@

$script:def = [IntPtr]::Zero
$script:defParent = [IntPtr]::Zero
$cb = [CDD+EP]{
    param($h, $l)
    $d = [CDD]::FindWindowEx($h, [IntPtr]::Zero, "SHELLDLL_DefView", $null)
    if ($d -ne [IntPtr]::Zero) {
        $script:def = $d
        $script:defParent = $h
        return $false
    }
    return $true
}
[CDD]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null

if ($script:def -eq [IntPtr]::Zero) {
    Write-Output "DefView: NOT FOUND (可能被销毁)"
} else {
    $list = [CDD]::FindWindowEx($script:def, [IntPtr]::Zero, "SysListView32", $null)
    Write-Output ("DefView = 0x{0:X}  exists={1} visible={2}" -f $script:def.ToInt64(), [CDD]::IsWindow($script:def), [CDD]::IsWindowVisible($script:def))
    Write-Output ("Parent  = 0x{0:X}" -f $script:defParent.ToInt64())
    if ($list -ne [IntPtr]::Zero) {
        Write-Output ("ListView = 0x{0:X}  visible={1}" -f $list.ToInt64(), [CDD]::IsWindowVisible($list))
    } else {
        Write-Output "ListView: NOT FOUND (图标列表控件不存在)"
    }
}
