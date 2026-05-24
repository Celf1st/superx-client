Add-Type -AssemblyName System.Drawing
$root = "C:\src\superx-dev\superx-client"

# Render an "SX" rounded-square mark of given size with a two-stop gradient.
function New-SXBitmap([int]$s, [System.Drawing.Color]$c1, [System.Drawing.Color]$c2, [System.Drawing.Color]$fg) {
  $bmp = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)

  $r = [float]($s * 0.22); $d = $r * 2
  $rect = New-Object System.Drawing.RectangleF(0, 0, $s, $s)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
  $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
  $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
  $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 60.0)
  $g.FillPath($brush, $path)

  $font = New-Object System.Drawing.Font("Arial", [float]($s * 0.40), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center; $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
  $tr = New-Object System.Drawing.RectangleF(0, [float]($s * -0.02), $s, $s)
  $fb = New-Object System.Drawing.SolidBrush($fg)
  $g.DrawString("SX", $font, $fb, $tr, $sf)
  $g.Dispose(); $brush.Dispose(); $fb.Dispose(); $font.Dispose(); $path.Dispose()
  return $bmp
}
function Get-Png($bmp) { $ms = New-Object System.IO.MemoryStream; $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); return ,$ms.ToArray() }

# Write a multi-size .ico from a hashtable {size -> pngbytes}
function Write-Ico($pngs, $sizes, $outPath) {
  $ms = New-Object System.IO.MemoryStream; $bw = New-Object System.IO.BinaryWriter($ms)
  $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
  $offset = 6 + (16 * $sizes.Count)
  foreach ($s in $sizes) {
    $len = $pngs[$s].Length; $wb = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$wb); $bw.Write([byte]$wb); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$len); $bw.Write([uint32]$offset); $offset += $len
  }
  foreach ($s in $sizes) { $bw.Write($pngs[$s]) }
  $bw.Flush(); [System.IO.File]::WriteAllBytes($outPath, $ms.ToArray())
  Write-Output ("  {0}  ({1} bytes)" -f (Split-Path $outPath -Leaf), $ms.Length)
}

# palettes
$violet1 = [System.Drawing.Color]::FromArgb(255,99,76,224);  $violet2 = [System.Drawing.Color]::FromArgb(255,28,22,56)
$green1  = [System.Drawing.Color]::FromArgb(255,46,204,113);  $green2  = [System.Drawing.Color]::FromArgb(255,16,82,54)
$gray1   = [System.Drawing.Color]::FromArgb(255,120,120,130); $gray2   = [System.Drawing.Color]::FromArgb(255,40,40,48)
$white   = [System.Drawing.Color]::White

# ---- 1) app icon + logo.svg (violet) ----
$appSizes = @(16,32,48,64,128,256); $appPng = @{}
foreach ($s in $appSizes) { $b = New-SXBitmap $s $violet1 $violet2 $white; $appPng[$s] = Get-Png $b; $b.Dispose() }
"app icon:"; Write-Ico $appPng $appSizes "$root\windows\runner\resources\app_icon.ico"
$b64 = [Convert]::ToBase64String($appPng[256])
$svg = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="256" height="256" viewBox="0 0 256 256"><image width="256" height="256" xlink:href="data:image/png;base64,' + $b64 + '"/></svg>'
[System.IO.File]::WriteAllText("$root\assets\images\logo.svg", $svg); "logo.svg ($($svg.Length) b)"

# ---- 2) tray icons (ico sizes 16/24/32/48 + 32 png) ----
$traySizes = @(16,24,32,48)
function Make-Tray($name, $c1, $c2) {
  $png = @{}; foreach ($s in $traySizes) { $b = New-SXBitmap $s $c1 $c2 $white; $png[$s] = Get-Png $b; $b.Dispose() }
  Write-Ico $png $traySizes "$root\assets\images\$name.ico"
  [System.IO.File]::WriteAllBytes("$root\assets\images\$name.png", $png[32])
}
"tray icons:"
Make-Tray "tray_icon"               $violet1 $violet2
Make-Tray "tray_icon_dark"          $violet1 $violet2
Make-Tray "tray_icon_connected"     $green1  $green2
Make-Tray "tray_icon_disconnected"  $gray1   $gray2
"DONE"
