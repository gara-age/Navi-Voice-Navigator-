Set-Location $PSScriptRoot\..

function New-BackgroundExecutableAlias {
  $sourceExe = '.\.venv-background\Scripts\pythonw.exe'
  $targetExe = '.\.venv-background\Scripts\Navi Background.exe'

  if (Test-Path $sourceExe) {
    Copy-Item -LiteralPath $sourceExe -Destination $targetExe -Force
  }
}

function Remove-ExistingBackgroundEnv {
  if (-not (Test-Path .\.venv-background)) {
    return
  }

  Get-Process -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Path -like '*voiceNavigator*\.venv-background\Scripts\python.exe' -or
      $_.Path -like '*voiceNavigator*\.venv-background\Scripts\pythonw.exe' -or
      $_.Path -like '*voiceNavigator*\.venv-background\Scripts\Navi Background.exe'
    } |
    Stop-Process -Force -ErrorAction SilentlyContinue

  Start-Sleep -Milliseconds 500
  Remove-Item .\.venv-background -Recurse -Force -ErrorAction Stop
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

    New-BackgroundExecutableAlias

    Write-Host "Background environment ready: .venv-background ($Label)"
    exit 0
  } catch {
    if (Test-Path .\.venv-background) {
      Remove-Item .\.venv-background -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Remove-ExistingBackgroundEnv

$preferredPython314 = 'C:\Users\USER\AppData\Local\Python\pythoncore-3.14-64\python.exe'
if (Test-Path $preferredPython314) {
  Initialize-BackgroundEnv -Launcher $preferredPython314 -Arguments @() -Label "Python 3.14"
}

$directPython311 = 'C:\Python311\python.exe'
if (Test-Path $directPython311) {
  Initialize-BackgroundEnv -Launcher $directPython311 -Arguments @() -Label "Python 3.11"
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
