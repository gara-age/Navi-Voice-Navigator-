@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\build_release_bundle.ps1" %*
