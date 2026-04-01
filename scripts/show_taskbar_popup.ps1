param(
  [string]$Title = "Voice Navigator",
  [string]$Message = "알림",
  [int]$DurationMs = 5000,
  [string]$State = "info",
  [string]$ThemeMode = "light",
  [string]$LargeText = "0"
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function Get-PretendardFontFamily {
  $fontDir = 'C:\Users\USER\Desktop\voiceNavigator\app_flutter\assets\fonts'
  if (-not (Test-Path $fontDir)) {
    return New-Object System.Windows.Media.FontFamily('Segoe UI')
  }

  try {
    $uriPath = ($fontDir -replace '\\', '/')
    return New-Object System.Windows.Media.FontFamily("file:///$uriPath/#Pretendard")
  } catch {
    return New-Object System.Windows.Media.FontFamily('Segoe UI')
  }
}

function Convert-ToMediaColor {
  param([string]$Hex)

  if ([string]::IsNullOrWhiteSpace($Hex)) {
    return [System.Windows.Media.Color]::FromArgb(0, 0, 0, 0)
  }

  $trimmed = $Hex.Trim()
  if (-not $trimmed.StartsWith('#')) {
    return [System.Windows.Media.Color]::FromArgb(0, 0, 0, 0)
  }

  $value = $trimmed.Substring(1)
  if ($value.Length -eq 6) {
    return [System.Windows.Media.Color]::FromArgb(
      255,
      [Convert]::ToByte($value.Substring(0, 2), 16),
      [Convert]::ToByte($value.Substring(2, 2), 16),
      [Convert]::ToByte($value.Substring(4, 2), 16)
    )
  }

  if ($value.Length -eq 8) {
    return [System.Windows.Media.Color]::FromArgb(
      [Convert]::ToByte($value.Substring(0, 2), 16),
      [Convert]::ToByte($value.Substring(2, 2), 16),
      [Convert]::ToByte($value.Substring(4, 2), 16),
      [Convert]::ToByte($value.Substring(6, 2), 16)
    )
  }

  return [System.Windows.Media.Color]::FromArgb(0, 0, 0, 0)
}

function New-Brush {
  param([string]$Hex)
  return New-Object System.Windows.Media.SolidColorBrush((Convert-ToMediaColor -Hex $Hex))
}

function Convert-StrokeCap {
  param([string]$Value)
  switch ($Value) {
    'round' { return [System.Windows.Media.PenLineCap]::Round }
    'square' { return [System.Windows.Media.PenLineCap]::Square }
    default { return [System.Windows.Media.PenLineCap]::Flat }
  }
}

function Convert-StrokeJoin {
  param([string]$Value)
  switch ($Value) {
    'round' { return [System.Windows.Media.PenLineJoin]::Round }
    'bevel' { return [System.Windows.Media.PenLineJoin]::Bevel }
    default { return [System.Windows.Media.PenLineJoin]::Miter }
  }
}

function New-SvgViewbox {
  param(
    [string]$SvgPath,
    [string]$StrokeHex
  )

  $svg = [xml](Get-Content -Path $SvgPath -Raw)
  $parts = ($svg.svg.viewBox -split '\s+')
  $canvas = New-Object System.Windows.Controls.Canvas
  $canvas.Width = [double]$parts[2]
  $canvas.Height = [double]$parts[3]

  foreach ($node in $svg.svg.ChildNodes) {
    if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) {
      continue
    }

    $strokeBrush = New-Brush -Hex $StrokeHex
    $strokeWidth = if ($node.'stroke-width') { [double]$node.'stroke-width' } else { 2.0 }
    $lineCap = Convert-StrokeCap -Value $node.'stroke-linecap'
    $lineJoin = Convert-StrokeJoin -Value $node.'stroke-linejoin'

    switch ($node.Name) {
      'path' {
        $shape = New-Object System.Windows.Shapes.Path
        $shape.Data = [System.Windows.Media.Geometry]::Parse($node.d)
        $shape.Stroke = $strokeBrush
        $shape.StrokeThickness = $strokeWidth
        $shape.StrokeStartLineCap = $lineCap
        $shape.StrokeEndLineCap = $lineCap
        $shape.StrokeLineJoin = $lineJoin
        $shape.Fill = [System.Windows.Media.Brushes]::Transparent
        [void]$canvas.Children.Add($shape)
      }
      'rect' {
        $shape = New-Object System.Windows.Shapes.Rectangle
        $shape.Width = [double]$node.width
        $shape.Height = [double]$node.height
        $shape.RadiusX = if ($node.rx) { [double]$node.rx } else { 0 }
        $shape.RadiusY = if ($node.ry) { [double]$node.ry } else { $shape.RadiusX }
        $shape.Stroke = $strokeBrush
        $shape.StrokeThickness = $strokeWidth
        $shape.Fill = [System.Windows.Media.Brushes]::Transparent
        [System.Windows.Controls.Canvas]::SetLeft($shape, [double]$node.x)
        [System.Windows.Controls.Canvas]::SetTop($shape, [double]$node.y)
        [void]$canvas.Children.Add($shape)
      }
      'circle' {
        $shape = New-Object System.Windows.Shapes.Ellipse
        $r = [double]$node.r
        $shape.Width = $r * 2
        $shape.Height = $r * 2
        $shape.Stroke = $strokeBrush
        $shape.StrokeThickness = $strokeWidth
        $shape.Fill = [System.Windows.Media.Brushes]::Transparent
        [System.Windows.Controls.Canvas]::SetLeft($shape, ([double]$node.cx - $r))
        [System.Windows.Controls.Canvas]::SetTop($shape, ([double]$node.cy - $r))
        [void]$canvas.Children.Add($shape)
      }
      'line' {
        $shape = New-Object System.Windows.Shapes.Line
        $shape.X1 = [double]$node.x1
        $shape.Y1 = [double]$node.y1
        $shape.X2 = [double]$node.x2
        $shape.Y2 = [double]$node.y2
        $shape.Stroke = $strokeBrush
        $shape.StrokeThickness = $strokeWidth
        $shape.StrokeStartLineCap = $lineCap
        $shape.StrokeEndLineCap = $lineCap
        [void]$canvas.Children.Add($shape)
      }
    }
  }

  $viewbox = New-Object System.Windows.Controls.Viewbox
  $viewbox.Stretch = [System.Windows.Media.Stretch]::Uniform
  $viewbox.Child = $canvas
  return $viewbox
}

function Get-IconPath {
  param([string]$PopupState)

  switch ($PopupState.ToLowerInvariant()) {
    'listening' { return 'C:\Users\USER\Downloads\mic.svg' }
    'processing' { return 'C:\Users\USER\Downloads\cog.svg' }
    'success' { return 'C:\Users\USER\Downloads\square-check.svg' }
    'retry' { return 'C:\Users\USER\Downloads\rotate-ccw.svg' }
    'warning' { return 'C:\Users\USER\Downloads\hourglass.svg' }
    'error' { return 'C:\Users\USER\Downloads\ban.svg' }
    'apperror' { return 'C:\Users\USER\Downloads\triangle-alert.svg' }
    'secure' { return 'C:\Users\USER\Downloads\lock.svg' }
    'themedark' { return 'C:\Users\USER\Downloads\moon.svg' }
    'themecontrast' { return 'C:\Users\USER\Downloads\contrast.svg' }
    'themelargetext' { return 'C:\Users\USER\Downloads\zoom-in.svg' }
    default { return 'C:\Users\USER\Downloads\triangle-alert.svg' }
  }
}

function Get-StatePalette {
  param([string]$PopupState)

  switch ($PopupState.ToLowerInvariant()) {
    'listening' { return @{ Start = '#1F6FD9'; End = '#2875DF'; Accent = '#A9D8FF' } }
    'processing' { return @{ Start = '#0C7D96'; End = '#0AA1BC'; Accent = '#A6F3FF' } }
    'success' { return @{ Start = '#1B9446'; End = '#2DA65A'; Accent = '#C5FFD9' } }
    'retry' { return @{ Start = '#7A4B12'; End = '#9E5B12'; Accent = '#F2C694' } }
    'warning' { return @{ Start = '#7A4B12'; End = '#9E5B12'; Accent = '#F2C694' } }
    'error' { return @{ Start = '#CC3427'; End = '#EF3D34'; Accent = '#FFC3BC' } }
    'apperror' { return @{ Start = '#CC3427'; End = '#EF3D34'; Accent = '#FFC3BC' } }
    'secure' { return @{ Start = '#6738BF'; End = '#8658D4'; Accent = '#E1CAFF' } }
    'themedark' { return @{ Start = '#17202A'; End = '#0E151D'; Accent = '#C7D5E8' } }
    'themecontrast' { return @{ Start = '#000000'; End = '#000000'; Accent = '#FFF500' } }
    'themelargetext' { return @{ Start = '#1F6FD9'; End = '#377EE6'; Accent = '#C5DEFF' } }
    default { return @{ Start = '#303846'; End = '#4B5668'; Accent = '#D9E4F5' } }
  }
}

function Build-ThemePalette {
  param(
    [string]$PopupState,
    [string]$PopupTheme,
    [hashtable]$StatePalette
  )

  if ($PopupState -eq 'themedark') {
    return @{
      CardStart = '#17202A'
      CardEnd = '#0E151D'
      Title = '#FFFFFF'
      Message = '#D6DFEA'
      IconBackground = '#1FFFFFFF'
      CloseBackground = '#1AFFFFFF'
      ProgressTrack = '#24FFFFFF'
      ProgressFill = '#C7D5E8'
      Border = '#2D3A49'
    }
  }

  if ($PopupState -eq 'themecontrast' -or $PopupTheme -eq 'contrast') {
    return @{
      CardStart = '#000000'
      CardEnd = '#000000'
      Title = '#FFF500'
      Message = '#FFFFFF'
      IconBackground = '#15000000'
      CloseBackground = '#15000000'
      ProgressTrack = '#40FFF500'
      ProgressFill = '#FFF500'
      Border = '#FFF500'
    }
  }

  if ($PopupState -eq 'themelargetext') {
    return @{
      CardStart = '#1F6FD9'
      CardEnd = '#377EE6'
      Title = '#FFFFFF'
      Message = '#EFF6FF'
      IconBackground = '#20FFFFFF'
      CloseBackground = '#18FFFFFF'
      ProgressTrack = '#24FFFFFF'
      ProgressFill = '#FFFFFFFF'
      Border = '#00000000'
    }
  }

  if ($PopupTheme -eq 'dark') {
    return @{
      CardStart = '#17202A'
      CardEnd = '#0E151D'
      Title = '#FFFFFF'
      Message = '#D6DFEA'
      IconBackground = '#1FFFFFFF'
      CloseBackground = '#1AFFFFFF'
      ProgressTrack = '#24FFFFFF'
      ProgressFill = $StatePalette.Accent
      Border = '#2D3A49'
    }
  }

  return @{
    CardStart = $StatePalette.Start
    CardEnd = $StatePalette.End
    Title = '#FFFFFF'
    Message = '#EFF6FF'
    IconBackground = '#20FFFFFF'
    CloseBackground = '#18FFFFFF'
    ProgressTrack = '#24FFFFFF'
    ProgressFill = '#FFFFFFFF'
    Border = '#00000000'
  }
}

function Truncate-Message {
  param(
    [string]$Text,
    [int]$MaxChars
  )

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return ''
  }

  $single = ($Text -replace '\s+', ' ').Trim()
  if ($single.Length -le $MaxChars) {
    return $single
  }

  return ($single.Substring(0, $MaxChars - 3) + '...')
}

$isLargeText = $LargeText -match '^(1|true|yes)$'
$normalizedState = $State.ToLowerInvariant()
$normalizedTheme = $ThemeMode.ToLowerInvariant()
$statePalette = Get-StatePalette -PopupState $normalizedState
$themePalette = Build-ThemePalette -PopupState $normalizedState -PopupTheme $normalizedTheme -StatePalette $statePalette

$popupWidth = if ($isLargeText) { 378 } else { 360 }
$popupHeight = if ($isLargeText) { 120 } else { 104 }
$iconBoxSize = if ($isLargeText) { 48 } else { 42 }
$titleFontSize = if ($isLargeText) { 18.5 } else { 16.5 }
$messageFontSize = if ($isLargeText) { 13.5 } else { 12.2 }
$progressHeight = if ($isLargeText) { 5 } else { 4 }
$safeDuration = [Math]::Max($DurationMs, 1500)
$displayMessage = Truncate-Message -Text $Message -MaxChars $(if ($isLargeText) { 96 } else { 74 })

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="$popupWidth"
        Height="$popupHeight"
        AllowsTransparency="True"
        Background="Transparent"
        WindowStyle="None"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        ShowActivated="False"
        Topmost="True">
  <Grid>
    <Border x:Name="CardBorder"
            CornerRadius="26"
            BorderThickness="1"
            Padding="16,10,16,10">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid Grid.Row="0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="58"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="36"/>
          </Grid.ColumnDefinitions>
          <Border x:Name="IconBadge"
                  Grid.Column="0"
                  Width="$iconBoxSize"
                  Height="$iconBoxSize"
                  CornerRadius="15"
                  HorizontalAlignment="Left"
                  VerticalAlignment="Center"/>
          <Grid Grid.Column="1" Margin="8,0,12,0" VerticalAlignment="Center">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock x:Name="TitleText"
                       Grid.Row="0"
                       FontFamily="Segoe UI"
                       FontWeight="Bold"
                       FontSize="$titleFontSize"
                       VerticalAlignment="Center"
                       TextWrapping="NoWrap"
                       TextTrimming="CharacterEllipsis"/>
            <TextBlock x:Name="MessageText"
                       Grid.Row="1"
                       Margin="0,5,0,0"
                       FontFamily="Segoe UI"
                       FontWeight="SemiBold"
                       FontSize="$messageFontSize"
                       VerticalAlignment="Center"
                       TextWrapping="Wrap"
                       MaxHeight="32"/>
          </Grid>
          <Border x:Name="CloseBadge"
                  Grid.Column="2"
                  Width="32"
                  Height="32"
                  CornerRadius="14"
                  HorizontalAlignment="Right"
                  VerticalAlignment="Center"
                  Cursor="Hand"/>
        </Grid>
        <Border x:Name="ProgressTrack"
                Grid.Row="1"
                Margin="0,10,0,0"
                Height="$progressHeight"
                CornerRadius="0">
          <Grid>
            <Border x:Name="ProgressFill"
                    HorizontalAlignment="Left"
                    Height="$progressHeight"
                    CornerRadius="0"/>
          </Grid>
        </Border>
      </Grid>
    </Border>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$cardBorder = $window.FindName('CardBorder')
$iconBadge = $window.FindName('IconBadge')
$titleText = $window.FindName('TitleText')
$messageText = $window.FindName('MessageText')
$closeBadge = $window.FindName('CloseBadge')
$progressTrack = $window.FindName('ProgressTrack')
$progressFill = $window.FindName('ProgressFill')
$pretendardFont = Get-PretendardFontFamily

$window.FontFamily = $pretendardFont

$gradient = New-Object System.Windows.Media.LinearGradientBrush
$gradient.StartPoint = New-Object System.Windows.Point(0, 0)
$gradient.EndPoint = New-Object System.Windows.Point(1, 1)
$gradient.GradientStops.Add((New-Object System.Windows.Media.GradientStop((Convert-ToMediaColor -Hex $themePalette.CardStart), 0.0)))
$gradient.GradientStops.Add((New-Object System.Windows.Media.GradientStop((Convert-ToMediaColor -Hex $themePalette.CardEnd), 1.0)))

$cardBorder.Background = $gradient
$cardBorder.BorderBrush = New-Brush -Hex $themePalette.Border
$iconBadge.Background = New-Brush -Hex $themePalette.IconBackground
$closeBadge.Background = New-Brush -Hex $themePalette.CloseBackground
$progressTrack.Background = New-Brush -Hex $themePalette.ProgressTrack
$progressFill.Background = New-Brush -Hex $themePalette.ProgressFill

$titleText.Text = $Title
$messageText.Text = $displayMessage
$titleText.FontFamily = $pretendardFont
$messageText.FontFamily = $pretendardFont
$titleText.Foreground = New-Brush -Hex $themePalette.Title
$messageText.Foreground = New-Brush -Hex $themePalette.Message

$iconSvg = Get-IconPath -PopupState $normalizedState
if (Test-Path $iconSvg) {
  $iconBadge.Child = New-SvgViewbox -SvgPath $iconSvg -StrokeHex $themePalette.Title
}

$closeSvg = 'C:\Users\USER\Downloads\x.svg'
if (Test-Path $closeSvg) {
  $closeBadge.Child = New-SvgViewbox -SvgPath $closeSvg -StrokeHex $themePalette.Title
}

$screen = [System.Windows.SystemParameters]::WorkArea
$window.Left = $screen.Right - $popupWidth - 18
$window.Top = $screen.Bottom - $popupHeight - 18

$closeAction = {
  if ($window.IsVisible) {
    $window.Close()
  }
}

$closeBadge.Add_MouseLeftButtonUp({
  & $closeAction
})

$startTime = [DateTime]::UtcNow
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(40)

$updateProgress = {
  $elapsed = ([DateTime]::UtcNow - $startTime).TotalMilliseconds
  $ratio = [Math]::Min([Math]::Max($elapsed / $safeDuration, 0.0), 1.0)
  $progressFill.Width = $progressTrack.ActualWidth * (1.0 - $ratio)
  if ($ratio -ge 1.0) {
    $timer.Stop()
    & $closeAction
  }
}

$window.Add_ContentRendered({
  $progressFill.Width = $progressTrack.ActualWidth
  & $updateProgress
  $timer.Start()
})

$timer.Add_Tick({
  & $updateProgress
})

$window.ShowDialog() | Out-Null
