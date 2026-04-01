Set-Location $PSScriptRoot
$env:VOICE_NAVIGATOR_ROOT = (Resolve-Path $PSScriptRoot).Path
$exe = Join-Path $PSScriptRoot 'dist\demo\voice_navigator.exe'

powershell -ExecutionPolicy Bypass -File .\scripts\ensure_background_hidden.ps1

function Get-LatestSourceWriteTime {
  $paths = @(
    (Join-Path $PSScriptRoot 'app_flutter\lib'),
    (Join-Path $PSScriptRoot 'app_flutter\assets'),
    (Join-Path $PSScriptRoot 'app_flutter\pubspec.yaml')
  )

  $latest = Get-Date '2000-01-01'
  foreach ($path in $paths) {
    if (-not (Test-Path $path)) { continue }
    $items = if ((Get-Item $path) -is [System.IO.DirectoryInfo]) {
      Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
    } else {
      Get-Item -Path $path -ErrorAction SilentlyContinue
    }
    foreach ($item in $items) {
      if ($item.LastWriteTime -gt $latest) {
        $latest = $item.LastWriteTime
      }
    }
  }
  return $latest
}

if (Test-Path $exe) {
  $latestSource = Get-LatestSourceWriteTime
  $exeWriteTime = (Get-Item $exe).LastWriteTime
  if ($exeWriteTime -ge $latestSource) {
    Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
    exit 0
  }

  Write-Host "Source files are newer than the demo build. Launching current Flutter code..." -ForegroundColor Yellow
}

if (-not (Test-Path $exe)) {
  Write-Host "No built demo executable found. Launching current Flutter code..." -ForegroundColor Yellow
}

powershell -ExecutionPolicy Bypass -File .\scripts\run_flutter_demo.ps1
