param()

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Decode-Text {
  param([string]$Escaped)
  return ('"' + $Escaped + '"' | ConvertFrom-Json)
}

function To-AsciiJson {
  param([string]$Text)
  $builder = New-Object System.Text.StringBuilder
  foreach ($char in $Text.ToCharArray()) {
    $code = [int][char]$char
    if ($code -gt 127) {
      [void]$builder.AppendFormat('\u{0:x4}', $code)
    } else {
      [void]$builder.Append($char)
    }
  }
  return $builder.ToString()
}

function Write-JsonLine {
  param([hashtable]$Data)
  $json = $Data | ConvertTo-Json -Compress -Depth 6
  [Console]::WriteLine((To-AsciiJson -Text $json))
  [Console]::Out.Flush()
}

function Emit-Progress {
  param(
    [int]$Step,
    [string]$Action,
    [string]$Status,
    [string]$Detail,
    [string]$PopupState = "processing"
  )

  Write-JsonLine @{
    kind = "progress"
    payload = @{
      step = $Step
      action = $Action
      status = $Status
      detail = $Detail
      popup_state = $PopupState
    }
  }
}

function Emit-StepResult {
  param(
    [int]$Step,
    [string]$Action,
    [string]$Detail
  )

  Emit-Progress -Step $Step -Action $Action -Status "success" -Detail $Detail -PopupState "success"
  return @{
    step = $Step
    action = $Action
    status = "success"
    detail = $Detail
  }
}

$steps = New-Object System.Collections.Generic.List[object]
$personalizeKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

try {
  Emit-Progress -Step 1 -Action "open_windows_settings" -Status "processing" -Detail (Decode-Text '\u0057\u0069\u006e\u0064\u006f\u0077\u0073 \uC124\uC815\uC758 \uC0C9\uC0C1 \uD654\uBA74\uC744 \uC5EC\uB294 \uC911\uC785\uB2C8\uB2E4.')
  Start-Process "ms-settings:colors"
  Start-Sleep -Milliseconds 1800
  $steps.Add((Emit-StepResult -Step 1 -Action "open_windows_settings" -Detail (Decode-Text '\u0057\u0069\u006e\u0064\u006f\u0077\u0073 \uC124\uC815\uC744 \uC5F4\uC5C8\uC2B5\uB2C8\uB2E4.')))

  $currentAppsUseLightTheme = (Get-ItemProperty -Path $personalizeKey -Name AppsUseLightTheme).AppsUseLightTheme
  $targetValue = if ($currentAppsUseLightTheme -eq 0) { 1 } else { 0 }
  $targetModeLabel = if ($targetValue -eq 0) {
    Decode-Text '\uB2E4\uD06C \uD14C\uB9C8'
  } else {
    Decode-Text '\uB77C\uC774\uD2B8 \uD14C\uB9C8'
  }

  Emit-Progress -Step 2 -Action "toggle_windows_theme" -Status "processing" -Detail "$targetModeLabel $((Decode-Text '\uB85C \uBCC0\uACBD\uD558\uB294 \uC911\uC785\uB2C8\uB2E4.'))"
  Set-ItemProperty -Path $personalizeKey -Name AppsUseLightTheme -Type DWord -Value $targetValue
  Set-ItemProperty -Path $personalizeKey -Name SystemUsesLightTheme -Type DWord -Value $targetValue
  Start-Sleep -Milliseconds 1000
  $steps.Add((Emit-StepResult -Step 2 -Action "toggle_windows_theme" -Detail "$targetModeLabel $((Decode-Text '\uB85C \uC804\uD658\uD588\uC2B5\uB2C8\uB2E4.'))"))

  Emit-Progress -Step 3 -Action "verify_theme_state" -Status "processing" -Detail (Decode-Text '\uBCC0\uACBD\uB41C \uD14C\uB9C8 \uAC12\uC744 \uD655\uC778\uD558\uB294 \uC911\uC785\uB2C8\uB2E4.')
  $appsUseLightTheme = (Get-ItemProperty -Path $personalizeKey -Name AppsUseLightTheme).AppsUseLightTheme
  $systemUsesLightTheme = (Get-ItemProperty -Path $personalizeKey -Name SystemUsesLightTheme).SystemUsesLightTheme
  if ($appsUseLightTheme -ne $targetValue -or $systemUsesLightTheme -ne $targetValue) {
    throw "theme_not_toggled"
  }
  $steps.Add((Emit-StepResult -Step 3 -Action "verify_theme_state" -Detail "$targetModeLabel $((Decode-Text '\uC801\uC6A9\uC744 \uD655\uC778\uD588\uC2B5\uB2C8\uB2E4.'))"))

  Write-JsonLine @{
    kind = "result"
    payload = @{
      status = "success"
      scenario = "windows_theme_toggle"
      target_mode = if ($targetValue -eq 0) { "dark" } else { "light" }
      steps = $steps
      route_summary = "$((Decode-Text '\u0057\u0069\u006e\u0064\u006f\u0077\u0073 \uD654\uBA74 \uBAA8\uB4DC\uB97C')) $targetModeLabel $((Decode-Text '\uB85C \uBCC0\uACBD\uD588\uC2B5\uB2C8\uB2E4.'))"
    }
  }
  Start-Sleep -Milliseconds 250
} catch {
  $reason = $_.Exception.Message
  Emit-Progress -Step ($steps.Count + 1) -Action "windows_theme_toggle" -Status "error" -Detail "$((Decode-Text '\u0057\u0069\u006e\u0064\u006f\u0077\u0073 \uD14C\uB9C8 \uBCC0\uACBD \uC2DC\uB098\uB9AC\uC624\uAC00 \uC2E4\uD328\uD588\uC2B5\uB2C8\uB2E4:')) $reason" -PopupState "appError"
  Write-JsonLine @{
    kind = "result"
    payload = @{
      status = "error"
      scenario = "windows_theme_toggle"
      reason = $reason
      steps = $steps
    }
  }
  Start-Sleep -Milliseconds 250
}
