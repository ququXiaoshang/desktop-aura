# Test: toggle desktop icons via ShowWindow on SysListView32 (no explorer restart).
# Finds the ListView robustly via EnumWindows/EnumChildWindows (works on Progman or WorkerW host).
# Verifies: hide -> show -> item count unchanged (list not broken).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File test-showwindow.ps1
# ASCII-only.
$ErrorActionPreference = 'Stop'

Add-Type -Namespace Win32 -Name Desk -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder sb, int n);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
'@

function Cls($h) { $sb = New-Object System.Text.StringBuilder 256; [void][Win32.Desk]::GetClassName($h, $sb, 256); return $sb.ToString() }

function Find-DesktopListView {
  $roots = New-Object System.Collections.ArrayList
  $cbRoot = [Win32.Desk+EnumProc]{ param($h,$l)
    $c = Cls $h
    if ($c -eq 'Progman' -or $c -eq 'WorkerW') { [void]$roots.Add($h) }
    return $true
  }
  [void][Win32.Desk]::EnumWindows($cbRoot, [IntPtr]::Zero)

  foreach ($r in $roots) {
    $found = [IntPtr]::Zero
    $cbChild = [Win32.Desk+EnumProc]{ param($h,$l)
      $c = Cls $h
      if ($c -eq 'SysListView32') { $script:found = $h; return $false }
      return $true
    }
    [void][Win32.Desk]::EnumChildWindows($r, $cbChild, [IntPtr]::Zero)
    if ($found -ne [IntPtr]::Zero) { return $found }
  }
  return [IntPtr]::Zero
}

$LVM_GETITEMCOUNT = 0x1004
$SW_HIDE = 0
$SW_SHOW = 5

$lv = Find-DesktopListView
if ($lv -eq [IntPtr]::Zero) { Write-Output 'FAIL: SysListView32 not found (icons likely hidden via registry)'; exit 1 }
Write-Output ("hwnd=0x" + $lv.ToString('X'))

$vis0 = [Win32.Desk]::IsWindowVisible($lv)
$count0 = [Win32.Desk]::SendMessage($lv, $LVM_GETITEMCOUNT, [IntPtr]::Zero, [IntPtr]::Zero).ToInt64()
Write-Output ("before: visible=$vis0  itemCount=$count0")

[Win32.Desk]::ShowWindow($lv, $SW_HIDE) | Out-Null
Start-Sleep -Milliseconds 600
$visHide = [Win32.Desk]::IsWindowVisible($lv)
Write-Output ("after HIDE: visible=$visHide")

[Win32.Desk]::ShowWindow($lv, $SW_SHOW) | Out-Null
Start-Sleep -Milliseconds 600
$visShow = [Win32.Desk]::IsWindowVisible($lv)
$count1 = [Win32.Desk]::SendMessage($lv, $LVM_GETITEMCOUNT, [IntPtr]::Zero, [IntPtr]::Zero).ToInt64()
Write-Output ("after SHOW: visible=$visShow  itemCount=$count1")

if ($visHide -eq $false -and $visShow -eq $true -and $count1 -eq $count0 -and $count1 -gt 0) {
  Write-Output 'RESULT: OK - toggle works, list intact'
} else {
  Write-Output 'RESULT: WARN - verify manually'
}
