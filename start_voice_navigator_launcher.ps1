Set-Location $PSScriptRoot

try {
  powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\scripts\stop_background.ps1" | Out-Null
} catch {
}

Start-Process powershell -ArgumentList @(
  '-NoExit',
  '-ExecutionPolicy',
  'Bypass',
  '-File',
  "$PSScriptRoot\scripts\run_background.ps1"
)

Start-Sleep -Milliseconds 800

powershell -ExecutionPolicy Bypass -File .\start_flutter_gui.ps1
