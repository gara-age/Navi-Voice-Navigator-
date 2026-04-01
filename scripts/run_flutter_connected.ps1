Set-Location $PSScriptRoot\..\app_flutter

$env:VOICE_NAVIGATOR_ROOT = (Resolve-Path "$PSScriptRoot\..").Path
$env:Path = 'C:\Program Files\Git\cmd;C:\src\flutter\bin;' + [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

$flutter = 'C:\src\flutter\bin\flutter.bat'
if (Test-Path $flutter) {
  & $flutter run -d windows -t lib\main_connected.dart
  exit 0
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "Flutter SDK was not found. Run scripts/setup_flutter_windows.ps1 after installing Flutter."
  exit 1
}

flutter run -d windows -t lib\main_connected.dart
