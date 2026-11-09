# Removes Bindy: program, certificates, startup entry and your data. Must be run as administrator.
# Only deletes the files Bindy itself makes in %LOCALAPPDATA%\Bindy (no recursive deletion of unknown folders, so a planted junction cannot be abused).
param([switch]$KeepData)
$ErrorActionPreference = 'Continue'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run as administrator.' }
$dest = Join-Path $env:ProgramFiles 'Bindy'
Get-Process BindyStart -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $dest 'BindyStart.exe') } | Stop-Process -Force
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Bindy' -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Bindy.lnk" -ErrorAction SilentlyContinue
foreach ($navn in 'Root', 'TrustedPublisher') {
    $lager = New-Object Security.Cryptography.X509Certificates.X509Store($navn, 'LocalMachine'); $lager.Open('ReadWrite')
    foreach ($c in @($lager.Certificates | Where-Object { $_.Subject -in 'CN=Bindy local signing', 'CN=Bindy lokal signering' })) { $lager.Remove($c) }   # the second name is from early versions
    $lager.Close()
}
Get-NetFirewallRule -DisplayName 'Bindy MCP' -ErrorAction SilentlyContinue | Remove-NetFirewallRule   # MCP over Tailscale (see install.ps1)
foreach ($l in @(netsh http show urlacl)) { if ($l -match 'http://(100\.\d+\.\d+\.\d+):47831/') { netsh http delete urlacl url="http://$($Matches[1]):47831/" | Out-Null } }
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue   # Program Files: only an administrator can write here
if (-not $KeepData) {
    $d = Join-Path $env:LOCALAPPDATA 'Bindy'
    if (Test-Path $d) {
        foreach ($f in 'bindy-oppgave.md', 'bindy-oppgave.forrige.md', 'bindy-feil.log', 'bindy-host-feil.log', 'bindy-del-utklipp', 'bindy-musefolger-av', 'bindy-settings.json', 'bindy-mcp-token.bin', 'bindy-sist.log') { Remove-Item (Join-Path $d $f) -Force -ErrorAction SilentlyContinue }
        $a = Join-Path $d 'bindy-arbeid'
        if ((Test-Path $a) -and -not ((Get-Item $a -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { Remove-Item $a -Recurse -Force -ErrorAction SilentlyContinue }
        Remove-Item $d -ErrorAction SilentlyContinue   # only if it is empty
        if (Test-Path $d) { "Note: $d contains files Bindy does not know about. Delete them yourself." }
    }
}
'Bindy has been removed.'
