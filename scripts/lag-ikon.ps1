# Lager host\bindy.ico (binders på mørk flate). Kjøres bare når ikonet skal endres; resultatet ligger i repoet.
Add-Type -AssemblyName System.Drawing
$ut = Join-Path (Split-Path $PSScriptRoot) 'host\bindy.ico'
$png = foreach ($s in 16, 32, 48, 256) {
    $bm = New-Object Drawing.Bitmap($s, $s, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bm); $g.SmoothingMode = 'AntiAlias'
    $r = $s * 0.22; $d = 2 * $r; $bk = New-Object Drawing.Drawing2D.GraphicsPath
    $bk.AddArc(0, 0, $d, $d, 180, 90); $bk.AddArc($s - $d - 1, 0, $d, $d, 270, 90); $bk.AddArc($s - $d - 1, $s - $d - 1, $d, $d, 0, 90); $bk.AddArc(0, $s - $d - 1, $d, $d, 90, 90); $bk.CloseFigure()
    $g.FillPath((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(20, 18, 30))), $bk)
    $g.DrawPath((New-Object Drawing.Pen([Drawing.Color]::FromArgb(143, 135, 194), [Math]::Max(1, $s / 32))), $bk)
    $h = $s * 0.72; $w = 0.42 * $h; $x = ($s - $w) / 2; $y = $s * 0.14   # samme form som Binders.Tegn i bindy.ps1
    $x1 = $x + 0.14 * $w; $x2 = $x + 0.5 * $w; $x3 = $x + 0.86 * $w; $R = ($x3 - $x1) / 2; $r1 = ($x2 - $x1) / 2; $yTop = $y + 0.04 * $h; $cy = $y + 0.68 * $h
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    $p.AddLine($x2, $y + 0.36 * $h, $x2, $cy); $p.AddArc($x1, $cy - $r1, 2 * $r1, 2 * $r1, 0, 180); $p.AddLine($x1, $cy, $x1, $yTop + $R)
    $p.AddArc($x1, $yTop, 2 * $R, 2 * $R, 180, 180); $p.AddLine($x3, $yTop + $R, $x3, $y + 0.86 * $h)
    $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(196, 192, 222), [Math]::Max(1.5, $s * 0.085)); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    $g.DrawPath($pen, $p); $g.Dispose()
    $ms = New-Object IO.MemoryStream; $bm.Save($ms, [Drawing.Imaging.ImageFormat]::Png); [pscustomobject]@{ S = $s; B = $ms.ToArray() }
}
$fs = [IO.File]::Create($ut); $w = New-Object IO.BinaryWriter($fs)
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$png.Count)
$off = 6 + 16 * $png.Count
foreach ($i in $png) { $w.Write([byte]($i.S % 256)); $w.Write([byte]($i.S % 256)); $w.Write([byte]0); $w.Write([byte]0); $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$i.B.Length); $w.Write([uint32]$off); $off += $i.B.Length }
foreach ($i in $png) { $w.Write($i.B) }
$w.Close(); "Lagde $ut"
