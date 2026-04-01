Set-Location $PSScriptRoot\..

$baseUrl = "http://127.0.0.1:18400"

Write-Host "Checking Voice Navigator local server..." -ForegroundColor Cyan

try {
  $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get
  Write-Host "Health:" ($health | ConvertTo-Json -Compress) -ForegroundColor Green
} catch {
  Write-Error "Health check failed. Is the server running on $baseUrl?"
  exit 1
}

try {
  $sessionBody = @{
    client = "smoke_test"
    trigger_source = "manual"
    mode = "general"
    locale = "ko-KR"
    accessibility = @{
      large_text = $true
      screen_reader_enabled = $true
    }
  } | ConvertTo-Json -Depth 5

  $session = Invoke-RestMethod `
    -Uri "$baseUrl/session/start" `
    -Method Post `
    -ContentType "application/json" `
    -Body $sessionBody

  Write-Host "Session started:" ($session | ConvertTo-Json -Compress) -ForegroundColor Green

  $textBody = @{
    session_id = $session.session_id
    text = "youtube cat videos search"
    mode = "general"
  } | ConvertTo-Json -Depth 5

  $command = Invoke-RestMethod `
    -Uri "$baseUrl/command/text" `
    -Method Post `
    -ContentType "application/json" `
    -Body $textBody

  Write-Host "Command response:" ($command | ConvertTo-Json -Depth 6) -ForegroundColor Green
} catch {
  Write-Error "API smoke test failed: $($_.Exception.Message)"
  exit 1
}

Write-Host "Local server smoke test completed." -ForegroundColor Cyan
