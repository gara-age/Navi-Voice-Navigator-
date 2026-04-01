Set-Location $PSScriptRoot\..

function Test-BackgroundRunning {
  try {
    $processes = Get-Process -Name 'Navi Background','pythonw','python' -ErrorAction SilentlyContinue
    foreach ($process in $processes) {
      try {
        if ($process.ProcessName -eq 'Navi Background') {
          return $true
        }
      } catch {
      }
    }
  } catch {
  }

  return $false
}

function Start-HiddenBackground {
  $aliasedExe = '.\.venv-background\Scripts\Navi Background.exe'
  $pythonwExe = '.\.venv-background\Scripts\pythonw.exe'

  if (Test-Path $aliasedExe) {
    Start-Process -FilePath $aliasedExe -WindowStyle Hidden -WorkingDirectory $PWD -ArgumentList @(
      'background_service/src/main.py'
    )
    return
  }

  if (Test-Path $pythonwExe) {
    Copy-Item -LiteralPath $pythonwExe -Destination $aliasedExe -Force
    Start-Process -FilePath $aliasedExe -WindowStyle Hidden -WorkingDirectory $PWD -ArgumentList @(
      'background_service/src/main.py'
    )
    return
  }

  Start-Process powershell -WindowStyle Hidden -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    "$PWD\scripts\run_background.ps1"
  )
}

if (Test-BackgroundRunning) {
  exit 0
}

Start-HiddenBackground

Start-Sleep -Milliseconds 700
