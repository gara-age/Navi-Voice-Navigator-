Set-Location $PSScriptRoot\..

Write-Host "Starting local server, background service, and Flutter app in separate windows..."

Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "$PWD\scripts\run_server.ps1"
Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "$PWD\scripts\run_background.ps1"
Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "$PWD\scripts\run_flutter.ps1"
