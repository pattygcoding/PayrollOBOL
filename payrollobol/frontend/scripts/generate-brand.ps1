Add-Type -AssemblyName System.Drawing
$bitmap = New-Object System.Drawing.Bitmap 128, 128
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#186449'))
$paper = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#f1f5e9'))
$accent = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#d9c88d'))
$ink = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#186449'))
$graphics.FillRectangle($paper, 31, 23, 66, 82)
$graphics.FillRectangle($accent, 31, 23, 12, 82)
$graphics.FillRectangle($ink, 54, 42, 29, 5)
$graphics.FillRectangle($ink, 54, 57, 29, 5)
$graphics.FillRectangle($ink, 54, 72, 18, 5)
$bitmap.Save((Join-Path $PSScriptRoot '../public/brand.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$ink.Dispose()
$accent.Dispose()
$paper.Dispose()
$graphics.Dispose()
$bitmap.Dispose()