Set-Location $PSScriptRoot
$env:VOICE_NAVIGATOR_ROOT = (Resolve-Path $PSScriptRoot).Path
$exe = Join-Path $PSScriptRoot 'dist\launcher\voice_navigator.exe'

if (Test-Path $exe) {
  Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
  exit 0
}

[void][Reflection.Assembly]::LoadWithPartialName('PresentationFramework')
[System.Windows.MessageBox]::Show(
  "빌드된 launcher 실행 파일을 찾을 수 없습니다.`n먼저 build_release_bundle.bat 또는 scripts\\build_flutter_launcher.ps1 를 실행해주세요.",
  "Navi: Voice Navigator",
  [System.Windows.MessageBoxButton]::OK,
  [System.Windows.MessageBoxImage]::Information
) | Out-Null
exit 1
