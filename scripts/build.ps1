# Builds BindyStart.exe (the launcher with UI access) with csc.exe, which ships with Windows. No SDK needed.
# -Rot: the folder that contains host\ (default: this repo). The installer builds from a copy only an administrator can write to.
param([string]$Rot = (Split-Path $PSScriptRoot))
$ut = Join-Path $Rot 'out'; New-Item -ItemType Directory -Force $ut | Out-Null
$sma = Get-ChildItem "$env:windir\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\*\System.Management.Automation.dll" |
    Sort-Object { [version]($_.Directory.Name -replace '^v([\d.]+)_.*', '$1') } -Descending | Select-Object -First 1
if (-not $sma) { throw 'Could not find System.Management.Automation (is Windows PowerShell 5.1 missing?)' }
$wpf = "$env:windir\Microsoft.NET\Framework64\v4.0.30319\WPF"   # UI Automation for the Superguide executor
& "$env:windir\Microsoft.NET\Framework64\v4.0.30319\csc.exe" -nologo -target:winexe -platform:x64 `
    "-win32manifest:$Rot\host\app.manifest" "-win32icon:$Rot\host\bindy.ico" "-reference:$($sma.FullName)" `
    "-reference:$wpf\UIAutomationClient.dll" "-reference:$wpf\UIAutomationTypes.dll" "-reference:$wpf\WindowsBase.dll" `
    "-out:$ut\BindyStart.exe" "$Rot\host\BindyHost.cs" "$Rot\host\Superguide.cs"
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
"Built: $ut\BindyStart.exe"
