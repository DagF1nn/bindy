# Fjerner Bindy: program, sertifikater, oppstart og dine data. Må kjøres som administrator.
# Sletter bare filene Bindy selv lager i %LOCALAPPDATA%\Bindy (ingen rekursiv sletting av ukjente mapper, så en plantet junction ikke kan misbrukes).
param([switch]$BeholdData)
$ErrorActionPreference = 'Continue'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Kjør som administrator.' }
$dest = Join-Path $env:ProgramFiles 'Bindy'
Get-Process BindyStart -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $dest 'BindyStart.exe') } | Stop-Process -Force
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Bindy' -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Bindy.lnk" -ErrorAction SilentlyContinue
foreach ($navn in 'Root', 'TrustedPublisher') {
    $lager = New-Object Security.Cryptography.X509Certificates.X509Store($navn, 'LocalMachine'); $lager.Open('ReadWrite')
    foreach ($c in @($lager.Certificates | Where-Object { $_.Subject -eq 'CN=Bindy lokal signering' })) { $lager.Remove($c) }
    $lager.Close()
}
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue   # Program Files: bare administrator kan skrive her
if (-not $BeholdData) {
    $d = Join-Path $env:LOCALAPPDATA 'Bindy'
    if (Test-Path $d) {
        foreach ($f in 'bindy-oppgave.md', 'bindy-oppgave.forrige.md', 'bindy-feil.log', 'bindy-host-feil.log', 'bindy-del-utklipp') { Remove-Item (Join-Path $d $f) -Force -ErrorAction SilentlyContinue }
        $a = Join-Path $d 'bindy-arbeid'
        if ((Test-Path $a) -and -not ((Get-Item $a -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { Remove-Item $a -Recurse -Force -ErrorAction SilentlyContinue }
        Remove-Item $d -ErrorAction SilentlyContinue   # bare hvis den er tom
        if (Test-Path $d) { "Merk: $d inneholder filer Bindy ikke kjenner. Slett dem selv." }
    }
}
'Bindy er fjernet.'
