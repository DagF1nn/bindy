# Installerer Bindy med UI-tilgang (uiAccess) i C:\Program Files\Bindy. Må kjøres som administrator.
# Bruk: powershell -ExecutionPolicy Bypass -File scripts\installer.ps1 [-Ja] [-IkkeAutostart]
# Hvorfor: Windows gir bare UI-tilgang til signerte program i en mappe vanlige brukere ikke kan skrive i. Se SECURITY.md.
param([switch]$Ja, [switch]$IkkeAutostart)
$ErrorActionPreference = 'Stop'
$rot = Split-Path $PSScriptRoot
$dest = Join-Path $env:ProgramFiles 'Bindy'
$emne = 'CN=Bindy lokal signering'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Kjør som administrator (Win+X, Terminal (administrator)).' }

# Alt som bygges, vises og signeres skjer fra en kopi i Program Files (bare administrator kan skrive der).
# Da kan ingen vanlig prosess bytte filene mellom hash-visningen og signeringen.
$stage = Join-Path $dest 'staging'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item (Join-Path $rot 'host') $stage -Recurse; Copy-Item (Join-Path $rot 'src') $stage -Recurse
& "$PSScriptRoot\bygg.ps1" -Rot $stage | Out-Null
$exe = Join-Path $stage 'out\BindyStart.exe'; $skript = Join-Path $stage 'src\bindy.ps1'
Write-Host "Dette installeres i $dest og gis UI-tilgang:"
foreach ($f in $exe, $skript) { "  {0}  SHA-256 {1}" -f (Split-Path $f -Leaf), (Get-FileHash $f -Algorithm SHA256).Hash }
Write-Host "Sammenlign bindy.ps1-summen med den som står på utgivelsessiden på GitHub."
Write-Host "Det legges også et selvsignert sertifikat som betrodd på denne maskinen. Les SECURITY.md først."
if (-not $Ja -and (Read-Host 'Fortsette? (j/N)') -notmatch '^[jJyY]') { Remove-Item $stage -Recurse -Force; 'Avbrutt.'; return }

$cert = $null
try {
    Get-Process BindyStart -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $dest 'BindyStart.exe') } | Stop-Process -Force
    # Nøkkelen kan ikke eksporteres og lever bare i dette skriptet. Sertifikatet går direkte til lagrene (ingen fil i TEMP å bytte ut).
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $emne -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(2) -KeyExportPolicy NonExportable
    $offentlig = New-Object Security.Cryptography.X509Certificates.X509Certificate2(,$cert.RawData)
    foreach ($navn in 'Root', 'TrustedPublisher') {
        $lager = New-Object Security.Cryptography.X509Certificates.X509Store($navn, 'LocalMachine'); $lager.Open('ReadWrite')
        foreach ($gammel in @($lager.Certificates | Where-Object { $_.Subject -eq $emne })) { $lager.Remove($gammel) }   # gamle Bindy-sertifikater fjernes
        $lager.Add($offentlig); $lager.Close()
    }
    Copy-Item $exe (Join-Path $dest 'BindyStart.exe') -Force; Copy-Item $skript (Join-Path $dest 'bindy.ps1') -Force
    $sig = Set-AuthenticodeSignature -FilePath (Join-Path $dest 'BindyStart.exe') -Certificate $cert -HashAlgorithm SHA256
    if ($sig.Status -ne 'Valid') { throw "Signeringen ble ikke gyldig: $($sig.Status)" }
} finally {
    if ($cert) { Remove-Item $cert.PSPath -DeleteKey -Force -ErrorAction SilentlyContinue }   # sertifikat OG privat nøkkel slettes alltid, også ved feil
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue }
}
if (-not $IkkeAutostart) {
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Bindy' -Value "`"$dest\BindyStart.exe`""
}
try { $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Bindy.lnk"); $lnk.TargetPath = "$dest\BindyStart.exe"; $lnk.WorkingDirectory = $dest; $lnk.IconLocation = "$dest\BindyStart.exe,0"; $lnk.Save() } catch { Write-Host "Snarvei i Startmenyen feilet: $_" }   # slik finner du Bindy i Start
Write-Host "Ferdig. Start Bindy: & '$dest\BindyStart.exe'"
