$ErrorActionPreference = 'Stop'
$disc = Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path (Join-Path $_.Root 'x64dbg.zip') } | Select-Object -First 1
if (-not $disc) { throw 'Tools disc not found' }
$target = 'C:\CTF-Tools'
New-Item -ItemType Directory -Force -Path $target | Out-Null
Expand-Archive -Path (Join-Path $disc.Root 'x64dbg.zip') -DestinationPath (Join-Path $target 'x64dbg') -Force
$sysinternalsUrl = 'https://download.sysinternals.com/files/SysinternalsSuite.zip'
$sysinternalsArchive = Join-Path $target 'SysinternalsSuite.zip'
$answer = Read-Host "Download Sysinternals from Microsoft now? [y/N]"
if ($answer -match '^[Yy]$') {
  Invoke-WebRequest -Uri $sysinternalsUrl -OutFile $sysinternalsArchive
  Expand-Archive -Path $sysinternalsArchive -DestinationPath (Join-Path $target 'Sysinternals') -Force
  Remove-Item $sysinternalsArchive -Force
} else { Write-Output 'Sysinternals was skipped.' }
Write-Output "x64dbg installed in $target\x64dbg"
