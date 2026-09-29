# Rebuild runtime textures; retain the supplied full-resolution PNG sources.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$source = Join-Path $PSScriptRoot '../materials/ui/newUi'
$destination = Join-Path $source 'optimized'
New-Item -ItemType Directory -Force $destination | Out-Null
foreach ($file in Get-ChildItem -LiteralPath $source -Filter '*.png') {
    $outputName = if ($file.Name -eq 'fond.png') { 'fond_v2.png' } else { $file.Name }
    $image = [System.Drawing.Image]::FromFile($file.FullName)
    try {
        $limit = if ($file.Name -eq 'fond.png') { 1920 } elseif ($file.Name -in @('coter.png','cote2.png')) { 768 } elseif ($image.Width -gt $image.Height * 2) { 512 } else { 256 }
        $ratio = [math]::Min(1.0, $limit / [math]::Max($image.Width, $image.Height))
        if ($ratio -eq 1) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $destination $outputName) -Force; continue }
        $bitmap = New-Object System.Drawing.Bitmap ([int]($image.Width * $ratio)), ([int]($image.Height * $ratio))
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($image, 0, 0, $bitmap.Width, $bitmap.Height)
            $bitmap.Save((Join-Path $destination $outputName), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    } finally { $image.Dispose() }
}
Get-ChildItem -LiteralPath $destination | Measure-Object -Property Length -Sum

