# List visible windows belonging to electron processes, with their size.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WCheck {
    public delegate bool EP(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L; public int T; public int R; public int B; }
}
"@

$pids = @(Get-Process electron -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.Id })
if ($pids.Count -eq 0) { Write-Output "NO_ELECTRON"; exit 0 }

$script:found = New-Object System.Collections.ArrayList
$cb = [WCheck+EP]{
    param($h, $l)
    $pid2 = [uint32]0
    [WCheck]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
    if ($pids -contains [int]$pid2) {
        $vis = [WCheck]::IsWindowVisible($h)
        $r = New-Object WCheck+RECT
        [WCheck]::GetWindowRect($h, [ref]$r) | Out-Null
        $w = $r.R - $r.L
        $hh = $r.B - $r.T
        $null = $script:found.Add("0x$($h.ToInt64().ToString('X')) visible=$vis size=${w}x${hh}")
    }
    return $true
}
[WCheck]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null

$script:found
