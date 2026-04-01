@echo off
cd /d "%~dp0"
start "" powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File ".\start_flutter_gui.ps1"
