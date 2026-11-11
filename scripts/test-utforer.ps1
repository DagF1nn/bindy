# Tests the Superguide executor (host\Superguide.cs). Runs against a test window it makes itself (its own process).
# Sends real mouse and keyboard input for about 30 seconds: do not touch the mouse or keyboard while it runs (touching them is itself a stop case).
# Usage: powershell -STA -ExecutionPolicy Bypass -File scripts\test-utforer.ps1
$ErrorActionPreference = 'Stop'
$rot = Split-Path $PSScriptRoot
Add-Type -AssemblyName System.Windows.Forms, UIAutomationClient, UIAutomationTypes, WindowsBase
Add-Type -Path (Join-Path $rot 'host\Superguide.cs') -ReferencedAssemblies System.Windows.Forms, UIAutomationClient, UIAutomationTypes, WindowsBase
Add-Type @"
using System.Runtime.InteropServices;
public static class TstKey { [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint fl, System.UIntPtr ex); }
"@
# The block lists are read from bindy.ps1 so the test uses exactly what the program uses.
$src = Get-Content (Join-Path $rot 'src\bindy.ps1') -Encoding UTF8
. ([scriptblock]::Create((($src | Where-Object { $_ -match '^\$(Sperret|SperretProsess) = ' }) -join "`n")))
$fe = 0
function Sjekk([string]$navn, $faktisk, [string]$forventetStart) {
    if ("$faktisk".StartsWith($forventetStart)) { "OK    $navn  ($faktisk)" } else { $script:fe++; "FEIL  $navn  forventet $forventetStart..., fikk: $faktisk" }
}

# 1. Before Init: everything refused
Sjekk 'ikke initialisert' ([SgUtforer]::Skriv('a')) 'FEIL:IKKE_KLAR'
[SgUtforer]::Init($Sperret, $SperretProsess)
[SgUtforer]::Tillat('SgTestForm')   # testvinduet må være på tillatelseslisten
[SgUtforer]::Start(40, 120)

# 2. Pure refusals (no input is sent)
Sjekk 'win+r nektes' ([SgUtforer]::Tast('win+r')) 'FEIL:UGYLDIG'
Sjekk 'ctrl+alt+delete nektes' ([SgUtforer]::Tast('ctrl+alt+delete')) 'FEIL:UGYLDIG'
Sjekk 'win+s nektes' ([SgUtforer]::Tast('win+s')) 'FEIL:UGYLDIG'
Sjekk 'win+e nektes' ([SgUtforer]::Tast('win+e')) 'FEIL:UGYLDIG'
Sjekk 'ctrl+shift+esc nektes' ([SgUtforer]::Tast('ctrl+shift+esc')) 'FEIL:UGYLDIG'
Sjekk 'delete krever Henrik' ([SgUtforer]::Tast('delete')) 'FEIL:KREVER_HENRIK'
Sjekk 'ctrl+enter krever Henrik' ([SgUtforer]::Tast('ctrl+enter')) 'FEIL:KREVER_HENRIK'
Sjekk 'alt+f4 krever Henrik' ([SgUtforer]::Tast('alt+f4')) 'FEIL:KREVER_HENRIK'
$bk = [SgUtforer].GetField('Bekreft', [Reflection.BindingFlags]'NonPublic,Static').GetValue($null)   # \b i en vanlig C#-streng var backspace: ordgrenser må virke
foreach ($n in 'Send', 'Send (Ctrl-Enter)', 'Run', 'Allow', 'Remove', 'Pay', 'Fjern', 'Kjør', 'Tillat', 'Pay now', 'Uninstall', 'Windows Security') { Sjekk "Bekreft treffer '$n'" ([string]$bk.IsMatch($n)) 'True' }
foreach ($n in 'Resend', 'Prune', 'Payload', 'Cancel', 'Save') { Sjekk "Bekreft treffer ikke '$n'" ([string]$bk.IsMatch($n)) 'False' }
$et = [SgUtforer].GetMethod('ErTillatt', [Reflection.BindingFlags]'NonPublic,Static')   # tillatelsesliste: (prosess, vindusklasse)
foreach ($c in @(@('chrome', '', 'True'), @('notepad', '', 'True'), @('ApplicationFrameHost', '', 'True'), @('explorer', 'Shell_TrayWnd', 'True'), @('explorer', 'Progman', 'True'), @('explorer', 'CabinetWClass', 'False'), @('powershell', '', 'False'), @('BindyStart', '', 'False'), @('regedit', '', 'False'), @('', '', 'False'), @('SgTestForm', '', 'True'))) { Sjekk "tillatt $($c[0]) $($c[1])" ([string]$et.Invoke($null, @($c[0], $c[1]))) $c[2] }
Sjekk 'ukjent tast' ([SgUtforer]::Tast('foo')) 'FEIL:UGYLDIG'
Sjekk 'dobbel modifikator' ([SgUtforer]::Tast('ctrl+ctrl+s')) 'FEIL:UGYLDIG'
Sjekk 'kontrolltegn i Skriv' ([SgUtforer]::Skriv("a`nb")) 'FEIL:UGYLDIG'
Sjekk 'for lang Skriv' ([SgUtforer]::Skriv('x' * 501)) 'FEIL:UGYLDIG'
Sjekk 'app: uninstall nektes' ([SgUtforer]::ApneApp('Contoso.Uninstall!App')) 'FEIL:UGYLDIG'
Sjekk 'app: ugyldige tegn' ([SgUtforer]::ApneApp("a;calc")) 'FEIL:UGYLDIG'
Sjekk 'scroll: ugyldig mengde' ([SgUtforer]::Scroll(10, 10, 'ned', 99)) 'FEIL:UGYLDIG'
Sjekk 'vent: for lang' ([SgUtforer]::Vent(99999)) 'FEIL:UGYLDIG'

# 3. Stop conditions
[SgUtforer]::Start(40, 120)
[SgUtforer]::Stopp()
$t = [Diagnostics.Stopwatch]::StartNew(); $r = [SgUtforer]::Vent(5000); $t.Stop()
Sjekk 'Stopp() stopper Vent' $r 'FEIL:STOPPET'
Sjekk '  ...innen 1 s' ($(if ($t.ElapsedMilliseconds -lt 1000) { 'FEIL:STOPPET' } else { "for sen: $($t.ElapsedMilliseconds) ms" })) 'FEIL:STOPPET'
[SgUtforer]::Start(40, 120); Start-Sleep -Milliseconds 100
[TstKey]::keybd_event(0x1B, 0, 0, [UIntPtr]::Zero)   # Esc held down
$r = [SgUtforer]::Vent(5000)
[TstKey]::keybd_event(0x1B, 0, 2, [UIntPtr]::Zero)
Sjekk 'Esc stopper Vent' $r 'FEIL:'   # either STOPPET:Esc or BRUKER_RORTE (the key press is input too): both stop
[SgUtforer]::Start(40, 120); Start-Sleep -Milliseconds 100   # GetLastInputInfo ticks about every 15 ms
[TstKey]::keybd_event(0x10, 0, 0, [UIntPtr]::Zero); [TstKey]::keybd_event(0x10, 0, 2, [UIntPtr]::Zero)   # "Henrik" taps Shift
Sjekk 'bruker rører tastatur' ([SgUtforer]::Vent(2000)) 'FEIL:BRUKER_RORTE'

# 4. Test window in its own process (the executor refuses to type into powershell itself, so the form cannot live in this script)
$dir = Join-Path $env:TEMP ('SgTest-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $dir | Out-Null
# (the form sends an Alt tap before SetForegroundWindow: that is what lets a background process take focus)
$cs = @'
using System; using System.Windows.Forms; using System.Runtime.InteropServices;
public static class P { [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] static extern void keybd_event(byte v, byte s, uint f, UIntPtr e);
 [STAThread] public static void Main(string[] a) {
  Form f = new Form(); f.Text = a[0]; f.Width = 420; f.Height = 260; f.StartPosition = FormStartPosition.CenterScreen; f.TopMost = true;
  TextBox pw = new TextBox(); pw.Name = "pw"; pw.UseSystemPasswordChar = true; pw.Left = 20; pw.Top = 20; f.Controls.Add(pw);
  TextBox tx = new TextBox(); tx.Name = "tx"; tx.Left = 20; tx.Top = 60; tx.Width = 300; f.Controls.Add(tx);
  Button b = new Button(); b.Name = "b"; b.Text = "Uninstall"; b.Left = 20; b.Top = 100; b.Width = 120; b.Height = 40; f.Controls.Add(b); f.ActiveControl = pw;
  f.Shown += delegate { keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero); SetForegroundWindow(f.Handle); f.Activate(); pw.Focus(); }; Application.Run(f); } }
'@
Set-Content (Join-Path $dir 'f.cs') $cs -Encoding UTF8
& "$env:windir\Microsoft.NET\Framework64\v4.0.30319\csc.exe" -nologo -target:winexe "-out:$dir\SgTestForm.exe" -reference:System.Windows.Forms.dll "$dir\f.cs" | Out-Null
Add-Type @"
using System.Runtime.InteropServices;
public static class TstFg { [DllImport("user32.dll")] static extern System.IntPtr GetForegroundWindow(); [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(System.IntPtr h, out uint p);
  public static uint Pid() { uint p; GetWindowThreadProcessId(GetForegroundWindow(), out p); return p; } }
"@
function Aapne([string]$tittel) {
    $pr = Start-Process "$dir\SgTestForm.exe" -ArgumentList "`"$tittel`"" -PassThru; Start-Sleep -Milliseconds 1200
    (New-Object -ComObject WScript.Shell).AppActivate($pr.Id) | Out-Null; Start-Sleep -Milliseconds 500
    if ([TstFg]::Pid() -ne $pr.Id) { $pr.Kill(); Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue; "AVBRUTT: testvinduet fikk ikke fokus (rørte noen PC-en?). Ingenting er sendt til andre vinduer."; exit 2 }   # never type into someone else's window
    return $pr
}
function Felt($pr, [string]$id) {   # WinForms fields have no useful AutomationId: pick by class and position (pw = upper EDIT, tx = lower EDIT, b = BUTTON)
    $pr.Refresh(); if ($pr.MainWindowHandle -eq 0) { throw 'test window has no handle' }
    $rotEl = [Windows.Automation.AutomationElement]::FromHandle($pr.MainWindowHandle)
    $alle = @($rotEl.FindAll('Descendants', [Windows.Automation.Condition]::TrueCondition))
    $kl = if ($id -eq 'b') { 'BUTTON' } else { 'EDIT' }
    $e = @($alle | Where-Object { $_.Current.ClassName -match $kl } | Sort-Object { $_.Current.BoundingRectangle.Y })[$(if ($id -eq 'tx') { 1 } else { 0 })]
    if (-not $e) { throw "test field $id not found" }
    $r = $e.Current.BoundingRectangle; return @{ el = $e; x = [int]($r.X + $r.Width / 2); y = [int]($r.Y + $r.Height / 2) }
}
Add-Type -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int SendMessage(System.IntPtr h, int m, int w, System.Text.StringBuilder l);' -Name TstMsg -Namespace Tst
function Verdi($f) { $sb = New-Object Text.StringBuilder 600; [void][Tst.TstMsg]::SendMessage([IntPtr]$f.el.Current.NativeWindowHandle, 0x000D, 600, $sb); $sb.ToString() }   # WM_GETTEXT

$pr = Aapne 'Min bank - Edge'; [SgUtforer]::Start(40, 120)
Sjekk 'sperret tittel (bank)' ([SgUtforer]::Skriv('hei')) 'FEIL:SPERRET'
$pr.Kill(); Start-Sleep -Milliseconds 300
$pr = Aapne 'Test form'; $pw = Felt $pr 'pw'; $tx = Felt $pr 'tx'; $ub = Felt $pr 'b'
[SgUtforer]::Start(40, 120)
Sjekk 'utenfor skjermen' ([SgUtforer]::Klikk(-99999, 5)) 'FEIL:UGYLDIG'
Sjekk 'knapp Uninstall krever Henrik' ([SgUtforer]::Klikk($ub.x, $ub.y)) 'FEIL:KREVER_HENRIK'
[SgUtforer]::Start(40, 120)
Sjekk 'klikk i passordfelt' ([SgUtforer]::Klikk($pw.x, $pw.y)) 'FEIL:PASSORDFELT'
Sjekk 'Skriv i passordfelt (fokus der fra start)' ([SgUtforer]::Skriv('hemmelig')) 'FEIL:PASSORDFELT'
[SgUtforer]::Start(40, 120)
[SgUtforer]::Start(40, 120); Sjekk 'Klikk i vanlig felt for å flytte fokus' ([SgUtforer]::Klikk($tx.x, $tx.y)) 'OK'
Sjekk 'Skriv æøå' ([SgUtforer]::Skriv('Hei æøå ÅØÆ ok')) 'OK'
Start-Sleep -Milliseconds 400
Sjekk '  ...teksten kom frem' (Verdi $tx) 'Hei æøå ÅØÆ ok'
Sjekk 'Tast home' ([SgUtforer]::Tast('home')) 'OK'
Sjekk 'Tast shift+end (modifikator)' ([SgUtforer]::Tast('shift+end')) 'OK'   # a WinForms TextBox has no Ctrl+A
Sjekk 'Tast backspace' ([SgUtforer]::Tast('backspace')) 'OK'
Start-Sleep -Milliseconds 400
Sjekk '  ...feltet er tomt' ("[" + (Verdi $tx) + "]") '[]'
Sjekk 'Klikk i tekstfelt' ([SgUtforer]::Klikk($tx.x, $tx.y)) 'OK'
Sjekk 'Dobbeltklikk' ([SgUtforer]::Dobbeltklikk($tx.x, $tx.y)) 'OK'
Sjekk 'FinnElement finner knapp' ([SgUtforer]::FinnElement('Uninstall')) 'OK:'
Sjekk 'FinnElement: finnes ikke' ([SgUtforer]::FinnElement('Finnes ikke her')) 'FEIL:IKKE_FUNNET'

# 5. Cap on steps
[SgUtforer]::Start(2, 120)
Sjekk 'tak: Skriv 1' ([SgUtforer]::Skriv('a')) 'OK'
Sjekk 'tak: Skriv 2' ([SgUtforer]::Skriv('b')) 'OK'
Sjekk 'tak: steg nådd' ([SgUtforer]::Skriv('c')) 'FEIL:TAK_STEG'
$pr.Kill(); Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue

if ($fe) { "`n$fe test(er) feilet."; exit 1 } else { "`nAlle tester OK." }
