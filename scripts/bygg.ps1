# Bygger BindyStart.exe (starter med UI-tilgang) med csc.exe som følger med Windows. Ingen SDK trengs.
$rot = Split-Path $PSScriptRoot
$ut = Join-Path $rot 'out'; New-Item -ItemType Directory -Force $ut | Out-Null
$sma = Get-ChildItem "$env:windir\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\*\System.Management.Automation.dll" |
    Sort-Object { [version]($_.Directory.Name -replace '^v([\d.]+)_.*', '$1') } -Descending | Select-Object -First 1
if (-not $sma) { throw 'Fant ikke System.Management.Automation (Windows PowerShell 5.1 mangler?)' }
& "$env:windir\Microsoft.NET\Framework64\v4.0.30319\csc.exe" -nologo -target:winexe -platform:x64 `
    "-win32manifest:$rot\host\app.manifest" "-reference:$($sma.FullName)" "-out:$ut\BindyStart.exe" "$rot\host\BindyHost.cs"
if ($LASTEXITCODE -ne 0) { throw 'Bygging feilet' }
"Bygget: $ut\BindyStart.exe"
