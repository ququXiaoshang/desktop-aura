# Test SHGetSetSettings: read current SHELLSTATE and check the fHideIcons bit.
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
public class ShellCfg {
    [DllImport("shell32.dll")]
    public static extern void SHGetSetSettings(ref SHELLSTATE ss, uint mask, bool bSet);
}
"@

$ss = New-Object SHELLSTATE
$ss.reserved = New-Object byte[] 128
$mask = [uint32]::MaxValue
[ShellCfg]::SHGetSetSettings([ref]$ss, $mask, $false)
Write-Output ("dwFlags = 0x{0:X8}" -f $ss.dwFlags)
Write-Output ("bit0 fShowAllObjects = {0}" -f (($ss.dwFlags -band 0x1) -ne 0))
Write-Output ("bit12 fHideIcons = {0}" -f (($ss.dwFlags -band 0x1000) -ne 0))
Write-Output ("bit15 = {0}" -f (($ss.dwFlags -band 0x8000) -ne 0))
