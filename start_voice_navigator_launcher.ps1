Set-Location $PSScriptRoot
powershell -ExecutionPolicy Bypass -File .\scripts\ensure_background_hidden.ps1

powershell -ExecutionPolicy Bypass -File .\start_flutter_gui.ps1
