Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class CrabIconProcessor
{
    private static byte[] Pixels(Bitmap bitmap)
    {
        var rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
        var data = bitmap.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try
        {
            byte[] pixels = new byte[data.Stride * bitmap.Height];
            Marshal.Copy(data.Scan0, pixels, 0, pixels.Length);
            return pixels;
        }
        finally { bitmap.UnlockBits(data); }
    }

    private static Bitmap Standardize(Bitmap source)
    {
        var result = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(result))
            graphics.DrawImage(source, 0, 0, source.Width, source.Height);
        return result;
    }

    private static byte Clamp(double value) { return (byte)Math.Max(0, Math.Min(255, Math.Round(value))); }

    public static string Process(string name, string greenBase64, string magentaBase64, string directory)
    {
        using (var greenStream = new MemoryStream(Convert.FromBase64String(greenBase64)))
        using (var magentaStream = new MemoryStream(Convert.FromBase64String(magentaBase64)))
        using (var greenSource = new Bitmap(greenStream))
        using (var magentaSource = new Bitmap(magentaStream))
        using (var green = Standardize(greenSource))
        using (var magenta = Standardize(magentaSource))
        {
            if (green.Width != magenta.Width || green.Height != magenta.Height)
                throw new Exception("Capture dimensions differ for " + name);
            int width = green.Width, height = green.Height;
            byte[] a = Pixels(green), b = Pixels(magenta);
            var foreground = new Bitmap(width, height, PixelFormat.Format32bppArgb);
            var rect = new Rectangle(0, 0, width, height);
            var data = foreground.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            int minX = width, minY = height, maxX = -1, maxY = -1;
            try
            {
                byte[] output = new byte[data.Stride * height];
                for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++)
                {
                    int i = (y * width + x) * 4;
                    int difference = Math.Abs(a[i] - b[i]) + Math.Abs(a[i+1] - b[i+1]) + Math.Abs(a[i+2] - b[i+2]);
                    double opacity = Math.Max(0, Math.Min(1, 1.0 - difference / 765.0));
                    if (opacity < 0.08) continue;
                    int j = y * data.Stride + x * 4;
                    output[j+3] = Clamp(opacity * 255);
                    output[j] = Clamp(a[i] / opacity);
                    output[j+1] = Clamp((a[i+1] - 255 * (1 - opacity)) / opacity);
                    output[j+2] = Clamp(a[i+2] / opacity);
                    if (opacity > 0.25)
                    {
                        minX = Math.Min(minX, x); minY = Math.Min(minY, y);
                        maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
                    }
                }
                Marshal.Copy(output, 0, data.Scan0, output.Length);
            }
            finally { foreground.UnlockBits(data); }
            if (maxX <= minX || maxY <= minY) throw new Exception("No foreground in " + name);
            int side = Math.Max(maxX - minX + 1, maxY - minY + 1);
            side = (int)Math.Ceiling(side * 1.15);
            int centerX = (minX + maxX) / 2, centerY = (minY + maxY) / 2;
            var crop = new Rectangle(centerX - side / 2, centerY - side / 2, side, side);
            using (foreground)
            using (var fitted = new Bitmap(512, 512, PixelFormat.Format32bppArgb))
            using (var graphics = Graphics.FromImage(fitted))
            {
                graphics.Clear(Color.Transparent);
                graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                graphics.DrawImage(foreground, new Rectangle(0, 0, 512, 512), crop, GraphicsUnit.Pixel);
                byte[] fit = Pixels(fitted);
                byte[] final = new byte[fit.Length];
                for (int y = 0; y < 512; y++)
                for (int x = 0; x < 512; x++)
                {
                    bool nearby = false;
                    for (int dy = -4; dy <= 4 && !nearby; dy++)
                    for (int dx = -4; dx <= 4; dx++)
                    {
                        if (dx*dx + dy*dy > 16) continue;
                        int nx = x+dx, ny = y+dy;
                        if (nx>=0 && nx<512 && ny>=0 && ny<512 && fit[(ny*512+nx)*4+3] > 32)
                        { nearby = true; break; }
                    }
                    if (nearby) final[(y*512+x)*4+3] = 255;
                }
                using (var outlined = new Bitmap(512, 512, PixelFormat.Format32bppArgb))
                {
                    var finalData = outlined.LockBits(new Rectangle(0, 0, 512, 512), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                    try { Marshal.Copy(final, 0, finalData.Scan0, final.Length); }
                    finally { outlined.UnlockBits(finalData); }
                    using (var composite = Graphics.FromImage(outlined))
                        composite.DrawImageUnscaled(fitted, 0, 0);
                    string path = Path.Combine(directory, name + ".png");
                    outlined.Save(path, ImageFormat.Png);
                    return path;
                }
            }
        }
    }
}
'@

$iconDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\UI\new-crab-icons'
New-Item -ItemType Directory -Path $iconDirectory -Force | Out-Null
while ($null -ne ($line = [Console]::ReadLine())) {
    try {
        $item = ConvertFrom-Json $line
        $path = [CrabIconProcessor]::Process($item.name, $item.green, $item.magenta, $iconDirectory)
        [Console]::WriteLine("OK " + $path)
    } catch {
        [Console]::WriteLine("ERROR " + $_.Exception.Message)
    }
}
