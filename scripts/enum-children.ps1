# Recursively enumerate child windows of the desktop DefView to find the icon list.
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class EC {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string n);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    public delegate bool EP(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
}
"@

$script:def = [IntPtr]::Zero
$cb = [EC+EP]{
    param($h, $l)
    $d = [EC]::FindWindowEx($h, [IntPtr]::Zero, "SHELLDLL_DefView", $null)
    if ($d -ne [IntPtr]::Zero) { $script:def = $d; return $false }
    return $true
}
[EC]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null

if ($script:def -eq [IntPtr]::Zero) { Write-Output "DefView NOT FOUND"; exit 0 }

$script:names = New-Object System.Collections.ArrayList
$enum = [EC+EnumProc]{
    param($h, $l)
    $sb = New-Object System.Text.StringBuilder 256
    [EC]::GetClassName($h, $sb, 256) | Out-Null
    $null = $script:names.Add(("0x{0:X} {1} visible={2}" -f $h.ToInt64(), $sb.ToString(), [EC]::IsWindowVisible($h)))
    return $true
}
[EC]::EnumChildWindows($script:def, $enum, [IntPtr]::Zero) | Out-Null

Write-Output ("DefView 0x{0:X} 的子窗口（共 {1} 个）:" -f $script:def.ToInt64(), $script:names.Count)
$script:names | ForEach-Object { Write-Output ("  " + $_) }
