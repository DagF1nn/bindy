# Installs Bindy with UI access (uiAccess) in C:\Program Files\Bindy. Must be run as administrator.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\install.ps1 [-Yes] [-NoAutostart]
# Why: Windows only gives UI access to signed programs in a folder ordinary users cannot write to. See SECURITY.md.
param([switch]$Yes, [switch]$NoAutostart)
$ErrorActionPreference = 'Stop'
$rot = Split-Path $PSScriptRoot
$dest = Join-Path $env:ProgramFiles 'Bindy'
$emne = 'CN=Bindy local signing'
$gamleEmner = @($emne, 'CN=Bindy lokal signering')   # the second name is from early versions
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run as administrator (Win+X, Terminal (Admin)).' }

# Everything that is built, shown and signed happens from a copy in Program Files (only an administrator can write there).
# Then no ordinary process can swap the files between the hash display and the signing.
$stage = Join-Path $dest 'staging'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item (Join-Path $rot 'host') $stage -Recurse; Copy-Item (Join-Path $rot 'src') $stage -Recurse
& "$PSScriptRoot\build.ps1" -Rot $stage | Out-Null
$exe = Join-Path $stage 'out\BindyStart.exe'; $skript = Join-Path $stage 'src\bindy.ps1'
Write-Host "This will be installed in $dest and given UI access:"
foreach ($f in $exe, $skript) { "  {0}  SHA-256 {1}" -f (Split-Path $f -Leaf), (Get-FileHash $f -Algorithm SHA256).Hash }
Write-Host "Compare the bindy.ps1 sum with the one on the release page on GitHub."
Write-Host "A self-signed certificate will also be made trusted on this machine. Read SECURITY.md first."
if (-not $Yes -and (Read-Host 'Continue? (y/N)') -notmatch '^[yY]') { Remove-Item $stage -Recurse -Force; 'Cancelled.'; return }

$cert = $null
try {
    Get-Process BindyStart -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $dest 'BindyStart.exe') } | Stop-Process -Force
    # The key cannot be exported and only lives in this script. The certificate goes straight to the stores (no file in TEMP to swap).
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $emne -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(2) -KeyExportPolicy NonExportable
    $offentlig = New-Object Security.Cryptography.X509Certificates.X509Certificate2(,$cert.RawData)
    foreach ($navn in 'Root', 'TrustedPublisher') {
        $lager = New-Object Security.Cryptography.X509Certificates.X509Store($navn, 'LocalMachine'); $lager.Open('ReadWrite')
        foreach ($gammel in @($lager.Certificates | Where-Object { $_.Subject -in $gamleEmner })) { $lager.Remove($gammel) }   # old Bindy certificates are removed
        $lager.Add($offentlig); $lager.Close()
    }
    Copy-Item $exe (Join-Path $dest 'BindyStart.exe') -Force; Copy-Item $skript (Join-Path $dest 'bindy.ps1') -Force
    $sig = Set-AuthenticodeSignature -FilePath (Join-Path $dest 'BindyStart.exe') -Certificate $cert -HashAlgorithm SHA256
    if ($sig.Status -ne 'Valid') { throw "The signature was not valid: $($sig.Status)" }
} finally {
    if ($cert) { Remove-Item $cert.PSPath -DeleteKey -Force -ErrorAction SilentlyContinue }   # certificate AND private key are always deleted, also on failure
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue }
}
if (-not $NoAutostart) {
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Bindy' -Value "`"$dest\BindyStart.exe`""
}
try { $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Bindy.lnk"); $lnk.TargetPath = "$dest\BindyStart.exe"; $lnk.WorkingDirectory = $dest; $lnk.IconLocation = "$dest\BindyStart.exe,0"; $lnk.Save() } catch { Write-Host "Could not make the Start menu shortcut: $_" }   # this is how you find Bindy in Start
Write-Host "Done. Start Bindy from the Start menu, or: & '$dest\BindyStart.exe'"
