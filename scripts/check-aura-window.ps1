# Check visibility of windows belonging to Aura processes.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class AW {
    public delegate bool EP(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
    [StructLayout(LayoutKind.Sequential)] public struct R { public int L; public int T; public int Rt; public int B; }
}
"@

$pids = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like '*Aura*' } | ForEach-Object { [int]$_.Id })
if ($pids.Count -eq 0) { Write-Output "NO_AURA_PROCESS"; exit 0 }
Write-Output ("Aura 进程数: " + $pids.Count)

$cb = [AW+EP]{
    param($h, $l)
    $p = [uint32]0
    [AW]::GetWindowThreadProcessId($h, [ref]$p) | Out-Null
    if ($pids -contains [int]$p) {
        $r = New-Object AW+R
        [AW]::GetWindowRect($h, [ref]$r) | Out-Null
        Write-Output ("0x{0:X} visible={1} size={2}x{3}" -f $h.ToInt64(), [AW]::IsWindowVisible($h), ($r.Rt - $r.L), ($r.B - $r.T))
    }
    return $true
}
[AW]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
