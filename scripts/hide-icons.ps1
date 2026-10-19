# Hide or show the system desktop icons.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File hide-icons.ps1 <0|1>   (0=show, 1=hide)
#
# Strategy (dual, same as DesktopIconToggle):
#   1) PRIMARY: ShowWindow(SW_HIDE/SW_SHOW) on the desktop SysListView32.
#      Instant toggle, NO explorer restart -> no white screen, no taskbar flash.
#      Keeps the ListView alive, so it can be shown again instantly.
#   2) FALLBACK: registry HideIcons + FWF_NOICONS + restart explorer.
#      Only used when the SysListView32 is missing (e.g. it was already destroyed).
#
# ASCII-only on purpose: powershell.exe 5.1 reads no-BOM .ps1 files as the ANSI codepage.
param([Parameter(Mandatory = $true)][int]$Hide)

$ErrorActionPreference = 'Stop'

Add-Type -Namespace Win32 -Name Icons -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder sb, int n);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
'@

function Get-Cls([IntPtr]$h) {
  $sb = New-Object System.Text.StringBuilder 256
  [void][Win32.Icons]::GetClassName($h, $sb, 256)
  return $sb.ToString()
}

# --- find the desktop SysListView32 (hosted under Progman or WorkerW) ---
$roots = New-Object System.Collections.ArrayList
$lvHits = New-Object System.Collections.ArrayList

$cbRoot = [Win32.Icons+EnumProc]{ param($h, $l)
  $c = Get-Cls $h
  if ($c -eq 'Progman' -or $c -eq 'WorkerW') { [void]$roots.Add($h) }
  return $true
}
[void][Win32.Icons]::EnumWindows($cbRoot, [IntPtr]::Zero)

foreach ($r in $roots) {
  $cbChild = [Win32.Icons+EnumProc]{ param($h, $l)
    if ((Get-Cls $h) -eq 'SysListView32') { [void]$lvHits.Add($h); return $false }
    return $true
  }
  [void][Win32.Icons]::EnumChildWindows($r, $cbChild, [IntPtr]::Zero)
  if ($lvHits.Count) { break }
}

$SW_HIDE = 0
$SW_SHOW = 5

if ($lvHits.Count -gt 0) {
  # PRIMARY: instant ShowWindow toggle, no explorer restart
  $lv = $lvHits[0]
  $cmd = if ($Hide -eq 1) { $SW_HIDE } else { $SW_SHOW }
  [Win32.Icons]::ShowWindow($lv, $cmd) | Out-Null
  $vis = [Win32.Icons]::IsWindowVisible($lv)
  Write-Output ("MODE=SW visible=" + $vis)
  exit 0
}

# --- FALLBACK: registry + restart explorer (ListView is missing) ---
$advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$bagPath = 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop'

$currentHide = (Get-ItemProperty -Path $advanced -Name HideIcons -ErrorAction SilentlyContinue).HideIcons
$bag = Get-ItemProperty -Path $bagPath -ErrorAction SilentlyContinue
$currentFF = 0
if ($bag -and $null -ne $bag.FFlags) { $currentFF = [int]$bag.FFlags }
$currentNoIcons = (($currentFF -band 0x1000) -ne 0)

$needChange = $false
if ($null -eq $currentHide -or [int]$currentHide -ne $Hide) { $needChange = $true }
if (($Hide -eq 1) -ne $currentNoIcons) { $needChange = $true }

if (-not $needChange) {
  Write-Output ("MODE=REG HideIcons=" + $Hide + " (already)")
  exit 0
}

Set-ItemProperty -Path $advanced -Name HideIcons -Value $Hide -Type DWord

if ($bag -and $null -ne $bag.FFlags) {
  $ff = [int]$bag.FFlags
  if ($Hide -eq 1) {
    $newFF = $ff -bor 0x1000
  } else {
    $newFF = $ff -band (-bnot 0x1000)
  }
  Set-ItemProperty -Path $bagPath -Name FFlags -Value $newFF -Type DWord
}

Stop-Process -Name explorer -Force

$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 200
  if (Get-Process explorer -ErrorAction SilentlyContinue) {
    Start-Sleep -Milliseconds 400
    break
  }
}

Write-Output ("MODE=REG HideIcons=" + $Hide)
