Set-Location $PSScriptRoot\..

if (Test-Path .\.venv-background) {
  Remove-Item .\.venv-background -Recurse -Force
}

function Initialize-BackgroundEnv {
  param(
    [string]$Launcher,
    [string[]]$Arguments,
    [string]$Label
  )

  try {
    & $Launcher @Arguments -m venv .venv-background
    if ($LASTEXITCODE -ne 0) {
      throw "venv creation failed"
    }

    .\.venv-background\Scripts\python -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
      throw "pip upgrade failed"
    }

    .\.venv-background\Scripts\python -m pip install -r background_service\requirements.txt
    if ($LASTEXITCODE -ne 0) {
      throw "requirements install failed"
    }

    Write-Host "Background environment ready: .venv-background ($Label)"
    exit 0
  } catch {
    if (Test-Path .\.venv-background) {
      Remove-Item .\.venv-background -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

if (Get-Command py -ErrorAction SilentlyContinue) {
  Initialize-BackgroundEnv -Launcher "py" -Arguments @("-3.14") -Label "Python 3.14"
  Initialize-BackgroundEnv -Launcher "py" -Arguments @("-3.13") -Label "Python 3.13"
  Initialize-BackgroundEnv -Launcher "py" -Arguments @("-3.12") -Label "Python 3.12"
  Initialize-BackgroundEnv -Launcher "py" -Arguments @("-3.11") -Label "Python 3.11"
}

if (Get-Command python -ErrorAction SilentlyContinue) {
  Initialize-BackgroundEnv -Launcher "python" -Arguments @() -Label "python"
}

Write-Error "Python launcher was not found. Install Python first."
