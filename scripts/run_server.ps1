Set-Location $PSScriptRoot\..

function Test-PythonRuntime {
  param([string]$Executable)

  if (-not (Test-Path $Executable)) {
    return $false
  }

  & $Executable -c "import encodings"
  return $LASTEXITCODE -eq 0
}

if (Test-PythonRuntime ".\.venv-server\Scripts\python.exe") {
  .\.venv-server\Scripts\python.exe -m uvicorn local_server.app.main:app --host 127.0.0.1 --port 18400 --reload
  exit 0
}

if (Get-Command py -ErrorAction SilentlyContinue) {
  try {
    py -3.14 -m uvicorn local_server.app.main:app --host 127.0.0.1 --port 18400 --reload
    exit 0
  } catch {
  }

  try {
    py -3.13 -m uvicorn local_server.app.main:app --host 127.0.0.1 --port 18400 --reload
    exit 0
  } catch {
  }

  try {
    py -3.12 -m uvicorn local_server.app.main:app --host 127.0.0.1 --port 18400 --reload
    exit 0
  } catch {
  }

  try {
    py -3.11 -m uvicorn local_server.app.main:app --host 127.0.0.1 --port 18400 --reload
    exit 0
  } catch {
  }
}

if (Get-Command python -ErrorAction SilentlyContinue) {
  python -m uvicorn local_server.app.main:app --host 127.0.0.1 --port 18400 --reload
  exit 0
}

Write-Error "No working Python runtime was found. Run scripts/setup_server_env.ps1 after installing Python."
