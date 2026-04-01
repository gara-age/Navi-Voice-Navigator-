param(
  [string]$MemoBase64 = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms

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

if ([string]::IsNullOrWhiteSpace($MemoBase64)) {
  throw "memo_base64_missing"
}

$memoText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($MemoBase64))
$diarySuffix = [string]([char]0xC77C) + [char]0xAE30
$fileName = "$(Get-Date -Format 'yyyy-MM-dd')$diarySuffix.txt"
$savePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) $fileName
$steps = New-Object System.Collections.Generic.List[object]

try {
  [System.IO.File]::WriteAllText(
    $savePath,
    "",
    [System.Text.UTF8Encoding]::new($false)
  )

  Emit-Progress -Step 1 -Action "open_notepad" -Status "processing" -Detail (Decode-Text '\uBA54\uBAA8\uC7A5\uC744 \uC2E4\uD589\uD558\uB294 \uC911\uC785\uB2C8\uB2E4.')
  $process = Start-Process notepad.exe -ArgumentList "`"$savePath`"" -PassThru
  Start-Sleep -Milliseconds 1200
  $wshell = New-Object -ComObject WScript.Shell
  $null = $wshell.AppActivate($process.Id)
  Start-Sleep -Milliseconds 500
  $steps.Add((Emit-StepResult -Step 1 -Action "open_notepad" -Detail (Decode-Text '\uBA54\uBAA8\uC7A5\uC744 \uC5F4\uC5C8\uC2B5\uB2C8\uB2E4.')))

  Emit-Progress -Step 2 -Action "prepare_editor" -Status "processing" -Detail (Decode-Text '\uBA54\uBAA8\uC7A5 \uD3B8\uC9D1 \uC601\uC5ED\uC744 \uC900\uBE44\uD558\uB294 \uC911\uC785\uB2C8\uB2E4.')
  $null = $wshell.AppActivate($process.Id)
  Start-Sleep -Milliseconds 300
  $wshell.SendKeys("^a")
  Start-Sleep -Milliseconds 150
  $wshell.SendKeys("{DEL}")
  Start-Sleep -Milliseconds 250
  $steps.Add((Emit-StepResult -Step 2 -Action "prepare_editor" -Detail (Decode-Text '\uAE30\uC874 \uB0B4\uC6A9\uC744 \uBE44\uC6B0\uACE0 \uD3B8\uC9D1 \uC601\uC5ED\uC744 \uC900\uBE44\uD588\uC2B5\uB2C8\uB2E4.')))

  Emit-Progress -Step 3 -Action "paste_content" -Status "processing" -Detail (Decode-Text '\uC77C\uAE30 \uB0B4\uC6A9\uC744 \uC785\uB825\uD558\uB294 \uC911\uC785\uB2C8\uB2E4.')
  [System.Windows.Forms.Clipboard]::SetText($memoText)
  $null = $wshell.AppActivate($process.Id)
  Start-Sleep -Milliseconds 300
  $wshell.SendKeys("^v")
  Start-Sleep -Milliseconds 700
  $steps.Add((Emit-StepResult -Step 3 -Action "paste_content" -Detail (Decode-Text '\uC77C\uAE30 \uB0B4\uC6A9\uC744 \uC785\uB825\uD588\uC2B5\uB2C8\uB2E4.')))

  Emit-Progress -Step 4 -Action "save_file" -Status "processing" -Detail "$fileName $(Decode-Text '\uC774\uB984\uC73C\uB85C \uC800\uC7A5\uD558\uB294 \uC911\uC785\uB2C8\uB2E4.')"
  $null = $wshell.AppActivate($process.Id)
  Start-Sleep -Milliseconds 300
  $wshell.SendKeys("^s")
  Start-Sleep -Milliseconds 1200
  $steps.Add((Emit-StepResult -Step 4 -Action "save_file" -Detail "$fileName $(Decode-Text '\uC774\uB984\uC73C\uB85C \uC800\uC7A5\uD588\uC2B5\uB2C8\uB2E4.')"))

  Emit-Progress -Step 5 -Action "verify_saved_file" -Status "processing" -Detail (Decode-Text '\uC800\uC7A5\uB41C \uD30C\uC77C \uB0B4\uC6A9\uC744 \uD655\uC778\uD558\uB294 \uC911\uC785\uB2C8\uB2E4.')
  if (-not (Test-Path -LiteralPath $savePath)) {
    throw "saved_file_not_found"
  }

  Start-Sleep -Milliseconds 500
  $savedText = [System.IO.File]::ReadAllText($savePath, [System.Text.Encoding]::UTF8)
  if ([string]::IsNullOrWhiteSpace($savedText) -or $savedText.Length -lt 40) {
    throw "saved_file_content_mismatch"
  }

  $steps.Add((Emit-StepResult -Step 5 -Action "verify_saved_file" -Detail $savePath))

  Write-JsonLine @{
    kind = "result"
    payload = @{
      status = "success"
      scenario = "memo_notepad"
      steps = $steps
      file_name = $fileName
      saved_path = $savePath
      route_summary = "$fileName $(Decode-Text '\uD30C\uC77C\uB85C \uC800\uC7A5\uD588\uC2B5\uB2C8\uB2E4.')"
    }
  }
  Start-Sleep -Milliseconds 250
} catch {
  $reason = $_.Exception.Message
  Emit-Progress -Step ($steps.Count + 1) -Action "memo_notepad" -Status "error" -Detail "$((Decode-Text '\uBA54\uBAA8\uC7A5 \uC2DC\uB098\uB9AC\uC624\uAC00 \uC2E4\uD328\uD588\uC2B5\uB2C8\uB2E4:')) $reason" -PopupState "appError"
  Write-JsonLine @{
    kind = "result"
    payload = @{
      status = "error"
      scenario = "memo_notepad"
      reason = $reason
      steps = $steps
    }
  }
  Start-Sleep -Milliseconds 250
}
