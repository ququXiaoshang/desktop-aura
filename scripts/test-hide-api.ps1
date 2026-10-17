# Test: use SHGetSetSettings to hide/show desktop icons WITHOUT restarting Explorer.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
[StructLayout(LayoutKind.Sequential)]
public struct SHELLSTATE {
    public uint dwFlags;
    public uint dwWin32Version;
    public uint dwBuildNumber;
    public uint dwPlatformId;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 128)]
    public byte[] reserved;
}
public class ShellCfg2 {
    [DllImport("shell32.dll")]
    public static extern void SHGetSetSettings(ref SHELLSTATE ss, uint mask, bool bSet);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string n);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr h);
    public delegate bool EP(IntPtr h, IntPtr l);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EP cb, IntPtr l);
}
"@

function Get-DefViewVisible {
    $script:defVis = $null
    $cb = [ShellCfg2+EP]{
        param($h, $l)
        $d = [ShellCfg2]::FindWindowEx($h, [IntPtr]::Zero, "SHELLDLL_DefView", $null)
        if ($d -ne [IntPtr]::Zero) {
            $script:defVis = [ShellCfg2]::IsWindowVisible($d)
            return $false
        }
        return $true
    }
    [ShellCfg2]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
    return $script:defVis
}

$ss = New-Object SHELLSTATE
$ss.reserved = New-Object byte[] 128
$maskAll = [uint32]::MaxValue
[ShellCfg2]::SHGetSetSettings([ref]$ss, $maskAll, $false)

"当前 dwFlags = 0x$($ss.dwFlags.ToString('X8'))  当前 DefView visible = $(Get-DefViewVisible)"

# 隐藏：设置 bit15 (fHideIcons)
$ss.dwFlags = $ss.dwFlags -bor 0x8000
[ShellCfg2]::SHGetSetSettings([ref]$ss, [uint32]0x8000, $true)
Start-Sleep -Milliseconds 500
"隐藏后 DefView visible = $(Get-DefViewVisible)"

# 恢复：清除 bit15
$ss2 = New-Object SHELLSTATE
$ss2.reserved = New-Object byte[] 128
[ShellCfg2]::SHGetSetSettings([ref]$ss2, $maskAll, $false)
$ss2.dwFlags = $ss2.dwFlags -band (-bnot 0x8000)
[ShellCfg2]::SHGetSetSettings([ref]$ss2, [uint32]0x8000, $true)
Start-Sleep -Milliseconds 500
"恢复后 DefView visible = $(Get-DefViewVisible)"
