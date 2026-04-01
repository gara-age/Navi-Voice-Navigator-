Set-Location $PSScriptRoot\..\app_flutter

$projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$env:VOICE_NAVIGATOR_ROOT = $projectRoot
$env:Path = 'C:\Program Files\Git\cmd;C:\src\flutter\bin;C:\Python311;C:\Python311\Scripts;' + [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

$flutter = 'C:\src\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter) -and -not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "Flutter SDK was not found. Run scripts/setup_flutter_windows.ps1 after installing Flutter."
  exit 1
}

if (Test-Path $flutter) {
  & $flutter build windows
} else {
  flutter build windows
}

$sourceDir = Join-Path (Get-Location) 'build\windows\x64\runner\Release'
$targetDir = Join-Path $projectRoot 'dist\launcher'

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Path (Join-Path $sourceDir '*') -Destination $targetDir -Recurse -Force

Write-Host "Launcher build is ready: $targetDir"
