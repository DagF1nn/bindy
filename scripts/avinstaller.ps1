# Fjerner Bindy helt: program, sertifikater, oppstart og data. Må kjøres som administrator.
param([switch]$BeholdData)
$ErrorActionPreference = 'Continue'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Kjør som administrator.' }
Get-Process BindyStart -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Bindy' -ErrorAction SilentlyContinue
foreach ($navn in 'Root', 'TrustedPublisher') {
    $lager = New-Object Security.Cryptography.X509Certificates.X509Store($navn, 'LocalMachine'); $lager.Open('ReadWrite')
    foreach ($c in @($lager.Certificates | Where-Object { $_.Subject -eq 'CN=Bindy lokal signering' })) { $lager.Remove($c) }
    $lager.Close()
}
Remove-Item (Join-Path $env:ProgramFiles 'Bindy') -Recurse -Force -ErrorAction SilentlyContinue
if (-not $BeholdData) { Remove-Item (Join-Path $env:LOCALAPPDATA 'Bindy') -Recurse -Force -ErrorAction SilentlyContinue }
'Bindy er fjernet.'
