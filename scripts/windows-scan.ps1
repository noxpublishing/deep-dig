# Disk inventory and deep scan for Windows. Read-only, needs no admin rights.
# Results are candidates, not verdicts: check each one before calling it junk.
# Written for Windows PowerShell 5.1 and PowerShell 7.
$ErrorActionPreference = 'SilentlyContinue'
$UserHome = $env:USERPROFILE
$Local = $env:LOCALAPPDATA
$Roaming = $env:APPDATA

function H($t) { Write-Output ''; Write-Output "=== $t ===" }
function SizeMB($p) {
    if (-not (Test-Path -LiteralPath $p)) { return 0 }
    $s = (Get-ChildItem -LiteralPath $p -Recurse -Force -File -Attributes !ReparsePoint | Measure-Object Length -Sum).Sum
    return [math]::Round(($s / 1MB), 0)
}
function TopDirs($root, $n) {
    Get-ChildItem -LiteralPath $root -Force -Directory -Attributes !ReparsePoint |
        ForEach-Object { [pscustomobject]@{ MB = (SizeMB $_.FullName); Last = $_.LastWriteTime.ToString('yyyy-MM-dd'); Pfad = $_.FullName } } |
        Sort-Object MB -Descending | Select-Object -First $n |
        ForEach-Object { '{0,8} MB  last used {1}  {2}' -f $_.MB, $_.Last, $_.Pfad }
}

H 'Disk and memory'
Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { '{0} {1:N1} GB free of {2:N1} GB' -f $_.DeviceID, ($_.FreeSpace / 1GB), ($_.Size / 1GB) }
$os = Get-CimInstance Win32_OperatingSystem
'{0}, Build {1}' -f $os.Caption, $os.BuildNumber
'RAM free {0:N1} GB of {1:N1} GB' -f ($os.FreePhysicalMemory / 1MB), ($os.TotalVisibleMemorySize / 1MB)
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 6 | ForEach-Object { '{0,8:N0} MB  {1}' -f ($_.WorkingSet64 / 1MB), $_.ProcessName }
foreach ($f in 'C:\hiberfil.sys', 'C:\pagefile.sys', 'C:\swapfile.sys', 'C:\Windows\MEMORY.DMP') {
    $i = Get-Item -LiteralPath $f -Force; if ($i) { '{0,8:N0} MB  {1}' -f ($i.Length / 1MB), $f }
}

H 'User folder (top 25)'
TopDirs $UserHome 25

H 'AppData Local (top 20)'
TopDirs $Local 20
H 'AppData Roaming (top 15)'
TopDirs $Roaming 15
H 'AppData LocalLow (top 6)'
TopDirs (Join-Path $UserHome 'AppData\LocalLow') 6

H 'Known hiding places'
$known = @($env:TEMP, 'C:\Windows\Temp', 'C:\Windows.old', 'C:\Windows\SoftwareDistribution\Download', 'C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization', 'C:\Windows\Minidump', 'C:\ProgramData\Package Cache', 'C:\ProgramData\Microsoft\Windows\WER', "$Local\CrashDumps", "$Local\Microsoft\Windows\INetCache", "$Local\Microsoft\Windows\Explorer", "$Local\D3DSCache", "$Local\NVIDIA\DXCache", "$Local\pip\Cache", "$Local\npm-cache", "$Roaming\npm-cache", "$UserHome\.nuget\packages", "$UserHome\.gradle", "$UserHome\.cargo\registry", "$UserHome\.m2", "$Local\Android\Sdk", "$UserHome\.android", "$Local\Docker", "$Roaming\Apple Computer\MobileSync\Backup", "$env:ProgramFiles\Steam\steamapps", "${env:ProgramFiles(x86)}\Steam\steamapps")
$known | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | ForEach-Object { [pscustomobject]@{ MB = (SizeMB $_); Pfad = $_ } } | Sort-Object MB -Descending | ForEach-Object { '{0,8} MB  {1}' -f $_.MB, $_.Pfad }
'Note: without admin rights, sizes of system folders are often too small.'

H 'Recycle Bin'
$rb = (New-Object -ComObject Shell.Application).Namespace(10)
if ($rb) { $items = $rb.Items(); $sum = 0; foreach ($i in $items) { $sum += $i.Size }; '{0} items, {1:N0} MB' -f $items.Count, ($sum / 1MB) }

H 'Single files of 300 MB and up'
Get-ChildItem -LiteralPath $UserHome -Recurse -Force -File -Attributes !ReparsePoint |
    Where-Object { $_.Length -gt 300MB -and $_.FullName -notmatch '\\node_modules\\|\\\.git\\|\\OneDrive\\|\\Google Drive\\' } |
    Sort-Object Length -Descending | Select-Object -First 30 |
    ForEach-Object { '{0,8:N0} MB  {1}  {2}' -f ($_.Length / 1MB), $_.LastWriteTime.ToString('yyyy-MM-dd'), $_.FullName }

H 'Old installers, images and VMs (20 MB and up)'
Get-ChildItem -LiteralPath $UserHome -Recurse -Force -File -Attributes !ReparsePoint -Include *.exe, *.msi, *.msix, *.iso, *.img, *.vhd, *.vhdx, *.vmdk, *.vdi, *.dmg, *.apk, *.nsp |
    Where-Object { $_.Length -gt 20MB -and $_.FullName -notmatch '\\node_modules\\|\\\.git\\|\\AppData\\Local\\Programs\\|\\OneDrive\\|\\Google Drive\\' } |
    Sort-Object Length -Descending | Select-Object -First 20 |
    ForEach-Object { '{0,8:N0} MB  {1}' -f ($_.Length / 1MB), $_.FullName }

H 'Zip next to its unpacked folder (20 MB and up)'
foreach ($r in "$UserHome\Downloads", "$UserHome\Desktop") {
    Get-ChildItem -LiteralPath $r -Filter *.zip -File | Where-Object { $_.Length -gt 20MB -and (Test-Path -LiteralPath ($_.FullName -replace '\.zip$', '')) } |
        ForEach-Object { '{0,8:N0} MB  {1}' -f ($_.Length / 1MB), $_.FullName }
}

H 'Build folders in projects idle for 60 days'
$cut = (Get-Date).AddDays(-60)
Get-ChildItem -LiteralPath $UserHome -Directory -Force -Recurse -Depth 4 -Attributes !ReparsePoint -Include node_modules, target, .next, .venv, venv, __pycache__, .gradle |
    Where-Object { $_.FullName -notmatch '\\node_modules\\|\\AppData\\|\\\.cargo\\|\\\.rustup\\' -and $_.Parent.LastWriteTime -lt $cut } |
    ForEach-Object { [pscustomobject]@{ MB = (SizeMB $_.FullName); Last = $_.Parent.LastWriteTime.ToString('yyyy-MM-dd'); Pfad = $_.FullName } } |
    Where-Object { $_.MB -ge 20 } | Sort-Object MB -Descending | Select-Object -First 25 |
    ForEach-Object { '{0,8} MB  project last active {1}  {2}' -f $_.MB, $_.Last, $_.Pfad }

H 'Installed programs (largest)'
$reg = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
$apps = Get-ItemProperty $reg | Where-Object { $_.DisplayName -and -not $_.SystemComponent }
$apps | Where-Object { $_.EstimatedSize } | Sort-Object EstimatedSize -Descending | Select-Object -First 20 |
    ForEach-Object { '{0,8:N0} MB  installed {1}  {2}' -f ($_.EstimatedSize / 1KB), $_.InstallDate, $_.DisplayName }
if (Get-Command winget -ErrorAction SilentlyContinue) { 'winget present: cross-check with "winget list".' }

H 'AppData with no recognizable program (20 MB and up)'
$names = ($apps.DisplayName + $apps.Publisher + (Get-Process).ProcessName + (Get-AppxPackage).Name) | Where-Object { $_ } | ForEach-Object { $_.ToLower() }
$skip = 'microsoft', 'packages', 'temp', 'programs', 'google', 'nvidia', 'd3dscache', 'crashdumps', 'connecteddevicesplatform', 'publishers', 'comms', 'placeholdertilelogofolder', 'virtualstore'
foreach ($root in $Local, $Roaming) {
    Get-ChildItem -LiteralPath $root -Force -Directory -Attributes !ReparsePoint | Where-Object {
        $n = $_.Name.ToLower(); ($skip -notcontains $n) -and -not ($names | Where-Object { $_.Contains($n) -or $n.Contains($_) } | Select-Object -First 1)
    } | ForEach-Object { [pscustomobject]@{ MB = (SizeMB $_.FullName); Last = $_.LastWriteTime.ToString('yyyy-MM-dd'); Pfad = $_.FullName } } |
        Where-Object { $_.MB -ge 20 } | Sort-Object MB -Descending | Select-Object -First 20 |
        ForEach-Object { '{0,8} MB  last used {1}  {2}' -f $_.MB, $_.Last, $_.Pfad }
}

H 'Services and autostart with no program'
Get-CimInstance Win32_Service | Where-Object { $_.PathName } | ForEach-Object {
    $p = if ($_.PathName -match '^"([^"]+)"') { $Matches[1] } else { ($_.PathName -split ' ')[0] }
    if ($p -and -not (Test-Path -LiteralPath $p)) { 'Service {0} -> missing: {1}' -f $_.Name, $p }
} | Select-Object -First 15
Get-CimInstance Win32_StartupCommand | Select-Object -First 25 | ForEach-Object { 'Autostart: {0}' -f $_.Name }

H 'WSL and Docker'
Get-ChildItem -LiteralPath "$Local\Packages" -Recurse -Filter ext4.vhdx -Force -File | ForEach-Object { '{0,8:N0} MB  {1}' -f ($_.Length / 1MB), $_.FullName }
Get-ChildItem -LiteralPath "$Local\Docker" -Recurse -Filter *.vhdx -Force -File | ForEach-Object { '{0,8:N0} MB  {1}' -f ($_.Length / 1MB), $_.FullName }
if (Get-Command docker -ErrorAction SilentlyContinue) { docker system df }

H 'Worktrees per project'
Get-ChildItem -LiteralPath $UserHome -Directory -Force -Attributes !ReparsePoint | ForEach-Object {
    $w = Join-Path $_.FullName '.claude\worktrees'; if (Test-Path -LiteralPath $w) { '{0,8} MB  {1}' -f (SizeMB $w), $w }
}
