# Full-flow icon extraction diagnosis (ExtractAssociatedIcon -> ToBitmap -> resize -> save).
Add-Type -AssemblyName System.Drawing

$files = @()
foreach ($dir in @("$env:USERPROFILE\Desktop", "$env:PUBLIC\Desktop")) {
    Get-ChildItem $dir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '^\.(lnk|url|exe)$' } |
        ForEach-Object { $files += $_ }
}

$sh = New-Object -ComObject WScript.Shell
$failCount = 0
$okCount = 0

foreach ($f in $files) {
    $source = $f.FullName
    $ext = $f.Extension.ToLower()
    if ($ext -eq '.lnk') {
        try {
            $lnk = $sh.CreateShortcut($f.FullName)
            $target = [string]$lnk.TargetPath
            $iconLoc = [string]$lnk.IconLocation
            $iconPath = ($iconLoc -split ',')[0]
            if ($iconPath -and (Test-Path $iconPath)) { $source = $iconPath }
            elseif ($target -and (Test-Path $target)) { $source = $target }
            else { $source = $target }
        } catch {}
    }

    if (-not (Test-Path $source)) {
        $failCount++
        Write-Output ("FAIL({0})  {1}  源不存在: {2}" -f 'missing', $f.Name, $source)
        continue
    }

    $stage = ""
    $ok = $false
    try {
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($source)
        if ($null -eq $icon) { $stage = 'ExtractAssociatedIcon=null' }
        else {
            try {
                $bmp = $icon.ToBitmap()
                $bmp64 = New-Object System.Drawing.Bitmap($bmp, 64, 64)
                $ms = New-Object System.IO.MemoryStream
                $bmp64.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                $ok = ($ms.Length -gt 0)
                $ms.Dispose()
                $bmp64.Dispose()
                $bmp.Dispose()
            } catch {
                $stage = 'ToBitmap/Save: ' + $_.Exception.Message
            }
            $icon.Dispose()
        }
    } catch {
        $stage = 'Extract: ' + $_.Exception.Message
    }

    if ($ok) { $okCount++ }
    else {
        $failCount++
        Write-Output ("FAIL({0})  {1}  {2}" -f $stage, $f.Name, $source)
    }
}

Write-Output ("--- ok={0} fail={1} ---" -f $okCount, $failCount)
