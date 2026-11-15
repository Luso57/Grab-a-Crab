Add-Type -AssemblyName System.Drawing
$folder = 'C:\Grab a Crab\Crabmodels'
$items = Get-Content -LiteralPath "$folder\manifest.json" -Raw | ConvertFrom-Json
$tileWidth = 400
$tileHeight = 390
$titleFont = New-Object System.Drawing.Font 'Segoe UI', 23, ([System.Drawing.FontStyle]::Bold)
$font = New-Object System.Drawing.Font 'Segoe UI', 15, ([System.Drawing.FontStyle]::Bold)
$smallFont = New-Object System.Drawing.Font 'Segoe UI', 10
$white = [System.Drawing.Brushes]::White
$muted = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(177, 192, 211))
# Six columns keep all variants in one readable landscape sheet.
$sheet = New-Object System.Drawing.Bitmap (2400), (1250)
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$graphics.Clear([System.Drawing.Color]::FromArgb(20, 27, 39))
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.DrawString('CRAB COLLECTION  /  18 SKINS', $titleFont, $white, 22, 14)
$graphics.DrawString('Same base crab. Textured FBX exports.', $smallFont, $muted, 26, 55)
for ($i = 0; $i -lt $items.Count; $i++) {
    $x = ($i % 6) * $tileWidth
    $y = 85 + [math]::Floor($i / 6) * $tileHeight
    $img = [System.Drawing.Image]::FromFile("$folder\Previews\$($items[$i].name).png")
    $graphics.DrawImage($img, [int]($x + 5), [int]$y, 390, 341)
    $label = $items[$i].name -creplace 'Crab$', ' Crab'
    $graphics.DrawString($label, $font, $white, [single]($x + 15), [single]($y + 348))
    $img.Dispose()
}
$sheet.Save("$folder\CrabCollection.png", [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$sheet.Dispose()
$font.Dispose()
$titleFont.Dispose()
$smallFont.Dispose()
$muted.Dispose()
Write-Output 'Saved Crabmodels\CrabCollection.png'
