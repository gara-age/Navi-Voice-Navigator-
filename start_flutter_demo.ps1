Set-Location $PSScriptRoot
$env:VOICE_NAVIGATOR_ROOT = (Resolve-Path $PSScriptRoot).Path
$exe = Join-Path $PSScriptRoot 'dist\demo\voice_navigator.exe'

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

  Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
  exit 0
}

if (-not (Test-Path $exe)) {
  [System.Windows.MessageBox]::Show(
    "빌드된 demo 실행 파일을 찾을 수 없습니다.`n먼저 build_release_bundle.bat -Mode demo 또는 scripts\\build_flutter_demo.ps1 를 실행해주세요.",
    "Navi: Voice Navigator",
    [System.Windows.MessageBoxButton]::OK,
    [System.Windows.MessageBoxImage]::Information
  ) | Out-Null
  exit 1
}
