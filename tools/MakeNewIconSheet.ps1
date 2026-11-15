param(
    [ValidateSet('Crab', 'Egg')]
    [string]$Kind
)

Add-Type -AssemblyName System.Drawing
$root = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\UI\new-crab-icons'
$files = @(Get-ChildItem -Path $root -Filter "*$Kind.png" | Sort-Object Name)
$sheet = New-Object System.Drawing.Bitmap(1080, 1080)
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$graphics.Clear([System.Drawing.Color]::FromArgb(255, 226, 184, 94))
$font = New-Object System.Drawing.Font('Arial', 12)
$brush = [System.Drawing.Brushes]::Black
for ($index = 0; $index -lt $files.Count; $index++) {
    $column = $index % 6
    $row = [math]::Floor($index / 6)
    $bitmap = [System.Drawing.Bitmap]::new($files[$index].FullName)
    $graphics.DrawImage($bitmap, [System.Drawing.Rectangle]::new($column * 180 + 5, $row * 180 + 5, 170, 150))
    $graphics.DrawString($files[$index].BaseName, $font, $brush, [float]($column * 180 + 6), [float]($row * 180 + 155))
    $bitmap.Dispose()
}
$output = Join-Path $env:TEMP ('New' + $Kind + 'IconSheet.png')
$sheet.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$sheet.Dispose()
$font.Dispose()
Write-Output $output
