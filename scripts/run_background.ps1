Set-Location $PSScriptRoot\..

function Test-PythonRuntime {
  param([string]$Executable)

  if (-not (Test-Path $Executable)) {
    return $false
  }

  & $Executable -c "import encodings"
  return $LASTEXITCODE -eq 0
}

if (Test-PythonRuntime ".\.venv-background\Scripts\python.exe") {
  .\.venv-background\Scripts\python.exe background_service/src/main.py
  exit 0
}

if (Get-Command py -ErrorAction SilentlyContinue) {
  try {
    py -3.14 background_service/src/main.py
    exit 0
  } catch {
  }

  try {
    py -3.11 background_service/src/main.py
    exit 0
  } catch {
  }
}

if (Get-Command python -ErrorAction SilentlyContinue) {
  python background_service/src/main.py
  exit 0
}

Write-Error "No working Python runtime was found. Run scripts/setup_background_env.ps1 first."
