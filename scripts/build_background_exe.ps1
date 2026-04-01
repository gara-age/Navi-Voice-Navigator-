Set-Location $PSScriptRoot\..

$projectRoot = (Resolve-Path .).Path
$env:VOICE_NAVIGATOR_ROOT = $projectRoot

function Test-PythonRuntime {
  param([string]$Executable)

  if (-not (Test-Path $Executable)) {
    return $false
  }

  & $Executable -c "import encodings"
  return $LASTEXITCODE -eq 0
}

$python = '.\.venv-background\Scripts\python.exe'
if (-not (Test-PythonRuntime $python)) {
  Write-Error "Background Python runtime is not ready. Run scripts/setup_background_env.ps1 first."
  exit 1
}

& $python -m pip install --upgrade pyinstaller
if ($LASTEXITCODE -ne 0) {
  Write-Error "Failed to install PyInstaller."
  exit 1
}

$spec = Join-Path $projectRoot 'background_service\navi_background.spec'
& $python -m PyInstaller --noconfirm --clean $spec
if ($LASTEXITCODE -ne 0) {
  Write-Error "PyInstaller build failed."
  exit 1
}

$sourceDir = Join-Path $projectRoot 'dist\Navi Background'
$sourceExe = Join-Path $projectRoot 'dist\Navi Background.exe'
$targetDir = Join-Path $projectRoot 'dist\background'

if (Test-Path $targetDir) {
  Remove-Item -LiteralPath $targetDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

if (Test-Path $sourceDir) {
  Copy-Item -Path (Join-Path $sourceDir '*') -Destination $targetDir -Recurse -Force
} elseif (Test-Path $sourceExe) {
  Copy-Item -LiteralPath $sourceExe -Destination (Join-Path $targetDir 'Navi Background.exe') -Force
} else {
  Write-Error "Background build output was not found."
  exit 1
}

Write-Host "Background build is ready: $targetDir"
