param(
  [ValidateSet('launcher', 'demo', 'connected', 'background', 'all')]
  [string]$Mode = 'all',
  [switch]$Zip,
  [switch]$Clean
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$appRoot = Join-Path $projectRoot 'app_flutter'
$distRoot = Join-Path $projectRoot 'dist'
$packagesRoot = Join-Path $distRoot 'packages'

Set-Location $appRoot

$env:VOICE_NAVIGATOR_ROOT = $projectRoot
$env:Path = 'C:\Program Files\Git\cmd;C:\src\flutter\bin;C:\Python311;C:\Python311\Scripts;' +
  [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
  [Environment]::GetEnvironmentVariable('Path', 'User')

$flutter = 'C:\src\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter) -and -not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error 'Flutter SDK was not found. Run scripts/setup_flutter_windows.ps1 after installing Flutter.'
  exit 1
}

function Invoke-Flutter {
  param(
    [string[]]$Arguments
  )

  if (Test-Path $flutter) {
    & $flutter @Arguments
  } else {
    flutter @Arguments
  }
}

function Reset-Directory {
  param(
    [string]$Path
  )

  if (Test-Path $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Get-GitCommit {
  try {
    $commit = git rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
      return $commit.Trim()
    }
  } catch {
  }

  return 'unknown'
}

function Write-BuildInfo {
  param(
    [string]$TargetDir,
    [string]$BuildName,
    [string]$EntryPoint
  )

  $content = @(
    "Name: $BuildName"
    "BuiltAt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "GitCommit: $(Get-GitCommit)"
    "EntryPoint: $EntryPoint"
    "Machine: $env:COMPUTERNAME"
  ) -join [Environment]::NewLine

  Set-Content -Path (Join-Path $TargetDir 'BUILD_INFO.txt') -Value $content -Encoding UTF8
}

function Build-ReleaseVariant {
  param(
    [string]$BuildName,
    [string]$DistFolder,
    [string]$EntryPoint
  )

  Write-Host "Building $BuildName release..." -ForegroundColor Cyan

  $arguments = @('build', 'windows', '--release')
  if ($EntryPoint -ne 'lib\main.dart') {
    $arguments += @('-t', $EntryPoint)
  }

  Invoke-Flutter -Arguments $arguments

  $sourceDir = Join-Path $appRoot 'build\windows\x64\runner\Release'
  $targetDir = Join-Path $distRoot $DistFolder

  if ($Clean) {
    Reset-Directory -Path $targetDir
  } else {
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
  }

  Copy-Item -Path (Join-Path $sourceDir '*') -Destination $targetDir -Recurse -Force
  Write-BuildInfo -TargetDir $targetDir -BuildName $BuildName -EntryPoint $EntryPoint

  if ($Zip) {
    New-Item -ItemType Directory -Force -Path $packagesRoot | Out-Null
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $zipPath = Join-Path $packagesRoot "Navi-Voice-Navigator-$DistFolder-release-$timestamp.zip"
    if (Test-Path $zipPath) {
      Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $targetDir '*') -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host "Created package: $zipPath" -ForegroundColor Green
  }

  Write-Host "$BuildName build is ready: $targetDir" -ForegroundColor Green
}

function Build-BackgroundVariant {
  Write-Host "Building Background release..." -ForegroundColor Cyan

  & "$projectRoot\scripts\build_background_exe.ps1"
  if ($LASTEXITCODE -ne 0) {
    throw "Background build failed"
  }

  $targetDir = Join-Path $distRoot 'background'
  Write-BuildInfo -TargetDir $targetDir -BuildName 'Background' -EntryPoint 'background_service/src/main.py'

  if ($Zip) {
    New-Item -ItemType Directory -Force -Path $packagesRoot | Out-Null
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $zipPath = Join-Path $packagesRoot "Navi-Background-release-$timestamp.zip"
    if (Test-Path $zipPath) {
      Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $targetDir '*') -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host "Created package: $zipPath" -ForegroundColor Green
  }

  Write-Host "Background build is ready: $targetDir" -ForegroundColor Green
}

$variants = switch ($Mode) {
  'launcher' {
    @(@{ Name = 'Launcher'; Dist = 'launcher'; Entry = 'lib\main.dart' })
  }
  'demo' {
    @(@{ Name = 'Demo'; Dist = 'demo'; Entry = 'lib\main_demo.dart' })
  }
  'connected' {
    @(@{ Name = 'Connected'; Dist = 'connected'; Entry = 'lib\main_connected.dart' })
  }
  'background' {
    @(@{ Name = 'Background'; Dist = 'background'; Entry = 'background_service/src/main.py' })
  }
  default {
    @(
      @{ Name = 'Launcher'; Dist = 'launcher'; Entry = 'lib\main.dart' },
      @{ Name = 'Demo'; Dist = 'demo'; Entry = 'lib\main_demo.dart' },
      @{ Name = 'Connected'; Dist = 'connected'; Entry = 'lib\main_connected.dart' },
      @{ Name = 'Background'; Dist = 'background'; Entry = 'background_service/src/main.py' }
    )
  }
}

foreach ($variant in $variants) {
  if ($variant.Dist -eq 'background') {
    Build-BackgroundVariant
    continue
  }

  Build-ReleaseVariant `
    -BuildName $variant.Name `
    -DistFolder $variant.Dist `
    -EntryPoint $variant.Entry
}

Write-Host 'Release build automation completed.' -ForegroundColor Yellow
