Set-Location $PSScriptRoot\..

$targets = Get-CimInstance Win32_Process |
  Where-Object {
    ($_.Name -like 'python*.exe' -or $_.Name -like 'py*.exe') -and
    $_.CommandLine -and
    (
      $_.CommandLine -like '*background_service/src/main.py*' -or
      $_.CommandLine -like '*background_service\src\main.py*'
    )
  }

if (-not $targets) {
  Write-Host "No running Voice Navigator background process was found."
  exit 0
}

foreach ($process in $targets) {
  try {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
    Write-Host "Stopped background process: $($process.ProcessId)"
  } catch {
    Write-Warning "Failed to stop process: $($process.ProcessId)"
  }
}
