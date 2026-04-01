@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File ".\start_voice_navigator.ps1"
