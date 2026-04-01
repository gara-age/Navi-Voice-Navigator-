Set-Location $PSScriptRoot\..\app_flutter

$flutter = 'C:\src\flutter\bin\flutter.bat'
if (Test-Path $flutter) {
  & $flutter config --enable-windows-desktop
  if (-not (Test-Path .\windows)) {
    & $flutter create . --platforms=windows
  }
  & $flutter pub get
  Write-Host "Flutter Windows workspace is ready."
  exit 0
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "Flutter SDK was not found. Install Flutter with Windows desktop support first."
  exit 1
}

flutter config --enable-windows-desktop

if (-not (Test-Path .\windows)) {
  flutter create . --platforms=windows
}

flutter pub get
Write-Host "Flutter Windows workspace is ready."
