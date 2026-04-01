Set-Location $PSScriptRoot\..

if (Test-Path .\.venv-server) {
  Remove-Item .\.venv-server -Recurse -Force
}

function Initialize-ServerEnv {
  param(
    [string]$Launcher,
    [string[]]$Arguments,
    [string]$Label
  )

  try {
    & $Launcher @Arguments -m venv .venv-server
    if ($LASTEXITCODE -ne 0) {
      throw "venv creation failed"
    }

    .\.venv-server\Scripts\python -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
      throw "pip upgrade failed"
    }

    .\.venv-server\Scripts\python -m pip install -r local_server\requirements.txt
    if ($LASTEXITCODE -ne 0) {
      throw "requirements install failed"
    }

    .\.venv-server\Scripts\python -m playwright install chromium
    if ($LASTEXITCODE -ne 0) {
      throw "playwright install failed"
    }

    Write-Host "Server environment ready: .venv-server ($Label)"
    exit 0
  } catch {
    if (Test-Path .\.venv-server) {
      Remove-Item .\.venv-server -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

if (Get-Command py -ErrorAction SilentlyContinue) {
  Initialize-ServerEnv -Launcher "py" -Arguments @("-3.14") -Label "Python 3.14"
  Initialize-ServerEnv -Launcher "py" -Arguments @("-3.13") -Label "Python 3.13"
  Initialize-ServerEnv -Launcher "py" -Arguments @("-3.12") -Label "Python 3.12"
  Initialize-ServerEnv -Launcher "py" -Arguments @("-3.11") -Label "Python 3.11"
}

if (Get-Command python -ErrorAction SilentlyContinue) {
  Initialize-ServerEnv -Launcher "python" -Arguments @() -Label "python"
}

Write-Error "Python launcher was not found. Install Python 3.11+ first."
