@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File ".\start_flutter_connected.ps1"
