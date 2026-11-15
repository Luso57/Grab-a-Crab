Add-Type -AssemblyName System.Drawing
$folder='C:\Grab a Crab\Crabmodels'
$items=Get-Content -LiteralPath "$folder\manifest.json" -Raw | ConvertFrom-Json
$sheet=New-Object System.Drawing.Bitmap (2400),(1250)
$graphics=[System.Drawing.Graphics]::FromImage($sheet)
$graphics.Clear([System.Drawing.Color]::FromArgb(20,27,39))
$graphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$title=New-Object System.Drawing.Font 'Segoe UI',23,([System.Drawing.FontStyle]::Bold)
$labelFont=New-Object System.Drawing.Font 'Segoe UI',15,([System.Drawing.FontStyle]::Bold)
$small=New-Object System.Drawing.Font 'Segoe UI',10
$muted=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(177,192,211))
$graphics.DrawString('CRAB COLLECTION  /  BATCH 2',$title,[System.Drawing.Brushes]::White,22,14)
$graphics.DrawString('18 new skins. Same base crab. Embedded texture FBX exports.',$small,$muted,26,55)
for ($i=0;$i -lt $items.Count;$i++) {
    $x=($i%6)*400
    $y=85+[math]::Floor($i/6)*390
    $image=[System.Drawing.Image]::FromFile("$folder\Previews\$($items[$i].name).png")
    $graphics.DrawImage($image,[int]($x+5),[int]$y,390,341)
    $label=$items[$i].name -creplace '([a-z])([A-Z])','$1 $2'
    $graphics.DrawString($label,$labelFont,[System.Drawing.Brushes]::White,[single]($x+15),[single]($y+348))
    $image.Dispose()
}
$sheet.Save("$folder\CrabCollection.png",[System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$sheet.Dispose()
$title.Dispose()
$labelFont.Dispose()
$small.Dispose()
$muted.Dispose()
Write-Output 'Saved Crabmodels\CrabCollection.png'
