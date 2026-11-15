Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class NewCrabIconNormalizer
{
    public static void Process(string path)
    {
        using (var source = new Bitmap(path))
        {
            int width = source.Width, height = source.Height;
            var rect = new Rectangle(0, 0, width, height);
            var data = source.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] pixels;
            try { pixels = new byte[data.Stride * height]; Marshal.Copy(data.Scan0, pixels, 0, pixels.Length); }
            finally { source.UnlockBits(data); }
            bool[] visited = new bool[width * height];
            int bestCount = 0, bestMinX = width, bestMinY = height, bestMaxX = -1, bestMaxY = -1;
            var queue = new Queue<int>();
            for (int start = 0; start < width * height; start++)
            {
                if (visited[start] || pixels[start * 4 + 3] < 80) continue;
                visited[start] = true;
                queue.Enqueue(start);
                int count = 0, minX = width, minY = height, maxX = -1, maxY = -1;
                while (queue.Count > 0)
                {
                    int current = queue.Dequeue(), x = current % width, y = current / width;
                    count++;
                    minX = Math.Min(minX, x); maxX = Math.Max(maxX, x);
                    minY = Math.Min(minY, y); maxY = Math.Max(maxY, y);
                    int[] neighbors = { x > 0 ? current - 1 : -1, x < width - 1 ? current + 1 : -1,
                        y > 0 ? current - width : -1, y < height - 1 ? current + width : -1 };
                    foreach (int next in neighbors)
                    {
                        if (next < 0 || visited[next] || pixels[next * 4 + 3] < 80) continue;
                        visited[next] = true;
                        queue.Enqueue(next);
                    }
                }
                if (count > bestCount)
                {
                    bestCount = count; bestMinX = minX; bestMinY = minY;
                    bestMaxX = maxX; bestMaxY = maxY;
                }
            }
            if (bestCount < 100) throw new Exception("No substantial foreground in " + path);
            int padding = (int)(Math.Max(bestMaxX - bestMinX, bestMaxY - bestMinY) * 0.22);
            int left = Math.Max(0, bestMinX - padding), top = Math.Max(0, bestMinY - padding);
            int right = Math.Min(width - 1, bestMaxX + padding), bottom = Math.Min(height - 1, bestMaxY + padding);
            int minKeepX = width, minKeepY = height, maxKeepX = -1, maxKeepY = -1;
            for (int y = 0; y < height; y++)
            for (int x = 0; x < width; x++)
            {
                int i = (y * width + x) * 4;
                if (x < left || x > right || y < top || y > bottom) pixels[i+3] = 0;
                else if (pixels[i+3] > 32)
                {
                    minKeepX = Math.Min(minKeepX, x); maxKeepX = Math.Max(maxKeepX, x);
                    minKeepY = Math.Min(minKeepY, y); maxKeepY = Math.Max(maxKeepY, y);
                }
            }
            int side = (int)Math.Ceiling(Math.Max(maxKeepX - minKeepX + 1, maxKeepY - minKeepY + 1) * 1.16);
            int cx = (minKeepX + maxKeepX) / 2, cy = (minKeepY + maxKeepY) / 2;
            using (var cleaned = new Bitmap(width, height, PixelFormat.Format32bppArgb))
            {
                var cleanedData = cleaned.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                try { Marshal.Copy(pixels, 0, cleanedData.Scan0, pixels.Length); }
                finally { cleaned.UnlockBits(cleanedData); }
                using (var output = new Bitmap(512, 512, PixelFormat.Format32bppArgb))
                using (var graphics = Graphics.FromImage(output))
                {
                    graphics.Clear(Color.Transparent);
                    graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    graphics.DrawImage(cleaned, new Rectangle(0, 0, 512, 512),
                        new Rectangle(cx - side / 2, cy - side / 2, side, side), GraphicsUnit.Pixel);
                    if (File.Exists(path + ".normalized")) File.Delete(path + ".normalized");
                    output.Save(path + ".normalized", ImageFormat.Png);
                }
            }
        }
        File.Copy(path + ".normalized", path, true);
        File.Delete(path + ".normalized");
    }
}
'@

$root = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\UI\new-crab-icons'
foreach ($file in Get-ChildItem -Path $root -Filter '*.png') {
    [NewCrabIconNormalizer]::Process($file.FullName)
}
Write-Output "Normalized $((Get-ChildItem -Path $root -Filter '*.png').Count) icons"
