# Bindy: en liten «øy» øverst på skjermen (som Dynamic Island) med en binders. Den vokser til et panel når du kaller på den.
#   Ctrl+Alt+H  = spør med skjermbilde av vinduet du står i.   Ctrl+Alt+J  = bare et spørsmål, uten skjerm.
#   Ctrl+Alt+P  = pause / fortsett (pausen stopper all skjermfangst og musehook).
#   Ctrl+Alt+N  = neste steg i veiledningen (samme som knappen «Neste steg»).
#   I panelet: «Skjerm» bytter mellom vindu / alle skjermer / av, «Pause», «Veiled meg» (eller Ctrl+Enter), Enter spør, Esc lukker.
# Trenger Claude mer enn bildet viser, ber den selv om bilde av alle skjermene (BEHOV: HELE_SKJERMEN), og spørsmålet sendes på nytt.
# VEILEDNING: Claude gir ett steg om gangen, en binders-peker (musepeker nr. 2) glir dit du skal trykke, og programmet følger
# med: etter klikk eller skjermendring sendes ett nytt bilde, Claude vurderer om steget er gjort og gir neste steg.
# Under veiledning blir øya en liten pille øverst med gjeldende steg. Klikk på den for å åpne panelet.
# Bare Windows PowerShell 5.1 og .NET (WinForms). Kjører Claude Code (Pro-kvoten), ingen API-nøkkel.
# Personvern: bildet fanges bare ved Ctrl+Alt+H, når «Skjerm» slås på, og under en veiledning du har startet selv. Under
# veiledning ser du det på bindersen i tray (grønn) og at øya er grønn. Sammenligning av skjermen skjer lokalt på små
# gråtonebilder som aldri lagres. Musehooken registrerer bare *hvor* du klikket, aldri taster, og kjører bare under veiledning.
# Vinduer med passord/bank i tittelen eller fra passordbehandlere fanges aldri; bilde av alle skjermer nektes så lenge et slikt vindu er synlig.
# --setting-sources project: Claude laster ikke brukerens globale CLAUDE.md (ca. 11 000 tokens per kall).
# Kontekst: skriptet limer inn %LOCALAPPDATA%\Bindy\bindy-oppgave.md (oppgavenotatet) i spørsmålet (Claude har ikke fil-tilgang) og skriver fremdrift nederst i den.
# Startes av brukeren selv (BindyStart.exe):
#   powershell -STA -File bindy.ps1          # kjører til du velger Avslutt i tray
#   powershell -STA -File bindy.ps1 -Sjekk   # selvsjekk uten vindu og uten å sende noe (tegner øya til en png)
#   powershell -STA -File bindy.ps1 -Prov    # fanger aktivt vindu og sender ÉN gang, skriver svaret
# snarvei: skjermendring sammenlignes på 32x20 gråtoner; en video i vinduet gjør at «stabil skjerm» aldri inntreffer.
# Da trigger bare klikk (1,8 s etter). Bør forbedres hvis det blir et problem.

param([switch]$Sjekk, [switch]$Prov)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$Mappe  = Join-Path $env:LOCALAPPDATA 'Bindy'   # all lagring ligger her (se PRIVACY.md)
New-Item -ItemType Directory -Force $Mappe | Out-Null
$FeilLogg = Join-Path $Mappe 'bindy-feil.log'; if ((Test-Path $FeilLogg) -and (Get-Item $FeilLogg).Length -gt 100000) { Remove-Item $FeilLogg -ErrorAction SilentlyContinue }   # snarvei: kuttes helt ved 100 kB, ingen rotasjon
$script:ClaudeSti = (Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source   # slås opp én gang ved oppstart
$Arbeid = Join-Path $Mappe 'bindy-arbeid'   # tom mappe: Claude leser ingen CLAUDE.md
$Notat  = Join-Path $Mappe 'bindy-oppgave.md'
New-Item -ItemType Directory -Force $Arbeid | Out-Null
$MaksBredde = 1280; $MaksBreddeAlle = 2000
$ModellSpør = 'sonnet'; $ModellSjekk = 'haiku'   # haiku er raskere og billigere til «er steget gjort?»
$MaksSjekker = 30; $StoppEtterMin = 5
$Sperret = 'passord|password|bank|bankid|vipps|vaultwarden|bitwarden|1password|keepass|lastpass|innlogging|logg inn|logg på|sign in|log in|id-porten|altinn|dnb|nordea|sparebank|handelsbanken|skatteetaten|helsenorge|paypal|revolut|nordnet|metamask|credential|windows-sikkerhet|wallet|lommebok|binance|coinbase|nettbank|sbanken|authenticator|seed phrase|recovery phrase|2fa'
$SperretProsess = 'keepass|keepassxc|1password|bitwarden|lastpass|bankid|nordpass|dashlane|enpass|protonpass|authy'
$script:klipp = New-Object Collections.ArrayList; $script:klippN = 0; $script:klippSendt = @(); $script:klippSist = $null; $script:klippSekv = 0; $script:sistFremme = [IntPtr]::Zero; $script:anbefalt = $false
$script:klippTid = New-Object Collections.ArrayList; $script:klippPinTil = $null; $script:klippSkjulTid = $null
# Utklippshistorikk: bare i minnet, maks 8 kopier, nyeste først. snarvei: polling hvert sekund i stedet for en utklippslytter, byttes ved behov.
# Deling av utklippshistorikken med Claude er AV som standard (personvern). Slås på i tray-menyen, valget huskes i en tom fil.
$script:delFil = Join-Path $Mappe 'bindy-del-utklipp'
$script:delKlipp = Test-Path $script:delFil
$script:musFil = Join-Path $Mappe 'bindy-musefolger-av'; $script:musPå = -not (Test-Path $script:musFil)   # musefølger på/av (fila finnes når den er av)
$script:musFade = 0; $script:musSist = ''
function Legg-Klipp([string]$t) {
    if ($t.Length -gt 2000) { return }   # sjekk lengden før regex, så enorme kopier ikke fryser lista
    $t = ($t -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', '').Trim()
    if (-not $t -or $t.Length -gt 400) { return }
    $i = $script:klipp.IndexOf($t); if ($i -ge 0) { $script:klipp.RemoveAt($i); $script:klippTid.RemoveAt($i) }
    $script:klipp.Insert(0, $t); $script:klippTid.Insert(0, [DateTime]::Now)
    while ($script:klipp.Count -gt 8) { $script:klipp.RemoveAt(8); $script:klippTid.RemoveAt(8) }
    $script:klippN = 0; $script:anbefalt = $false; Oppdater-Klipp
}
# Kopier eldre enn 60 min fjernes, så historikken ikke blir liggende og vokse.
function Rydd-Klipp {
    $fjernet = $false
    for ($i = $script:klipp.Count - 1; $i -ge 0; $i--) {
        if (([DateTime]::Now - $script:klippTid[$i]).TotalMinutes -gt 60) { $script:klipp.RemoveAt($i); $script:klippTid.RemoveAt($i); $fjernet = $true }
    }
    if ($fjernet) { $script:klippN = 0; Oppdater-Klipp }
}
# ---- Tegning uten overlapp: pilene flyttes rundt spissen, nummer og etiketter skyves til ledig plass.
function Ov-Krysser([double]$ax, [double]$ay, [double]$bx, [double]$by, [double]$cx, [double]$cy, [double]$dx, [double]$dy) {
    $d1 = ($bx - $ax) * ($cy - $ay) - ($by - $ay) * ($cx - $ax); $d2 = ($bx - $ax) * ($dy - $ay) - ($by - $ay) * ($dx - $ax)
    $d3 = ($dx - $cx) * ($ay - $cy) - ($dy - $cy) * ($ax - $cx); $d4 = ($dx - $cx) * ($by - $cy) - ($dy - $cy) * ($bx - $cx)
    return (($d1 * $d2 -lt 0) -and ($d3 * $d4 -lt 0))
}
function Ov-SegTreffer([double]$ax, [double]$ay, [double]$bx, [double]$by, $hind, [double]$tx, [double]$ty) {
    $n = [int][Math]::Max(3, [Math]::Sqrt(($bx - $ax) * ($bx - $ax) + ($by - $ay) * ($by - $ay)) / 6)
    for ($i = 0; $i -le $n; $i++) {
        $px = $ax + ($bx - $ax) * $i / $n; $py = $ay + ($by - $ay) * $i / $n
        if ([Math]::Abs($px - $tx) -lt 14 -and [Math]::Abs($py - $ty) -lt 14) { continue }   # nær spissen er det meningen å treffe målet
        foreach ($h in $hind) { if ($h.Contains([single]$px, [single]$py)) { return $true } }
    }
    return $false
}
function Ov-Treff($r, $hind) { foreach ($h in $hind) { if ($r.IntersectsWith($h)) { return $true } }; return $false }
function Ov-Rekt([double]$x, [double]$y, [double]$w, [double]$h) { return [Drawing.RectangleF]::new([single]$x, [single]$y, [single]$w, [single]$h) }
# $lst: former i skjermkoordinater (hashtabeller som endres på stedet). Rekkefølge: kanter og ringer, piler, nummer, etiketter.
function Ov-Plasser($lst, [double]$dpi) {
    $vs = [Windows.Forms.SystemInformation]::VirtualScreen; $vsF = Ov-Rekt $vs.X $vs.Y $vs.Width $vs.Height
    $hind = New-Object Collections.ArrayList; $e = 4 * $dpi
    foreach ($f in $lst) {
        if ($f.t -eq 'ramme') {
            $x1 = [Math]::Min($f.x1, $f.x2); $y1 = [Math]::Min($f.y1, $f.y2); $bw = [Math]::Abs($f.x2 - $f.x1); $bh = [Math]::Abs($f.y2 - $f.y1)
            [void]$hind.Add((Ov-Rekt ($x1 - $e) ($y1 - $e) ($bw + 2 * $e) (2 * $e))); [void]$hind.Add((Ov-Rekt ($x1 - $e) ($y1 + $bh - $e) ($bw + 2 * $e) (2 * $e)))
            [void]$hind.Add((Ov-Rekt ($x1 - $e) ($y1 - $e) (2 * $e) ($bh + 2 * $e))); [void]$hind.Add((Ov-Rekt ($x1 + $bw - $e) ($y1 - $e) (2 * $e) ($bh + 2 * $e)))
        } elseif ($f.t -eq 'sirkel') {
            for ($a = 0; $a -lt 360; $a += 20) { $rd = $a * [Math]::PI / 180; [void]$hind.Add((Ov-Rekt ($f.x + $f.r * [Math]::Cos($rd) - 5 * $dpi) ($f.y + $f.r * [Math]::Sin($rd) - 5 * $dpi) (10 * $dpi) (10 * $dpi))) }
        }
    }
    $piler = New-Object Collections.ArrayList
    foreach ($f in $lst) {
        if ($f.t -ne 'pil') { continue }
        $tx = $f.x2; $ty = $f.y2; $vx = $f.x1 - $tx; $vy = $f.y1 - $ty
        foreach ($gr in 0, 25, -25, 50, -50, 75, -75, 105, -105, 135, -135) {   # prøver andre startpunkter rundt spissen
            $rd = $gr * [Math]::PI / 180
            $sx = $tx + $vx * [Math]::Cos($rd) - $vy * [Math]::Sin($rd); $sy = $ty + $vx * [Math]::Sin($rd) + $vy * [Math]::Cos($rd)
            if (-not $vs.Contains([int]$sx, [int]$sy)) { continue }
            if (Ov-SegTreffer $sx $sy $tx $ty $hind $tx $ty) { continue }
            $kryss = $false
            foreach ($pp in $piler) { if (Ov-Krysser $sx $sy $tx $ty $pp[0] $pp[1] $pp[2] $pp[3]) { $kryss = $true; break } }
            if ($kryss) { continue }
            $f.x1 = [int]$sx; $f.y1 = [int]$sy; break
        }
        [void]$piler.Add(@($f.x1, $f.y1, $f.x2, $f.y2))
        $len = [Math]::Sqrt(($f.x2 - $f.x1) * ($f.x2 - $f.x1) + ($f.y2 - $f.y1) * ($f.y2 - $f.y1)); $n = [int][Math]::Max(2, $len / 8)
        for ($i = 0; $i -le $n; $i++) { [void]$hind.Add((Ov-Rekt ($f.x1 + ($f.x2 - $f.x1) * $i / $n - 5 * $dpi) ($f.y1 + ($f.y2 - $f.y1) * $i / $n - 5 * $dpi) (10 * $dpi) (10 * $dpi))) }
    }
    $forsk = @(@(0, 0), @(0, -30), @(30, 0), @(-30, 0), @(0, 30), @(30, -30), @(-30, -30), @(30, 30), @(-30, 30), @(0, -60), @(60, 0), @(-60, 0), @(0, 60))
    foreach ($f in $lst) {
        if ($f.t -ne 'nr') { continue }
        $rad = 15 * $dpi
        foreach ($o in $forsk) {
            $rx = $f.x + $o[0] * $dpi; $ry = $f.y + $o[1] * $dpi
            if (-not (Ov-Treff (Ov-Rekt ($rx - $rad) ($ry - $rad) (2 * $rad) (2 * $rad)) $hind)) { $f.x = [int]$rx; $f.y = [int]$ry; break }
        }
        [void]$hind.Add((Ov-Rekt ($f.x - $rad) ($f.y - $rad) (2 * $rad) (2 * $rad)))
    }
    $mg = $null; try { $mg = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero) } catch {}
    foreach ($f in $lst) {
        if ($f.t -ne 'tekst') { continue }
        $sz = $(if ($mg -and $fKnappFet) { $mg.MeasureString($f.s, $fKnappFet) } else { New-Object Drawing.SizeF((8 * $f.s.Length), 18) })
        $w = $sz.Width + 20 * $dpi; $h = $sz.Height + 8 * $dpi; $a = 12 * $dpi; $b = 8 * $dpi
        $kand = @(
            @(($f.x + $a), ($f.y - $h - $b)), @(($f.x - $w - $a), ($f.y - $h - $b)), @(($f.x + $a), ($f.y + 10 * $dpi)), @(($f.x - $w - $a), ($f.y + 10 * $dpi)),
            @(($f.x + 14 * $dpi), ($f.y - $h / 2)), @(($f.x - $w - 14 * $dpi), ($f.y - $h / 2)), @(($f.x - $w / 2), ($f.y - $h - 16 * $dpi)), @(($f.x - $w / 2), ($f.y + 16 * $dpi)),
            @(($f.x + $a), ($f.y - 2 * $h - 2 * $b)), @(($f.x - $w - $a), ($f.y - 2 * $h - 2 * $b)), @(($f.x + $a), ($f.y + $h + 2 * $b)), @(($f.x - $w - $a), ($f.y + $h + 2 * $b)))
        $val = $null; $innenfor = $null
        foreach ($c in $kand) {
            $r = Ov-Rekt $c[0] $c[1] $w $h
            if (-not $vsF.Contains($r)) { continue }
            if (-not $innenfor) { $innenfor = $c }
            if (-not (Ov-Treff $r $hind)) { $val = $c; break }
        }
        if (-not $val) { $val = $(if ($innenfor) { $innenfor } else { $kand[0] }) }
        $f.lx = [int]$val[0]; $f.ly = [int]$val[1]; $f.w = $w; $f.h = $h
        [void]$hind.Add((Ov-Rekt $f.lx $f.ly $w $h))
    }
    if ($mg) { $mg.Dispose() }
}
function Tøm-Klipp { $script:klipp.Clear(); $script:klippTid.Clear(); $script:klippN = 0; $script:anbefalt = $false; Oppdater-Klipp }
function Oppdater-Klipp {
    if ($null -ne $klippForm -and $klippForm.Visible) { Vis-Klipp $false }   # lista oppdateres mens den vises
}
$Systemprompt = 'Du er Bindy, brukerens hjelper på skjermen, en rolig og praktisk mentor. Når et skjermbilde er vedlagt, ser du vinduet (eller alle skjermene); ellers svarer du bare på spørsmålet. Svar på norsk, kort (maks 6 linjer, under veiledning bare 1-2 setninger): hva han ser og hva neste konkrete steg er. Vær konkret og gi svaret med en gang, er målet klart, svar med en gang uten å spørre tilbake. Spør bare når alternativene gir helt ulike resultater og du ikke kan avgjøre selv. Kan flere veier nå samme mål (for eksempel flere måter å åpne et program), velg selv den raskeste og enkleste og gå rett på sak uten å spørre. Må du spørre (flere apper, vinduer eller skjermer, eller et uklart mål), skriv STATUS: SPØRSMÅL først, ett kort spørsmål uten å liste alternativene i teksten, og så 2-4 alternativer som egne linjer [[VALG kort tekst]] (maks 40 tegn hver). brukeren trykker på en knapp, han skriver ikke. Ingen MARKER ved spørsmål. Prioritering: det brukeren skriver nå og det bildet viser går alltid foran bakgrunnsnotat og tidligere samtale; hold aldri fast på en gammel oppgave hvis han spør om noe annet. Bruk oppgavenotatet og tidligere spørsmål som kontekst. Gjengi aldri passord, kontonumre eller private meldinger. Hvis bildet ikke viser nok til å svare trygt (for eksempel et lite eller beskåret vindu, eller målet ikke er synlig), skriv BEHOV: HELE_SKJERMEN som første linje og ingenting mer, så får du bildet av alle skjermene hans. Når brukeren spør hvor han skal trykke på bildet, eller et steg handler om et bestemt felt eller en knapp, MÅ svaret avsluttes med en egen linje [[MARKER x1 y1 x2 y2]] med heltall i bildets piksler (venstre topp høyre bunn rundt akkurat det elementet). Ikke bruk MARKER ellers, og aldri uten bilde. Du kan i tillegg tegne på skjermen med egne linjer på slutten, alle med koordinater i bildets piksler: [[PIL x1 y1 x2 y2]] (pil fra start til spiss: la spissen treffe målet og start i et tomt område), [[SIRKEL x y r]] (sirkel rundt noe lite), [[RAMME x1 y1 x2 y2]] (ekstra ramme), [[NR x y n]] (nummerert merke når rekkefølgen betyr noe, n fra 1) og [[TEKST x y kort tekst]] (etikett på maks 40 tegn). MARKER skal fortsatt alltid være rundt hovedmålet. Rommer MARKER-boksen flere ting (for eksempel en rad med skjulte ikoner, en meny eller en liste), skal du i tillegg skrive [[PEKER x y]] på egen linje: ett punkt midt på det ENE elementet brukeren skal trykke på, så binderspekeren peker dit og ikke bare mot midten av boksen. Bruk så mange tegn som trengs (opptil 12), men ikke flere enn det som hjelper. Skriptet flytter merker og etiketter så de ikke havner oppå hverandre, men velg likevel punkter som ligger fornuftig fordelt. Skriv ren tekst uten markdown (ingen **, #, backticks eller lister med stjerner). Lenker skrives helt ut på egen linje. Hvis instruksjonen ber om en STATUS-linje, skal den være første linje i svaret.'

Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Text;
using System.Windows.Forms;
using System.Runtime.InteropServices;
public static class Vin {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("winmm.dll")] public static extern uint timeBeginPeriod(uint ms);   // 1 ms klokkeoppløsning: glatte animasjoner
    [DllImport("winmm.dll")] public static extern uint timeEndPeriod(uint ms);
    [DllImport("user32.dll")] public static extern IntPtr GetTopWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, int msg, int w, string l);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int val, int size);
    [DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint a, bool i, uint pid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("advapi32.dll")] static extern bool OpenProcessToken(IntPtr p, uint a, out IntPtr t);
    [DllImport("advapi32.dll")] static extern bool GetTokenInformation(IntPtr t, int c, out int v, int n, out int r);
    // Kjører vinduets prosess som administrator? Ukjent regnes som ja (tryggest).
    public static bool ErHevet(IntPtr hwnd) {
        uint pid; GetWindowThreadProcessId(hwnd, out pid);
        IntPtr p = OpenProcess(0x1000, false, pid); if (p == IntPtr.Zero) return true;
        IntPtr t; int v, r; bool ok = OpenProcessToken(p, 8, out t) && GetTokenInformation(t, 20, out v, 4, out r);
        if (!ok) { CloseHandle(p); return true; }
        GetTokenInformation(t, 20, out v, 4, out r); CloseHandle(t); CloseHandle(p); return v != 0;
    }
    [DllImport("user32.dll")] static extern bool SetWindowDisplayAffinity(IntPtr h, uint a);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
    // Løfter vinduet øverst blant «alltid øverst»-vinduer uten å ta fokus (oppgavelinja og skjulte-ikoner-menyen legger seg ellers over tegningen).
    public static void Topp(Form f) { if (f.IsHandleCreated && f.Visible) SetWindowPos(f.Handle, new IntPtr(-1), 0, 0, 0, 0, 0x13); }
    // Vinduet kommer ikke med i skjermbilder (Win10 2004+). Settes når håndtaket lages, og returnerer om det virket.
    public static bool Ekskluder(Form f) {
        EventHandler sett = delegate { SetWindowDisplayAffinity(f.Handle, 0x11); };
        f.HandleCreated += sett;
        if (f.IsHandleCreated) return SetWindowDisplayAffinity(f.Handle, 0x11);
        return true;
    }
}
public class HurtigtastVindu : NativeWindow, IDisposable {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h, int id, uint mod, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h, int id);
    public event Action<int> Trykket;
    public HurtigtastVindu() { CreateHandle(new CreateParams()); }
    public bool Registrer(int id, uint mod, uint vk) { return RegisterHotKey(Handle, id, mod, vk); }
    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0312 && Trykket != null) Trykket((int)m.WParam);
        base.WndProc(ref m);
    }
    public void Dispose() { UnregisterHotKey(Handle, 1); UnregisterHotKey(Handle, 2); UnregisterHotKey(Handle, 3); UnregisterHotKey(Handle, 4); DestroyHandle(); }
}
// Registrerer bare *hvor* og *når* venstre museknapp slippes (ingen taster). Kjører bare under veiledning.
public static class MuseKrok {
    delegate IntPtr LavNivaa(int n, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] struct PT { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct MS { public PT pt; public uint data, flags, tid; public IntPtr ex; }
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, LavNivaa p, IntPtr m, uint t);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int n, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string n);
    static LavNivaa _p = Krok; static IntPtr _h;
    public static int Teller, X, Y;
    public static void Start() {
        if (_h == IntPtr.Zero)
            _h = SetWindowsHookEx(14, _p, GetModuleHandle(System.Diagnostics.Process.GetCurrentProcess().MainModule.ModuleName), 0);
    }
    public static void Stopp() { if (_h != IntPtr.Zero) { UnhookWindowsHookEx(_h); _h = IntPtr.Zero; } }
    public static bool Aktiv { get { return _h != IntPtr.Zero; } }
    static IntPtr Krok(int n, IntPtr w, IntPtr l) {
        if (n >= 0 && (int)w == 0x0202) { MS s = (MS)Marshal.PtrToStructure(l, typeof(MS)); X = s.pt.x; Y = s.pt.y; Teller++; }
        return CallNextHookEx(_h, n, w, l);
    }
}
// Binders: én tråd tegnet med runde ender. (x, y) er øvre venstre hjørne, h er høyden.
public static class Binders {
    public static void Tegn(Graphics g, float x, float y, float h, Color c, float tykkelse) {
        float w = 0.42f * h;
        float x1 = x + 0.14f * w, x2 = x + 0.5f * w, x3 = x + 0.86f * w;
        float R = (x3 - x1) / 2f, r1 = (x2 - x1) / 2f, yTop = y + 0.04f * h, cy = y + 0.68f * h;
        GraphicsPath p = new GraphicsPath();
        p.AddLine(x2, y + 0.36f * h, x2, cy);
        p.AddArc(x1, cy - r1, 2 * r1, 2 * r1, 0, 180);
        p.AddLine(x1, cy, x1, yTop + R);
        p.AddArc(x1, yTop, 2 * R, 2 * R, 180, 180);
        p.AddLine(x3, yTop + R, x3, y + 0.86f * h);
        using (Pen pen = new Pen(c, tykkelse)) {
            pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round; pen.LineJoin = LineJoin.Round;
            g.DrawPath(pen, p);
        }
        p.Dispose();
    }
}
// Binders med uttrekkbar spiss: høyre ben (den frie enden) trekkes rett ut forover som en pekefinger, `ut` 0..1. Ingenting bøyes. Spissen ligger i (x3, enden).
public static class BindersApen {
    static void Mal(float h, out float x1, out float x3, out float R, out float yTop, out float cy, out float r1, out float x2) {
        float w = 0.42f * h; x1 = 0.14f * w; x2 = 0.5f * w; x3 = 0.86f * w;
        R = (x3 - x1) / 2f; r1 = (x2 - x1) / 2f; yTop = 0.04f * h; cy = 0.68f * h;
    }
    public static PointF Spiss(float h, float ut) {
        float x1, x2, x3, R, yTop, cy, r1; Mal(h, out x1, out x3, out R, out yTop, out cy, out r1, out x2);
        return new PointF(x3, (0.86f + 0.3f * ut) * h);
    }
    public static void Tegn(Graphics g, float h, float ut, Color c, float tykkelse) {
        float x1, x2, x3, R, yTop, cy, r1; Mal(h, out x1, out x3, out R, out yTop, out cy, out r1, out x2);
        using (Pen pen = new Pen(c, tykkelse)) {
            pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round; pen.LineJoin = LineJoin.Round;
            using (GraphicsPath p = new GraphicsPath()) {
                p.AddLine(x2, 0.36f * h, x2, cy); p.AddArc(x1, cy - r1, 2 * r1, 2 * r1, 0, 180); p.AddLine(x1, cy, x1, yTop + R);
                p.AddArc(x1, yTop, 2 * R, 2 * R, 180, 180); p.AddLine(x3, yTop + R, x3, (0.86f + 0.3f * ut) * h);
                g.DrawPath(pen, p);
            }
        }
    }
}
// Svak ramme på skjermen. Gjennomsiktig, tar ikke fokus og slipper musklikk gjennom.
public class Ramme : Form {
    public Ramme() {
        FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true;
        StartPosition = FormStartPosition.Manual; BackColor = Color.Magenta; TransparencyKey = Color.Magenta;
        SetStyle(ControlStyles.OptimizedDoubleBuffer, true);
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get { CreateParams p = base.CreateParams; p.ExStyle |= 0x80000 | 0x20 | 0x08000000 | 0x80; return p; }
    }
    protected override void OnPaint(PaintEventArgs e) {
        using (Pen d = new Pen(Color.FromArgb(11, 10, 18), 5)) e.Graphics.DrawRectangle(d, 2, 2, Width - 5, Height - 5);
        using (Pen p = new Pen(Color.FromArgb(168, 162, 210), 2)) e.Graphics.DrawRectangle(p, 2, 2, Width - 5, Height - 5);
    }
}
// Musepeker nr. 2: pulserende ring og en binders. Midten av vinduet er stedet den peker på.
public class Peker : Form {
    public float Puls = 0f, Skala = 1f, Vinkel = 45f, Apne = 0f;   // Vinkel: retningen spissen peker (grader, 0 = høyre, 90 = ned). Apne: 0 spissen inne, 1 helt utstrukket
    public static readonly Color Nokkel = Color.FromArgb(1, 1, 1);
    public Peker() {
        FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true;
        StartPosition = FormStartPosition.Manual; BackColor = Nokkel; TransparencyKey = Nokkel;
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get { CreateParams p = base.CreateParams; p.ExStyle |= 0x80000 | 0x20 | 0x08000000 | 0x80; return p; }
    }
    protected override void OnPaint(PaintEventArgs e) { Tegn(e.Graphics, Width, Height); }
    public void Tegn(Graphics g, int bredde, int hoyde) {
        g.SmoothingMode = SmoothingMode.AntiAlias; g.Clear(Nokkel);
        float cx = bredde / 2f, cy = hoyde / 2f, r = (11f + 1.5f * (float)Math.Sin(Puls)) * Skala;
        using (Pen a = new Pen(Color.FromArgb(120, 168, 162, 210), 2 * Skala)) g.DrawEllipse(a, cx - r, cy - r, 2 * r, 2 * r);
        float ut = Math.Max(0f, Math.Min(1.15f, Apne)), h = 56f * Skala;
        PointF tip = BindersApen.Spiss(h, ut);
        GraphicsState st = g.Save();
        g.TranslateTransform(cx, cy); g.RotateTransform(Vinkel - 90f); g.TranslateTransform(-tip.X, -tip.Y);
        BindersApen.Tegn(g, h, ut, Color.FromArgb(11, 10, 18), 8f * Skala);
        BindersApen.Tegn(g, h, ut, Color.FromArgb(196, 192, 222), 4f * Skala);
        g.Restore(st);
    }
}
// Øya: et gjennomsiktig vindu som er stort nok til det utvidede panelet. Bare selve øya tegnes (nøkkelfarge nesten svart).
public class Mentor : Form {
    public static readonly Color Nokkel = Color.FromArgb(1, 1, 1);
    public Mentor() {
        FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true;
        StartPosition = FormStartPosition.Manual; BackColor = Nokkel; TransparencyKey = Nokkel;
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
    }
    protected override bool ShowWithoutActivation { get { return true; } }
}
// Tray-menyen: samme stil og farger som RedScreens tray-meny (avrundet, ingen kant, hake i aksentfarge).
public class MorkMeny : ToolStripProfessionalRenderer {
    static Color Fl = Color.FromArgb(36, 36, 42), Hov = Color.FromArgb(52, 52, 60), Tx = Color.FromArgb(242, 242, 245), Sub = Color.FromArgb(154, 154, 165), Aks = Color.FromArgb(255, 107, 74);
    [System.Runtime.InteropServices.DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);
    class Farger : ProfessionalColorTable {
        static Color Fl = Color.FromArgb(36, 36, 42), Hov = Color.FromArgb(52, 52, 60);
        public override Color ToolStripDropDownBackground { get { return Fl; } }
        public override Color ImageMarginGradientBegin { get { return Fl; } }
        public override Color ImageMarginGradientMiddle { get { return Fl; } }
        public override Color ImageMarginGradientEnd { get { return Fl; } }
        public override Color MenuBorder { get { return Fl; } }
        public override Color MenuItemBorder { get { return Color.Transparent; } }
        public override Color MenuItemSelected { get { return Hov; } }
        public override Color SeparatorDark { get { return Hov; } }
        public override Color SeparatorLight { get { return Hov; } }
    }
    public MorkMeny() : base(new Farger()) { RoundedEdges = false; }
    public static void Rund(ToolStripDropDown m) { int v = 2; try { DwmSetWindowAttribute(m.Handle, 33, ref v, 4); } catch { } }   // Windows 11: avrundede hjørner
    protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e) { e.Graphics.Clear(Fl); }
    protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e) { }
    protected override void OnRenderImageMargin(ToolStripRenderEventArgs e) { using (var b = new SolidBrush(Fl)) e.Graphics.FillRectangle(b, e.AffectedBounds); }
    protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e) {
        if (!e.Item.Selected || !e.Item.Enabled) return;
        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        using (var p = new System.Drawing.Drawing2D.GraphicsPath()) {
            Rectangle r = new Rectangle(4, 1, e.Item.Width - 8, e.Item.Height - 2); int d = 12;
            p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90); p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90); p.CloseFigure();
            using (var b = new SolidBrush(Hov)) e.Graphics.FillPath(b, p);
        }
    }
    protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) { e.TextColor = e.Item.Enabled ? Tx : Sub; base.OnRenderItemText(e); }
    protected override void OnRenderItemCheck(ToolStripItemImageRenderEventArgs e) {
        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        Rectangle r = e.ImageRectangle; float cx = r.X + r.Width / 2f, cy = r.Y + r.Height / 2f;
        using (Pen p = new Pen(Aks, 2f)) { p.StartCap = System.Drawing.Drawing2D.LineCap.Round; p.EndCap = System.Drawing.Drawing2D.LineCap.Round; p.LineJoin = System.Drawing.Drawing2D.LineJoin.Round; e.Graphics.DrawLines(p, new PointF[] { new PointF(cx - 4.5f, cy + 0.2f), new PointF(cx - 1.5f, cy + 3.2f), new PointF(cx + 4.5f, cy - 3.2f) }); }
    }
    protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e) { using (Pen p = new Pen(Hov)) e.Graphics.DrawLine(p, 10, e.Item.Height / 2, e.Item.Width - 10, e.Item.Height / 2); }
}
// Lite skrivefelt-vindu ved bindersen: tar fokus (i motsetning til de andre), vises ikke i Alt-Tab.
public class InnVindu : Form {
    public InnVindu() { FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true; StartPosition = FormStartPosition.Manual; }
    [DllImport("gdi32.dll")] static extern IntPtr CreateRoundRectRgn(int a, int b, int c, int d, int e, int f);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
    protected override void OnSizeChanged(EventArgs e) {   // helt runde ender (pille)
        base.OnSizeChanged(e);
        if (Width > 0 && Height > 0) { IntPtr r = CreateRoundRectRgn(0, 0, Width + 1, Height + 1, Math.Min(Height, 52), Math.Min(Height, 52)); Region = Region.FromHrgn(r); DeleteObject(r); }
    }
    protected override CreateParams CreateParams {
        get { CreateParams p = base.CreateParams; p.ExStyle |= 0x80; return p; }
    }
}
// Utklippslista som vises ved bindersen: tar ikke fokus, så vinduet brukeren kom fra beholder det.
public class KlippVindu : Form {
    public KlippVindu() { FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true; StartPosition = FormStartPosition.Manual; }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get { CreateParams p = base.CreateParams; p.ExStyle |= 0x08000000 | 0x80; return p; }
    }
}
// Tegning på skjermen: gjennomsiktig vindu med ekte alfa per piksel (UpdateLayeredWindow), slipper klikk og fokus gjennom.
public class Overlegg : Form {
    [StructLayout(LayoutKind.Sequential)] struct BLEND { public byte Op, Flags, Alpha, Format; }
    [DllImport("user32.dll", SetLastError = true)] static extern bool UpdateLayeredWindow(IntPtr h, IntPtr dst, ref Point pd, ref Size sz, IntPtr src, ref Point ps, int key, ref BLEND b, int flags);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
    public void Flytt(int x, int y) { if (IsHandleCreated) SetWindowPos(Handle, IntPtr.Zero, x, y, 0, 0, 0x15); }   // NOSIZE | NOZORDER | NOACTIVATE
    public Overlegg() { FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true; StartPosition = FormStartPosition.Manual; }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get { CreateParams p = base.CreateParams; p.ExStyle |= 0x80000 | 0x20 | 0x08000000 | 0x80; return p; }
    }
    public void Vis(Bitmap bmp, int x, int y) {
        if (!IsHandleCreated) CreateHandle();
        IntPtr sc = GetDC(IntPtr.Zero); IntPtr mem = CreateCompatibleDC(sc); IntPtr hb = bmp.GetHbitmap(Color.FromArgb(0)); IntPtr old = SelectObject(mem, hb);
        Size sz = bmp.Size; Point ps = Point.Empty; Point pd = new Point(x, y);
        BLEND b = new BLEND(); b.Op = 0; b.Flags = 0; b.Alpha = 255; b.Format = 1;
        UpdateLayeredWindow(Handle, sc, ref pd, ref sz, mem, ref ps, 0, ref b, 2);
        SelectObject(mem, old); DeleteObject(hb); DeleteDC(mem); ReleaseDC(IntPtr.Zero, sc);
    }
}
"@
[void][Vin]::SetProcessDPIAware()   # ekte piksler, ikke skalerte

function Vindustittel($h) {
    $sb = New-Object Text.StringBuilder 512; [void][Vin]::GetWindowText($h, $sb, 512); return $sb.ToString()
}
function Er-Egen([string]$t) { return $t -like 'Bindy*' }

# Finner vinduet vi skal fange: det aktive, eller (hvis det er øya selv) det øverste andre vinduet.
function Finn-Mål {
    $h = [Vin]::GetForegroundWindow()
    if (-not (Er-Egen (Vindustittel $h))) { return $h }
    $h = [Vin]::GetTopWindow([IntPtr]::Zero)
    while ($h -ne [IntPtr]::Zero) {
        $t = Vindustittel $h
        $kl = New-Object Text.StringBuilder 128; [void][Vin]::GetClassName($h, $kl, 128)
        $skjult = 0; [void][Vin]::DwmGetWindowAttribute($h, 14, [ref]$skjult, 4)
        $r = New-Object Vin+RECT; [void][Vin]::GetWindowRect($h, [ref]$r)
        if ([Vin]::IsWindowVisible($h) -and -not [Vin]::IsIconic($h) -and $skjult -eq 0 -and $t -and -not (Er-Egen $t) `
            -and $kl.ToString() -notmatch '^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$' -and ($r.R - $r.L) -ge 200 -and ($r.B - $r.T) -ge 150) { return $h }
        $h = [Vin]::GetWindow($h, 2)   # GW_HWNDNEXT
    }
    return [IntPtr]::Zero
}

# Er dette et vindu vi aldri skal se på? Returnerer grunnen, eller $null.
function Sperre-Grunn($h, [string]$tittel) {
    $pid_ = 0; [void][Vin]::GetWindowThreadProcessId($h, [ref]$pid_)
    $prosess = (Get-Process -Id $pid_ -ErrorAction SilentlyContinue).ProcessName
    if ($tittel -match $Sperret -or $prosess -match $SperretProsess) { return "Sperret vindu ($prosess): passord/bank fanges ikke." }
    return $null
}

# Skjuler øya, rammen og pekeren mens vi tar bilde, så de ikke havner i bildet.
function Skjul-Overlay {
    $script:ovSkjult = @()
    if (-not $script:overlayKlar -or $script:ekskl) { return }
    $script:ovVar = $overlegg.Visible; if ($script:ovVar) { $overlegg.Hide() }   # tegningen skal ikke havne i bildet
    foreach ($f in @($form, $ramme, $peker)) { if ($f.Visible) { $script:ovSkjult += , @($f, $f.Opacity); $f.Opacity = 0 } }
    if ($script:ovSkjult.Count) { Start-Sleep -Milliseconds 70 }
}
function Vis-Overlay { if ($script:ovVar -and $script:ovShapes) { $overlegg.Show(); $script:ovNy = $true }; $script:ovVar = $false; foreach ($p in $script:ovSkjult) { $p[0].Opacity = $p[1] }; $script:ovSkjult = @() }

function Skaler([Drawing.Bitmap]$full, [int]$maks) {
    if ($full.Width -le $maks) { return $full }
    $nyH = [int]($full.Height * $maks / $full.Width)
    $liten = New-Object Drawing.Bitmap($maks, $nyH)
    $g = [Drawing.Graphics]::FromImage($liten); $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($full, 0, 0, $maks, $nyH); $g.Dispose(); $full.Dispose()
    return $liten
}

# Returnerer @{ ok; grunn; bitmap; tittel; L; T; skala; vB; vH }. Fanger bare ett vindu.
# Er et sperret vindu (passord/bank) synlig oppå rektangelet vi skal fange?
function Sperret-Overlapp($r) {
    $h = [Vin]::GetTopWindow([IntPtr]::Zero)
    while ($h -ne [IntPtr]::Zero) {
        if ([Vin]::IsWindowVisible($h) -and -not [Vin]::IsIconic($h)) {
            $t = Vindustittel $h
            if ($t) {
                $w = New-Object Vin+RECT
                if ([Vin]::GetWindowRect($h, [ref]$w) -and $w.L -lt $r.R -and $w.R -gt $r.L -and $w.T -lt $r.B -and $w.B -gt $r.T) { $sg = Sperre-Grunn $h $t; if ($sg) { return $sg } }
            }
        }
        $h = [Vin]::GetWindow($h, 2)
    }
    return $null
}
function Fang-Vindu {
    $h = Finn-Mål
    if ($h -eq [IntPtr]::Zero) { return @{ ok = $false; grunn = 'Fant ikke noe vindu å fange.' } }
    $tittel = Vindustittel $h
    $sg = Sperre-Grunn $h $tittel
    if ($sg) { return @{ ok = $false; grunn = $sg } }
    $r = New-Object Vin+RECT
    if (-not [Vin]::GetWindowRect($h, [ref]$r)) { return @{ ok = $false; grunn = 'Fant ikke vinduet.' } }
    $b = $r.R - $r.L; $hø = $r.B - $r.T
    if ($b -lt 50 -or $hø -lt 50) { return @{ ok = $false; grunn = 'Vinduet er for lite.' } }
    $so = Sperret-Overlapp $r; if ($so) { return @{ ok = $false; grunn = "Et sperret vindu ligger oppå: $so" } }
    Skjul-Overlay
    try {
        $full = New-Object Drawing.Bitmap($b, $hø)
        $g = [Drawing.Graphics]::FromImage($full); $g.CopyFromScreen($r.L, $r.T, 0, 0, $full.Size); $g.Dispose()
    } finally { Vis-Overlay }
    $bm = Skaler $full $MaksBredde
    return @{ ok = $true; tittel = $tittel; L = $r.L; T = $r.T; skala = $b / $bm.Width; bitmap = $bm; vB = $b; vH = $hø }
}

# Bilde av alle skjermene. Nektes hvis et vindu med bank/passord er synlig.
function Fang-Alle {
    $h = [Vin]::GetTopWindow([IntPtr]::Zero)
    while ($h -ne [IntPtr]::Zero) {
        if ([Vin]::IsWindowVisible($h) -and -not [Vin]::IsIconic($h)) {
            $t = Vindustittel $h
            if ($t) { $sg = Sperre-Grunn $h $t; if ($sg) { return @{ ok = $false; grunn = "Kan ikke se alle skjermene: $sg Lukk eller minimer vinduet først." } } }
        }
        $h = [Vin]::GetWindow($h, 2)
    }
    $vs = [Windows.Forms.SystemInformation]::VirtualScreen
    Skjul-Overlay
    try {
        $full = New-Object Drawing.Bitmap($vs.Width, $vs.Height)
        $g = [Drawing.Graphics]::FromImage($full); $g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $full.Size); $g.Dispose()
    } finally { Vis-Overlay }
    $bm = Skaler $full $MaksBreddeAlle
    return @{ ok = $true; tittel = 'alle skjermer'; L = $vs.Left; T = $vs.Top; skala = $vs.Width / $bm.Width; bitmap = $bm; vB = $vs.Width; vH = $vs.Height }
}

# Fanger etter valgt modus ('vindu' eller 'alle'). Er vinduet lite, går den over til alle skjermer.
function Fang-Etter([string]$modus) {
    if ($modus -eq 'alle') { return Fang-Alle }
    $f = Fang-Vindu
    if ($f.ok -and ($f.vB -lt 700 -or $f.vH -lt 420)) {
        $a = Fang-Alle
        if ($a.ok) { $f.bitmap.Dispose(); $a.liten = $true; return $a }
    }
    return $f
}

# Liten «signatur» av aktivt vindu: tittel + 32x20 gråtoner. Brukes bare til å se om skjermen har endret seg, lagres aldri.
function Ta-Signatur {
    $h = Finn-Mål
    if ($h -eq [IntPtr]::Zero) { return $null }
    $tittel = Vindustittel $h
    if (Sperre-Grunn $h $tittel) { return @{ blokkert = $true; tittel = $tittel } }
    $r = New-Object Vin+RECT
    if (-not [Vin]::GetWindowRect($h, [ref]$r)) { return $null }
    $b = $r.R - $r.L; $hø = $r.B - $r.T
    if ($b -lt 50 -or $hø -lt 50) { return $null }
    $full = New-Object Drawing.Bitmap($b, $hø)
    $g = [Drawing.Graphics]::FromImage($full); $g.CopyFromScreen($r.L, $r.T, 0, 0, $full.Size); $g.Dispose()
    $liten = New-Object Drawing.Bitmap(32, 20)
    $g = [Drawing.Graphics]::FromImage($liten); $g.InterpolationMode = 'Bilinear'; $g.DrawImage($full, 0, 0, 32, 20); $g.Dispose()
    $full.Dispose()
    $luma = New-Object 'byte[]' 640
    for ($y = 0; $y -lt 20; $y++) { for ($x = 0; $x -lt 32; $x++) {
        $p = $liten.GetPixel($x, $y); $luma[$y * 32 + $x] = [byte](($p.R * 30 + $p.G * 59 + $p.B * 11) / 100)
    } }
    $liten.Dispose()
    return @{ blokkert = $false; tittel = $tittel; luma = $luma }
}
function Sig-Diff($a, $b) {
    if (-not $a -or -not $b) { return 999 }
    if ($a.tittel -ne $b.tittel) { return 999 }
    $sum = 0; for ($i = 0; $i -lt 640; $i++) { $sum += [Math]::Abs([int]$a.luma[$i] - [int]$b.luma[$i]) }
    return $sum / 640.0
}

function Til-Jpeg([Drawing.Bitmap]$bm) {
    $kodek = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $p = New-Object Drawing.Imaging.EncoderParameters(1)
    $p.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [long]72)
    $ms = New-Object IO.MemoryStream
    $bm.Save($ms, $kodek, $p)
    return ,$ms.ToArray()
}

# Notatet gjelder i 3 timer etter siste endring (alltid under veiledning), og er tomt etter «Glem oppgaven».
function Les-Notat {
    if (-not (Test-Path $Notat)) { return '' }
    if (-not $script:vei -and (Get-Item $Notat).LastWriteTime -lt (Get-Date).AddHours(-3)) { return '' }
    $t = (Get-Content $Notat -Raw -Encoding UTF8).Trim()
    if ($t.StartsWith('# (ingen aktiv oppgave)')) { return '' }
    if ($t.Length -gt 3000) { $t = $t.Substring(0, 3000) }
    return $t
}
# Arkiverer notatet og glemmer samtalen, så neste oppgave starter rent.
function Arkiver-Oppgave {
    $script:logg.Clear()
    if (Test-Path $Notat) { Copy-Item $Notat ($Notat -replace '\.md$', '.forrige.md') -Force }
    [IO.File]::WriteAllText($Notat, "# (ingen aktiv oppgave)`n", (New-Object Text.UTF8Encoding($false)))
}

# Starter Claude. Svaret leses linje for linje (Les-Strøm), så teksten kan vises mens den skrives.
# $jpeg = $null gir et rent tekstspørsmål uten bilde.
function Start-Claude([string]$spørsmål, [byte[]]$jpeg, [string]$modell) {
    $innhold = @(@{ type = 'text'; text = $spørsmål })
    if ($jpeg) { $innhold += @{ type = 'image'; source = @{ type = 'base64'; media_type = 'image/jpeg'; data = [Convert]::ToBase64String($jpeg) } } }
    $linje = (@{ type = 'user'; message = @{ role = 'user'; content = $innhold } } | ConvertTo-Json -Depth 8 -Compress) + "`n"
    $psi = New-Object Diagnostics.ProcessStartInfo
    if (-not $script:ClaudeSti) { throw 'Fant ikke claude. Installer Claude Code og legg den i PATH (se docs/INSTALLASJON.md), start så Bindy på nytt.' }
    $psi.FileName = $script:ClaudeSti
    [void]$psi.EnvironmentVariables.Remove('NODE_OPTIONS')   # ingen injisert kode i claude via Node-innstillinger
    $psi.WorkingDirectory = $Arbeid
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.Arguments = "--print --model $modell --input-format stream-json --output-format stream-json --verbose --include-partial-messages " +
        '--strict-mcp-config --disable-slash-commands --setting-sources "" --no-session-persistence --system-prompt "' + $Systemprompt + '" ' +
        '--tools ""'   # ingen verktøy i det hele tatt (hvitliste), ikke svarteliste
    $p = [Diagnostics.Process]::Start($psi)
    $feil = $p.StandardError.ReadToEndAsync()
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($linje)
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.Close()
    return @{ p = $p; feil = $feil; les = $null; linjer = (New-Object Collections.ArrayList); delvis = ''; ferdig = $false }
}

# Leser det som har kommet fra Claude siden sist (uten å vente) og samler tekstbitene i $j.delvis.
function Les-Strøm($j) {
    for ($i = 0; $i -lt 300; $i++) {
        if (-not $j.les) { $j.les = $j.p.StandardOutput.ReadLineAsync() }
        if (-not $j.les.IsCompleted) { return }
        $l = $j.les.Result; $j.les = $null
        if ($null -eq $l) { $j.ferdig = $true; return }
        [void]$j.linjer.Add($l)
        if ($l.Contains('text_delta')) {
            try { $e = ($l | ConvertFrom-Json).event; if ($e.delta.type -eq 'text_delta') { $j.delvis += [string]$e.delta.text } } catch { }
        }
    }
}

function Les-Svar([string]$stdout, [string]$stderr) {
    $linjer = $stdout -split "`n" | Where-Object { $_.Trim() }
    for ($i = $linjer.Count - 1; $i -ge 0; $i--) {
        try { $d = $linjer[$i] | ConvertFrom-Json } catch { continue }
        if ($d.type -eq 'result') {
            if ($d.is_error) { throw [string]$d.result }
            return ([string]$d.result).Trim()
        }
    }
    throw "Uleselig svar. $($stderr.Substring(0, [Math]::Min(300, $stderr.Length)))"
}

# Plukker ut BEHOV-, STATUS-linja og [[MARKER x1 y1 x2 y2]]. Returnerer @{ tekst; boks; status; behov }.
function Del-Svar([string]$svar) {
    if ($svar.Length -gt 20000) { $svar = $svar.Substring(0, 20000) }   # tak: regexene under er kvadratiske på enorme svar
    $status = $null; $behov = $false
    $b = [regex]::Match($svar, '(?im)^[ \t]*BEHOV:\s*HELE_SKJERMEN[^\r\n]*\r?\n?')
    if ($b.Success) { $behov = $true; $svar = $svar.Remove($b.Index, $b.Length) }
    $s = [regex]::Match($svar, '(?im)^[ \t]*STATUS:\s*(STEG|GJORT|IKKE_GJORT|FERDIG|SPØRSMÅL)\b[^\r\n]*\r?\n?')
    if ($s.Success) { $status = $s.Groups[1].Value.ToUpper(); $svar = $svar.Remove($s.Index, $s.Length) }
    $m = [regex]::Match($svar, '\[\[MARKER\s+(\d{1,5})\s+(\d{1,5})\s+(\d{1,5})\s+(\d{1,5})\s*\]\]')
    $boks = $null
    if ($m.Success) {
        $b4 = @([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value, [int]$m.Groups[4].Value)
        if ($b4[2] -gt $b4[0] -and $b4[3] -gt $b4[1]) { $boks = $b4 }   # ugyldig boks (x2<=x1 eller y2<=y1) kastes
    }
    $svar = $svar -replace '\[\[MARKER[^\]]{0,200}\]\]', ''   # rydder alltid, også ødelagte koder
    $pk = $null; $mp = [regex]::Match($svar, '\[\[PEKER\s+(\d{1,5})\s+(\d{1,5})\s*\]\]'); if ($mp.Success) { $pk = @([int]$mp.Groups[1].Value, [int]$mp.Groups[2].Value) }
    $valg = @(); foreach ($mv in [regex]::Matches($svar, '\[\[VALG\s+([^\]\r\n]{1,60})\]\]')) { if ($valg.Count -lt 4) { $valg += $mv.Groups[1].Value.Trim() } }   # knapper brukeren kan trykke på
    $lim = $null; $skriv = $null
    $ml = [regex]::Match($svar, '\[\[LIM\s+(\d{1,2})\s*\]\]'); if ($ml.Success) { $lim = [int]$ml.Groups[1].Value }
    $mk = [regex]::Match($svar, '\[\[SKRIV\s+([^\]\r\n]{1,300})\]\]'); if ($mk.Success) { $skriv = $mk.Groups[1].Value.Trim() }
    $former = New-Object Collections.ArrayList   # tegn: PIL, RAMME, SIRKEL, NR, TEKST (koordinater i bildets piksler)
    foreach ($mm in [regex]::Matches($svar, '\[\[(PIL|RAMME|SIRKEL|NR|TEKST)\s+([^\]\r\n]{1,80})\]\]')) {
        if ($former.Count -ge 20) { break }
        $ty = $mm.Groups[1].Value.ToLower(); $ar = @($mm.Groups[2].Value.Trim() -split '\s+')
        $trengs = @{ pil = 4; ramme = 4; sirkel = 3; nr = 3; tekst = 3 }[$ty]; $ant = $(if ($ty -eq 'tekst') { 2 } else { $trengs })
        if ($ar.Count -lt $trengs) { continue }
        $tall = @(); $ok = $true
        for ($ii = 0; $ii -lt $ant; $ii++) { if ($ar[$ii] -notmatch '^\d{1,5}$') { $ok = $false; break }; $tall += [int]$ar[$ii] }
        if (-not $ok) { continue }
        if (($ty -in 'pil', 'ramme') -and $ty -eq 'ramme' -and ($tall[2] -le $tall[0] -or $tall[3] -le $tall[1])) { continue }
        $fo = @{ t = $ty; a = $tall }
        if ($ty -eq 'tekst') { $fo.s = ($ar[2..($ar.Count - 1)] -join ' ') }
        [void]$former.Add($fo)
    }
    if ($status -eq 'SPØRSMÅL') { $former.Clear() }
    $svar = $svar -replace '\[\[(LIM|SKRIV|VALG|PEKER|PIL|RAMME|SIRKEL|NR|TEKST)[^\]]{0,200}\]\]', ''
    if ($status -eq 'SPØRSMÅL') { $boks = $null; $pk = $null } else { $valg = @() }
    return @{ tekst = $svar.Trim(); boks = $boks; status = $status; behov = $behov; lim = $lim; skriv = $skriv; peker = $pk; valg = $valg; former = $former.ToArray() }
}
# Det som vises mens svaret strømmer inn: uten styrelinjer og halvferdige koder.
function Rens-Delvis([string]$t) {
    if ($t.Length -gt 20000) { $t = $t.Substring(0, 20000) }
    $t = $t -replace '(?im)^[ \t]*(STATUS|BEHOV):[^\r\n]*(\r?\n|$)', '' -replace '\[\[(MARKER|LIM|SKRIV|VALG|PEKER|PIL|RAMME|SIRKEL|NR|TEKST)[^\]]{0,200}\]\]', '' -replace '\[\[?[^\]]{0,200}$', '' -replace '\*\*|`', ''
    return $t.Trim()
}

# modus: 'spor' (vanlig spørsmål, med bilde hvis $b > 0), 'start' (brukeren ber om veiledning), 'sjekk' (automatisk, skjermen har endret seg)
function Lag-Spørsmål([string]$q, $logg, [int]$b, [int]$h, [string]$modus, [string]$steg, [bool]$alle) {
    $notat = Les-Notat
    $s = "SPRÅK: Svar på norsk, ekstremt enkelt og kort, som til noen som aldri har brukt data. Korte hverdagsord, ingen fagord eller engelske knappenavn uten forklaring, maks 2 korte setninger (et steg er én setning på under 12 ord). Svaret vises i en liten taleboks ved bindersen.`n`n"
    if ($notat) { $s += "BAKGRUNN fra brukerens samtale med Claude i terminalen (kan være utdatert; bruk den bare hvis den passer med det brukeren spør om eller det bildet viser):`n$notat`n`n" }
    $siste = @($logg | Where-Object { ((Get-Date) - $_.t).TotalMinutes -lt 10 } | Select-Object -Last 6)
    if ($siste.Count) { $s += "TIDLIGERE I DENNE ØKTA:`n" + (($siste | ForEach-Object { "brukeren: $($_.q)`nBindy: $($_.a)" }) -join "`n") + "`n`n" }
    $script:klippSendt = $(if ($script:delKlipp) { @($script:klipp | Select-Object -First 6) } else { @() })
    $kb = "UTKLIPPSTAVLEN (brukerens siste kopier, nyeste først; privat, bruk bare det som er relevant og gjengi aldri passord):`n"
    if ($script:klippSendt.Count) { $ki = 0; $kb += (($script:klippSendt | ForEach-Object { $ki++; $v = ($_ -replace '\s+', ' '); "$ki. " + $(if ($v.Length -gt 200) { $v.Substring(0, 200) + '…' } else { $v }) }) -join "`n") + "`n" } else { $kb += "(tom)`n" }
    if (-not $script:delKlipp) { $kb = "UTKLIPPSTAVLEN: brukeren deler ikke utklippene sine med deg, så du ser dem ikke og kan ikke anbefale [[LIM n]]. Trenger han tekst limt inn (en lenke, en adresse, et ord), skriv en egen linje [[SKRIV tekst]] (én linje, maks 300 tegn, ren tekst, uten tegnet ]) og si kort hva som limes inn. brukeren trykker selv «Lim inn».`n`n" } else {
    $kb += "Skal brukeren nå lime inn noe: anbefal en av dem med en egen linje [[LIM n]]. Trenger han tekst som ikke står i lista (en lenke, en adresse, et ord han skal skrive): skriv en egen linje [[SKRIV tekst]] (én linje, maks 300 tegn, ren tekst, uten tegnet ]) og si kort i svaret hva som limes inn. brukeren trykker selv «Lim inn», du skriver ikke selv. Bruk dem bare når steget faktisk handler om å skrive eller lime inn noe; under veiledning gir du teksten i det steget som trenger den.`n`n" }
    $s += $kb
    $mark = "[[MARKER x1 y1 x2 y2]]"
    $bilde = $(if ($alle) { "Bildet viser ALLE skjermene side om side og er $b x $h piksler." } else { "Bildet viser ett vindu og er $b x $h piksler." })
    if ($alle -and $script:geom -and $script:geom.skala) {   # flere skjermer: si hvor de ligger i bildet og hvilken musa står på, så veiledningen holder seg der
        $sk = $script:geom.skala; $mp = [Windows.Forms.Cursor]::Position; $si = 0; $med = 0; $deler = @()
        foreach ($sc in [Windows.Forms.Screen]::AllScreens) { $si++; $r = $sc.Bounds; if ($r.Contains($mp)) { $med = $si }; $deler += ("skjerm $si = x " + [int](($r.Left - $script:geom.L) / $sk) + " til " + [int](($r.Right - $script:geom.L) / $sk) + ", y " + [int](($r.Top - $script:geom.T) / $sk) + " til " + [int](($r.Bottom - $script:geom.T) / $sk)) }
        if ($si -gt 1 -and $med) { $bilde += " Skjermene i bildet: " + ($deler -join '; ') + ". Musepekeren står på skjerm $med. PRIORITER skjerm ${med}: veiled der så lenge steget kan gjøres der. Send bare brukeren til en annen skjerm når det ikke går, og si da tydelig hvilken skjerm." }
    }
    switch ($modus) {
        'start' { return $s + "$bilde brukeren vil bli veiledet steg for steg gjennom: $q`nGi BARE neste steg: én kort setning om hva han skal gjøre nå, og avslutt med $mark rundt akkurat det han skal trykke på eller bruke. Første linje i svaret skal være: STATUS: STEG. Hvert steg er ÉN fysisk handling (ett klikk, eller skriv ett ord), aldri flere handlinger i samme steg, og alltid med MARKER rundt elementet og [[PEKER x y]] på det ene punktet han skal trykke på, så han aldri må lete. Velg selv den raskeste veien når flere går (ikke spør om det). Unntak: må du spørre fordi alternativene gir ulike resultater, skriv STATUS: SPØRSMÅL som første linje, ett kort spørsmål og 2-4 linjer [[VALG kort tekst]] (ingen MARKER, ingen steg ennå)." }
        'sjekk' { return $s + "VEILEDNING PÅGÅR. brukerens mål (det han selv ba om): «$($script:veiMål)». Steget du ga sist: «$steg». $($script:ståttNote)Skjermen har endret seg siden. Bildet er tatt ETTER at brukeren handlet: vurder ut fra hva skjermen viser nå. Er resultatet av steget synlig (for eksempel at menyen eller vinduet har åpnet seg), svar GJORT selv om det ser litt annerledes ut enn du ventet. Svar IKKE_GJORT bare når du ser at det ikke har skjedd. $bilde Første linje i svaret skal være nøyaktig én av disse:`nSTATUS: GJORT (steget er gjort: gi så neste steg, én kort setning med én enkelt handling, og avslutt med $mark pluss [[PEKER x y]] på det ene punktet han skal trykke på)`nSTATUS: IKKE_GJORT (ikke gjort ennå: si kort hva som mangler, og $mark om relevant)`nSTATUS: FERDIG (hele oppgaven er ferdig: si det kort)`nSkriv ingenting før STATUS-linja." }
        default {
            if ($b -le 0) { return $s + "brukerens spørsmål (ingen skjermbilde vedlagt): $q" }
            return $s + "$bilde brukerens spørsmål: $q`n`n(Handler spørsmålet om hvor noe er eller hvor han skal trykke, MÅ siste linje i svaret være $mark i bildets piksler.)"
        }
    }
}

# ---------------------------------------------------------------- stil: farger, skrift og tegning (enheter, skaleres med skjermen)

function Farge([string]$hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
# Dempet palett: én lys aksent, resten dempede nøytrale flater.
$cØy = Farge '#0b0a12'; $cFlate = Farge '#14121e'; $cKant = Farge '#26233a'; $cTekst = Farge '#ecebf3'; $cDempet = Farge '#9b98b0'
$cAksent = Farge '#8f87c2'; $cFeil = Farge '#c98b84'; $cOk = Farge '#7fbf9f'; $cAdvar = Farge '#bfa66a'
$Familie = $(if ((New-Object Drawing.Text.InstalledFontCollection).Families.Name -contains 'Segoe UI Variable Text') { 'Segoe UI Variable Text' } else { 'Segoe UI' })
$FormB = 480; $PanelB = 440   # vinduets bredde og utvidet bredde i enheter

function Rund-Sti([double]$x, [double]$y, [double]$b, [double]$h, [double]$r) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    $d = [Math]::Min($r * 2, [Math]::Min($b, $h))
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $b - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $b - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure(); return $p
}
function Rund-Region($c, [int]$r) { $p = Rund-Sti 0 0 $c.Width $c.Height $r; $c.Region = New-Object Drawing.Region($p); $p.Dispose() }

$fPille = New-Object Drawing.Font($Familie, 13, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$fStatus = New-Object Drawing.Font($Familie, 11.5, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$sfPille = New-Object Drawing.StringFormat; $sfPille.Trimming = 'EllipsisCharacter'; $sfPille.FormatFlags = 'NoWrap'; $sfPille.LineAlignment = 'Center'
$sfHøyre = New-Object Drawing.StringFormat; $sfHøyre.Alignment = 'Far'; $sfHøyre.LineAlignment = 'Center'

# Øya: svart avrundet form som vokser fra pille til panel. iB/iH er gjeldende størrelse i enheter.
function Tegn-Øy([Drawing.Graphics]$g, [double]$sc, [double]$iB, [double]$iH, [int]$bob, [bool]$aktiv, [double]$ring, [string]$pilleTekst, [string]$statusTekst, [string]$statusFarge) {
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $g.Clear([Mentor]::Nokkel)
    $g.ScaleTransform($sc, $sc)
    $x = ($FormB - $iB) / 2; $y = 8
    $sti = Rund-Sti $x $y $iB $iH ([Math]::Min($iH / 2, 24))
    $b = New-Object Drawing.SolidBrush($cØy); $g.FillPath($b, $sti); $b.Dispose()
    $p = New-Object Drawing.Pen((Farge $(if ($aktiv) { '#35594a' } else { '#26233a' })), 1.25); $g.DrawPath($p, $sti); $p.Dispose()
    $liten = ($iH -lt 60) -or ($script:modus -eq 'pille')
    $steg = $liten -and $pilleTekst -like 'Steg:*'
    $ch = $(if ($liten) { 22 } else { 24 })
    $cx = $x + 18; $cy = $y + $(if ($steg) { 14 } elseif ($liten) { ($iH - $ch) / 2 } else { 14 }) + $bob * 0.5
    if ($ring -gt 0) {   # utvidende ring rundt bindersen: sendt / startet / svar
        $rr = 10 + 26 * (1 - $ring); $rc = $(if ($aktiv) { @(127, 191, 159) } else { @(168, 162, 210) })
        $rp = New-Object Drawing.Pen([Drawing.Color]::FromArgb([int](200 * $ring), $rc[0], $rc[1], $rc[2]), 2)
        $g.DrawEllipse($rp, ($cx + 5 - $rr), ($cy + $ch / 2 - $rr), (2 * $rr), (2 * $rr)); $rp.Dispose()
    }
    [Binders]::Tegn($g, $cx, $cy, $ch, (Farge $(if ($aktiv) { '#7fbf9f' } else { '#b4b0c9' })), 2.2)
    if ($liten) {
        if ($steg) {   # stegkort: nummer i aksentfarge og selve steget stort og hvitt
            if ($iB -gt 330 -and $iH -gt 56) {
                $lab = $(if ($script:veiIkke) { 'IKKE HELT ENNÅ' } else { 'STEG ' + ($script:veiGjort.Count + 1) })
                $lb = New-Object Drawing.SolidBrush((Farge $(if ($script:veiIkke) { '#d9b87a' } else { '#a9a1dd' })))
                $g.DrawString($lab, $fStegL, $lb, ($x + 54), ($y + 12)); $lb.Dispose()
                $tb = New-Object Drawing.SolidBrush((Farge '#f4f3fa'))
                $g.DrawString(($pilleTekst -replace '^Steg: ', ''), $fSteg, $tb, (New-Object Drawing.RectangleF(($x + 54), ($y + 29), ($iB - 54 - 22), ($iH - 29 - 8))), $sfSteg); $tb.Dispose()
            }
        } elseif ($pilleTekst -and $iB -gt 140) {
            $tb = New-Object Drawing.SolidBrush((Farge '#d9d6ee'))
            $g.DrawString($pilleTekst, $fPille, $tb, (New-Object Drawing.RectangleF(($x + 48), $y, ($iB - 66), $iH)), $sfPille); $tb.Dispose()
        }
    } elseif ($iB -gt $PanelB * 0.8) {   # panelet: status til høyre i toppfeltet og en tynn skillelinje
        $sb = New-Object Drawing.SolidBrush((Farge $statusFarge))
        $tw = $g.MeasureString($statusTekst, $fStatus).Width - 6
        $g.FillEllipse($sb, ($x + $iB - 46 - $tw - 14), ($y + 24), 7, 7); $sb.Dispose()
        $tb = New-Object Drawing.SolidBrush((Farge '#9b98b0'))
        $g.DrawString($statusTekst, $fStatus, $tb, (New-Object Drawing.RectangleF(($x + $iB - 136), ($y + 14), 90, 28)), $sfHøyre); $tb.Dispose()
        $lp = New-Object Drawing.Pen((Farge '#1e1c2e'), 1); $g.DrawLine($lp, ($x + 16), ($y + 52), ($x + $iB - 16), ($y + 52)); $lp.Dispose()
    }
    $g.ResetTransform()
}

function Lag-Ikon($farge) {   # tray-ikon: binders i valgt farge
    $bm = New-Object Drawing.Bitmap(32, 32)
    $g = [Drawing.Graphics]::FromImage($bm); $g.SmoothingMode = 'AntiAlias'
    [Binders]::Tegn($g, 5, 1, 30, [Drawing.Color]::FromArgb(40, 40, 60), 6)
    [Binders]::Tegn($g, 5, 1, 30, $farge, 3.5)
    $g.Dispose()
    return [Drawing.Icon]::FromHandle($bm.GetHicon())
}

# ---------------------------------------------------------------- selvsjekk og prøve

# Musefølger: målposisjon for ikonet (b x h) i fast avstand ned til høyre for pekeren; flippes til venstre/opp ved skjermkanten.
function Mus-Mål([int]$cx, [int]$cy, [int]$b, [int]$h, $wa) {
    $d = 32; $x = $cx + $d; $y = $cy + $d
    if ($x + $b -gt $wa.Right) { $x = $cx - $d - $b }
    if ($y + $h -gt $wa.Bottom) { $y = $cy - $d - $h }
    if ($x -lt $wa.Left) { $x = $wa.Left }; if ($y -lt $wa.Top) { $y = $wa.Top }
    return @($x, $y)
}

if ($Sjekk) {
    $fe = 0
    $wa = New-Object Drawing.Rectangle(0, 0, 1920, 1080)
    foreach ($t in @(@(100, 100, 132, 132), @(1900, 100, 1828, 132), @(100, 1070, 132, 998), @(1900, 1070, 1828, 998))) {
        $m = Mus-Mål $t[0] $t[1] 40 40 $wa
        if ($m[0] -ne $t[2] -or $m[1] -ne $t[3]) { Write-Host "FEIL: Mus-Mål ($($t[0]),$($t[1])) ga $($m -join ',')"; $fe++ }
    }
    foreach ($t in 'Min bank - Edge', 'Bitwarden', 'Notepad') {   # sperrelista skal treffe de to første
        if (($t -match $Sperret) -ne ($t -ne 'Notepad')) { Write-Host "FEIL: sperrelista for '$t'"; $fe++ }
    }
    $d = Del-Svar "STATUS: GJORT`nTrykk her.`n[[MARKER 10 20 110 60]]"
    if ($d.tekst -ne 'Trykk her.' -or ($d.boks -join ',') -ne '10,20,110,60' -or $d.status -ne 'GJORT') { Write-Host "FEIL: Del-Svar ($($d.status) / $($d.tekst))"; $fe++ }
    $d = Del-Svar "Hei`n[[MARKER 99999999999 1 2 3]]`n[[MARKER -5 1 2]]"
    if ($d.boks -or $d.tekst -ne 'Hei') { Write-Host "FEIL: Del-Svar ugyldig MARKER ($($d.tekst))"; $fe++ }
    $d = Del-Svar "STATUS: SPØRSMÅL`nHvilken skjerm?`n[[MARKER 1 1 50 50]]"
    if ($d.boks -or $d.status -ne 'SPØRSMÅL') { Write-Host 'FEIL: Del-Svar SPØRSMÅL'; $fe++ }
    $d = Del-Svar "Lim denne.`n[[LIM 2]]`n[[SKRIV https://google.com/account]]"
    if ($d.lim -ne 2 -or $d.skriv -ne 'https://google.com/account' -or $d.tekst -ne 'Lim denne.') { Write-Host "FEIL: Del-Svar LIM/SKRIV ($($d.lim) / $($d.skriv) / $($d.tekst))"; $fe++ }
    1..10 | ForEach-Object { Legg-Klipp "kopi $_" }; Legg-Klipp 'kopi 5'
    if ($script:klipp.Count -ne 8 -or $script:klipp[0] -ne 'kopi 5' -or @($script:klipp | Where-Object { $_ -eq 'kopi 5' }).Count -ne 1) { Write-Host 'FEIL: utklippshistorikk (maks 8, ingen duplikater)'; $fe++ }
    while ($script:klipp.Count -gt 3) { $script:klipp.RemoveAt(3); $script:klippTid.RemoveAt(3) }; $script:klippTid[2] = (Get-Date).AddMinutes(-61); Rydd-Klipp
    if ($script:klipp.Count -ne 2) { Write-Host 'FEIL: utklipp eldre enn 60 min fjernes ikke'; $fe++ }
    Tøm-Klipp
    if ((Rens-Delvis "Hei [[SKRIV abc]] ok") -ne 'Hei  ok') { Write-Host 'FEIL: Rens-Delvis SKRIV'; $fe++ }
    $d = Del-Svar "Se her.`n[[MARKER 10 10 100 50]]`n[[PIL 5 5 50 40]]`n[[SIRKEL 30 30 12]]`n[[NR 60 60 2]]`n[[TEKST 70 20 Trykk her]]`n[[PIL 1 2]]`n[[RAMME 50 50 20 20]]"
    if ($d.former.Count -ne 4 -or $d.former[3].s -ne 'Trykk her' -or $d.former[1].a[2] -ne 12 -or $d.tekst -ne 'Se her.') { Write-Host "FEIL: Del-Svar tegn ($($d.former.Count) / $($d.tekst))"; $fe++ }
    $d = Del-Svar "Trykk her.`n[[MARKER 10 10 100 50]]`n[[PEKER 40 30]]"
    if (-not $d.peker -or $d.peker[0] -ne 40 -or $d.tekst -ne 'Trykk her.') { Write-Host 'FEIL: Del-Svar PEKER'; $fe++ }
    $d = Del-Svar "STATUS: SPØRSMÅL`nHvilken skjerm?`n[[VALG Skjerm 1]]`n[[VALG Skjerm 2]]"
    if ($d.valg.Count -ne 2 -or $d.valg[1] -ne 'Skjerm 2' -or $d.tekst -ne 'Hvilken skjerm?') { Write-Host "FEIL: Del-Svar VALG ($($d.valg.Count) / $($d.tekst))"; $fe++ }
    $d = Del-Svar "Trykk her.`n[[VALG a]]"
    if ($d.valg.Count) { Write-Host 'FEIL: VALG uten SPØRSMÅL'; $fe++ }
    $d = Del-Svar "STATUS: SPØRSMÅL`nHvilken?`n[[PIL 1 1 5 5]]"
    if ($d.former.Count) { Write-Host 'FEIL: tegn ved SPØRSMÅL'; $fe++ }
    $nl = @(@{ t = 'nr'; x = 500; y = 500; n = 1 }, @{ t = 'nr'; x = 500; y = 500; n = 2 }, @{ t = 'nr'; x = 505; y = 502; n = 3 })
    Ov-Plasser $nl 1.0
    $ov = $false; foreach ($par in @(@(0, 1), @(0, 2), @(1, 2))) { if ([Math]::Abs($nl[$par[0]].x - $nl[$par[1]].x) -lt 30 -and [Math]::Abs($nl[$par[0]].y - $nl[$par[1]].y) -lt 30) { $ov = $true } }
    if ($ov) { Write-Host 'FEIL: nummer havner oppå hverandre'; $fe++ }
    $pl = @(@{ t = 'ramme'; x1 = 600; y1 = 500; x2 = 700; y2 = 540 }, @{ t = 'pil'; x1 = 800; y1 = 700; x2 = 650; y2 = 560 }, @{ t = 'pil'; x1 = 650; y1 = 700; x2 = 700; y2 = 560 })
    Ov-Plasser $pl 1.0
    if ((Ov-Krysser $pl[1].x1 $pl[1].y1 $pl[1].x2 $pl[1].y2 $pl[2].x1 $pl[2].y1 $pl[2].x2 $pl[2].y2)) { Write-Host 'FEIL: piler krysser hverandre'; $fe++ }
    $d = Del-Svar 'Bare tekst'
    if ($d.boks -or $d.status -or $d.behov) { Write-Host 'FEIL: Del-Svar uten ramme/status'; $fe++ }
    $d = Del-Svar "BEHOV: HELE_SKJERMEN`n"
    if (-not $d.behov -or $d.tekst) { Write-Host 'FEIL: Del-Svar behov'; $fe++ }
    if ((Rens-Delvis "STATUS: GJ") -ne '' -or (Rens-Delvis "Hei [[MARK") -ne 'Hei') { Write-Host 'FEIL: Rens-Delvis'; $fe++ }
    if ((Lag-Spørsmål 'hei' @() 0 0 'spor' '' $false) -notmatch 'ingen skjermbilde') { Write-Host 'FEIL: tekstspørsmål'; $fe++ }
    $png = Join-Path $env:TEMP 'bindy-oy.png'
    $bm = New-Object Drawing.Bitmap(960, 420); $g = [Drawing.Graphics]::FromImage($bm)
    $g.Clear([Drawing.Color]::FromArgb(60, 60, 70))
    Tegn-Øy $g 1.0 440 260 0 $false 0.5 '' 'Klar' '#8a87a3'; $g.Dispose(); $bm.Save($png)
    Write-Host "Øya tegnet: $png"
    $pp = New-Object Peker; $pp.Skala = 1.0; $pb = New-Object Drawing.Bitmap(760, 190); $pg = [Drawing.Graphics]::FromImage($pb); $pg.Clear([Drawing.Color]::FromArgb(60, 60, 70))
    $k = 0; foreach ($t in @(@(0, 0), @(0.5, 20), @(1, 90), @(1, 200))) {
        $pp.Apne = $t[0]; $pp.Vinkel = $t[1]; $pp.Puls = 1.6; $bi = New-Object Drawing.Bitmap(190, 190); $bg = [Drawing.Graphics]::FromImage($bi)
        $pp.Tegn($bg, 190, 190); $bg.Dispose(); $pg.DrawImage($bi, 190 * $k, 0); $k++
    }
    $pg.Dispose(); $pngP = Join-Path $env:TEMP 'bindy-peker.png'; $pb.Save($pngP); Write-Host "Peker tegnet: $pngP"
    $s1 = Ta-Signatur; $s2 = Ta-Signatur
    if ($s1 -and -not $s1.blokkert) {
        $dd = Sig-Diff $s1 $s2; Write-Host "Signatur av '$($s1.tittel)': diff mot seg selv = $([Math]::Round($dd, 2)) (skal være lav)"
        if ($dd -gt 4) { Write-Host 'ADVARSEL: aktivt vindu endrer seg hele tiden (video?)' }
    }
    [MuseKrok]::Start(); $ok = [MuseKrok]::Aktiv; [MuseKrok]::Stopp()
    if (-not $ok -or [MuseKrok]::Aktiv) { Write-Host 'FEIL: musehook start/stopp'; $fe++ } else { Write-Host 'Musehook start/stopp OK' }
    $f = Fang-Vindu
    if ($f.ok) {
        $jpeg = Til-Jpeg $f.bitmap
        Write-Host "Vindu '$($f.tittel)': $($f.bitmap.Width)x$($f.bitmap.Height), $([int]($jpeg.Length/1024)) kB, ca. $([int]($f.bitmap.Width * $f.bitmap.Height / 750)) tokens"
        if ($jpeg.Length -lt 1000) { Write-Host 'FEIL: bildet er tomt'; $fe++ }
    } else { Write-Host "Fangst nektet: $($f.grunn)" }
    $a = Fang-Alle
    if ($a.ok) { Write-Host "Alle skjermer: $($a.bitmap.Width)x$($a.bitmap.Height) (opprinnelig $($a.vB)x$($a.vH)), ca. $([int]($a.bitmap.Width * $a.bitmap.Height / 750)) tokens" } else { Write-Host "Alle skjermer nektet: $($a.grunn)" }
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Write-Host 'FEIL: fant ikke claude i PATH'; $fe++ }
    if ($fe) { exit 1 } else { Write-Host 'Selvsjekk OK (ingenting sendt).'; exit 0 }
}

if ($Prov) {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $f = Fang-Vindu
    if (-not $f.ok) { Write-Host $f.grunn; exit 1 }
    $q = Lag-Spørsmål 'Hva gjør jeg nå? Vis meg hvor tittellinjen er.' @() $f.bitmap.Width $f.bitmap.Height 'spor' '' $false
    $j = Start-Claude $q (Til-Jpeg $f.bitmap) $ModellSpør
    $ut = $j.p.StandardOutput.ReadToEnd(); [void]$j.p.WaitForExit(120000)
    $d = Del-Svar (Les-Svar $ut $j.feil.Result)
    Write-Host $d.tekst
    Write-Host "Ramme: $($d.boks -join ' ')  (bilde $($f.bitmap.Width)x$($f.bitmap.Height))"
    exit 0
}

# ---------------------------------------------------------------- tilstand

$script:jpeg = $null; $script:geom = $null; $script:tittel = ''; $script:skjermModus = 'vindu'; $script:alle = $false
$script:logg = New-Object Collections.ArrayList
$script:jobb = $null; $script:sporring = $null; $script:kallModus = 'spor'; $script:kallSig = $null; $script:alleForsøkt = $false
$script:rammeTid = $null; $script:bob = 0; $script:tikk = 0; $script:overlayKlar = $false; $script:ovSkjult = @()
$script:pause = $false; $script:toastTekst = ''; $script:toastTil = $null
# øya
$script:modus = 'skjult'; $script:iB = 120.0; $script:iH = 38.0; $script:iBm = 120.0; $script:iHm = 38.0
$script:fadeMål = 0.0; $script:hopp = 0; $script:ring = 0.0; $script:svarFull = ''; $script:visN = 0; $script:strømmer = $false
$script:knappFlash = 0; $script:tipsTil = $null; $script:tenkTekst = 'Tenker'; $script:kollapsTid = $null; $script:fokusNår = $false
# veiledning
$script:vei = $false; $script:veiMål = ''; $script:veiSteg = '';
$script:veiVis = ""; $script:veiIkke = $false; $script:kortB = 300; $script:kortH = 40; $script:stegMG = $null; $script:veiSig = $null; $script:veiPrev = $null; $script:veiStabil = 0; $script:veiAlle = $false
$script:veiSist = [DateTime]::MinValue; $script:veiUtenAkt = Get-Date; $script:veiSjekk = 0
$script:veiKlikkTeller = 0; $script:veiKlikkTid = $null; $script:veiKlikkPos = $null
$script:veiGjort = New-Object Collections.ArrayList; $script:mål = $null   # skjermkoordinater til forrige MARKER
$script:px = 0.0; $script:py = 0.0; $script:pTx = 0.0; $script:pTy = 0.0

$ramme = New-Object Ramme; $ramme.Opacity = 0.5
$overlegg = New-Object Overlegg; $script:ovShapes = $null; $script:ovBox = $null; $script:ovStart = $null; $script:ovFrame = 0; $script:ovNy = $false; $script:ovVar = $false
$peker = New-Object Peker; $peker.Opacity = 0.88
$mus = New-Object Overlegg; $script:musX = $null; $script:musY = $null; $script:musVist = $false
function Skjul-Ramme { $ramme.Hide(); $overlegg.Hide(); $script:ovShapes = $null; $script:rammeTid = $null; if (-not $script:vei) { $peker.Hide() } }

# ---- tegning: tre streker (glød, mørk kant, lys linje) så det syns på både lyse og mørke bakgrunner
$sfMidt = New-Object Drawing.StringFormat; $sfMidt.Alignment = 'Center'; $sfMidt.LineAlignment = 'Center'
function Ov-Strek($g, $sti, [double]$a, [double]$pulse, [double]$dpi) {
    foreach ($l in @(@(11, (26 + 22 * $pulse), '#b9b2ff'), @(6, 175, '#0b0a12'), @(3, 240, '#d2ccff'))) {
        $al = [int][Math]::Max(0, [Math]::Min(255, $l[1] * $a))
        $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb($al, (Farge $l[2])), [single]($l[0] * $dpi))
        $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
        $g.DrawPath($pen, $sti); $pen.Dispose()
    }
}
function Tegn-Overlegg {
    if (-not $script:ovShapes) { return }
    $bb = $script:ovBox; $t = ([DateTime]::Now - $script:ovStart).TotalSeconds; $dpi = $form.DeviceDpi / 96.0
    $bm = New-Object Drawing.Bitmap($bb.Width, $bb.Height, [Drawing.Imaging.PixelFormat]::Format32bppPArgb)
    $g = [Drawing.Graphics]::FromImage($bm); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $pulse = 0.5 + 0.5 * [Math]::Sin($t * 3.2); $k = 0
    foreach ($f in $script:ovShapes) {
        $p = [Math]::Max(0.0, [Math]::Min(1.0, ($t - 0.12 * $k) / 0.5)); $k++   # tegnene dukker opp etter hverandre
        if ($p -le 0) { continue }
        $e = 1 - [Math]::Pow(1 - $p, 3)
        switch ($f.t) {
            'ramme' {
                $gr = (1 - $e) * 12 * $dpi
                $sti = Rund-Sti ($f.x1 - $bb.X - $gr) ($f.y1 - $bb.Y - $gr) (($f.x2 - $f.x1) + 2 * $gr) (($f.y2 - $f.y1) + 2 * $gr) (10 * $dpi)
                Ov-Strek $g $sti $e $pulse $dpi; $sti.Dispose()
            }
            'sirkel' {
                $sti = New-Object Drawing.Drawing2D.GraphicsPath
                $sti.AddArc([single]($f.x - $bb.X - $f.r), [single]($f.y - $bb.Y - $f.r), [single](2 * $f.r), [single](2 * $f.r), -90, [single](359 * $e))
                Ov-Strek $g $sti 1.0 $pulse $dpi; $sti.Dispose()
            }
            'pil' {
                $ax = $f.x1 - $bb.X; $ay = $f.y1 - $bb.Y; $bx = $f.x2 - $bb.X; $by = $f.y2 - $bb.Y
                $sti = New-Object Drawing.Drawing2D.GraphicsPath
                $sti.AddLine([single]$ax, [single]$ay, [single]($ax + ($bx - $ax) * $e), [single]($ay + ($by - $ay) * $e))
                Ov-Strek $g $sti 1.0 $pulse $dpi; $sti.Dispose()
                if ($e -gt 0.7) {   # pilspiss
                    $vi = [Math]::Atan2($by - $ay, $bx - $ax); $len = 20 * $dpi; $ha = [Math]::Min(1.0, ($e - 0.7) / 0.3)
                    $hp = New-Object Drawing.Drawing2D.GraphicsPath
                    $hp.AddPolygon([Drawing.PointF[]]@(
                        (New-Object Drawing.PointF([single]$bx, [single]$by)),
                        (New-Object Drawing.PointF([single]($bx - $len * [Math]::Cos($vi - 0.45)), [single]($by - $len * [Math]::Sin($vi - 0.45)))),
                        (New-Object Drawing.PointF([single]($bx - $len * [Math]::Cos($vi + 0.45)), [single]($by - $len * [Math]::Sin($vi + 0.45))))))
                    $ob = New-Object Drawing.Pen([Drawing.Color]::FromArgb([int](175 * $ha), (Farge '#0b0a12')), [single](6 * $dpi)); $ob.LineJoin = 'Round'; $g.DrawPath($ob, $hp); $ob.Dispose()
                    $fb = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb([int](240 * $ha), (Farge '#d2ccff'))); $g.FillPath($fb, $hp); $fb.Dispose(); $hp.Dispose()
                }
            }
            'nr' {
                $rad = 13 * $dpi * (0.6 + 0.4 * $e + 0.18 * [Math]::Sin([Math]::PI * $e)); $cx = $f.x - $bb.X; $cy = $f.y - $bb.Y
                $ob = New-Object Drawing.Pen([Drawing.Color]::FromArgb([int](200 * $e), (Farge '#0b0a12')), [single](3 * $dpi))
                $fb = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb([int](245 * $e), (Farge '#b9b2ff')))
                $g.FillEllipse($fb, [single]($cx - $rad), [single]($cy - $rad), [single](2 * $rad), [single](2 * $rad)); $g.DrawEllipse($ob, [single]($cx - $rad), [single]($cy - $rad), [single](2 * $rad), [single](2 * $rad))
                $tb = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb([int](255 * $e), (Farge '#14121d')))
                $g.DrawString([string]$f.n, $fKnappFet, $tb, (New-Object Drawing.RectangleF([single]($cx - $rad), [single]($cy - $rad), [single](2 * $rad), [single](2 * $rad))), $sfMidt)
                $ob.Dispose(); $fb.Dispose(); $tb.Dispose()
            }
            'tekst' {
                $w = $f.w; $h = $f.h; $lx = $f.lx - $bb.X; $ly = $f.ly - $bb.Y
                $sti = Rund-Sti $lx $ly $w $h ($h / 2)
                $fb = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb([int](235 * $e), (Farge '#0b0a12'))); $g.FillPath($fb, $sti); $fb.Dispose()
                $ob = New-Object Drawing.Pen([Drawing.Color]::FromArgb([int](230 * $e), (Farge '#b9b2ff')), [single](1.6 * $dpi)); $g.DrawPath($ob, $sti); $ob.Dispose(); $sti.Dispose()
                $tb = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb([int](255 * $e), (Farge '#ecebf3')))
                $g.DrawString($f.s, $fKnappFet, $tb, (New-Object Drawing.RectangleF([single]$lx, [single]$ly, [single]$w, [single]$h)), $sfMidt); $tb.Dispose()
            }
        }
    }
    $g.Dispose(); $overlegg.Vis($bm, $bb.X, $bb.Y); $bm.Dispose()
}

# Tegner Claudes markeringer (ramme, pil, sirkel, nummer, tekst) og sender pekeren til hovedmålet.
# $boks = [[MARKER]] i bildets piksler (kan mangle), $former = de andre tegnene (kan mangle).
function Vis-Mål($boks, $former, $peker1 = $null) {
    $g = $script:geom; $s = $g.skala; $pad = 4; $dpi = $form.DeviceDpi / 96.0
    $X = { param($v) [int]($g.L + $v * $s) }; $Y = { param($v) [int]($g.T + $v * $s) }
    $lst = New-Object Collections.ArrayList
    if ($boks) { [void]$lst.Add(@{ t = 'ramme'; x1 = (& $X $boks[0]) - $pad; y1 = (& $Y $boks[1]) - $pad; x2 = (& $X $boks[2]) + $pad; y2 = (& $Y $boks[3]) + $pad }) }
    foreach ($f in @($former)) {
        $a = $f.a
        switch ($f.t) {
            { $_ -in 'ramme', 'pil' } { [void]$lst.Add(@{ t = $f.t; x1 = (& $X $a[0]); y1 = (& $Y $a[1]); x2 = (& $X $a[2]); y2 = (& $Y $a[3]) }) }
            'sirkel' { [void]$lst.Add(@{ t = 'sirkel'; x = (& $X $a[0]); y = (& $Y $a[1]); r = [Math]::Max(8, [int]($a[2] * $s)) }) }
            'nr'     { [void]$lst.Add(@{ t = 'nr'; x = (& $X $a[0]); y = (& $Y $a[1]); n = $a[2] }) }
            'tekst'  { [void]$lst.Add(@{ t = 'tekst'; x = (& $X $a[0]); y = (& $Y $a[1]); s = $f.s }) }
        }
    }
    if (-not $lst.Count) { return }
    Ov-Plasser $lst $dpi
    # omriss av alle tegn (skjermkoordinater): hovedmålet for pekeren er MARKER, ellers første tegn
    $mnX = [int]::MaxValue; $mnY = [int]::MaxValue; $mxX = [int]::MinValue; $mxY = [int]::MinValue; $pb = $null
    foreach ($f in $lst) {
        switch ($f.t) {
            { $_ -in 'ramme', 'pil' } { $bx1 = [Math]::Min($f.x1, $f.x2); $by1 = [Math]::Min($f.y1, $f.y2); $bx2 = [Math]::Max($f.x1, $f.x2); $by2 = [Math]::Max($f.y1, $f.y2) }
            'sirkel' { $bx1 = $f.x - $f.r; $by1 = $f.y - $f.r; $bx2 = $f.x + $f.r; $by2 = $f.y + $f.r }
            'nr'     { $bx1 = $f.x - 14; $by1 = $f.y - 14; $bx2 = $f.x + 14; $by2 = $f.y + 14 }
            'tekst'  { $bx1 = $f.lx; $by1 = $f.ly; $bx2 = $f.lx + $f.w; $by2 = $f.ly + $f.h }
        }
        if (-not $pb) { $pb = @([int]$bx1, [int]$by1, [int]$bx2, [int]$by2) }
        $mnX = [Math]::Min($mnX, $bx1); $mnY = [Math]::Min($mnY, $by1); $mxX = [Math]::Max($mxX, $bx2); $mxY = [Math]::Max($mxY, $by2)
    }
    $m = [int](44 * $dpi); $vs = [Windows.Forms.SystemInformation]::VirtualScreen
    $bb = [Drawing.Rectangle]::Intersect($vs, (New-Object Drawing.Rectangle(([int]$mnX - $m), ([int]$mnY - $m), ([int]($mxX - $mnX) + 2 * $m), ([int]($mxY - $mnY) + 2 * $m))))
    if ($bb.Width -lt 10 -or $bb.Height -lt 10) { return }
    $script:ovShapes = @($lst); $script:ovBox = $bb; $script:ovStart = Get-Date; $script:ovFrame = 0
    $overlegg.Show(); Tegn-Overlegg
    $x1 = $pb[0]; $y1 = $pb[1]; $x2 = $pb[2]; $y2 = $pb[3]
    if ($peker1) { $cx = [int]($g.L + $peker1[0] * $s); $cy = [int]($g.T + $peker1[1] * $s); $x1 = $cx - 12; $y1 = $cy - 12; $x2 = $cx + 12; $y2 = $cy + 12 }   # pekeren går til det ene målet, ikke midten av boksen
    $script:mål = @($x1, $y1, $x2, $y2)
    $script:pTx = ($x1 + $x2) / 2.0; $script:pTy = ($y1 + $y2) / 2.0
    if (-not $peker.Visible) {   # pekeren flyr ut fra der musa står
        if ($null -ne $script:musX) { $script:px = $script:musX + 20; $script:py = $script:musY + 20; $peker.Opacity = 0.88; $peker.Skala = [single]($sc * 0.5) }   # det er musefølgeren som flyr av sted (bare én binders)
        else { $m = [Windows.Forms.Cursor]::Position; $script:px = [double]$m.X; $script:py = [double]$m.Y; $peker.Opacity = 0 }
        $peker.Location = New-Object Drawing.Point(([int]$script:px - [int]($peker.Width / 2)), ([int]$script:py - [int]($peker.Height / 2)))
        $peker.Show()
        $peker.Vinkel = [single]270   # utstikkeren opp, som på musefølgeren, og snur seg mot målet underveis
        $peker.Apne = 0; $script:aV = 0.0
    }
    $script:rammeTid = [DateTime]::Now.AddSeconds($(if ($script:vei) { 120 } else { 30 }))   # forsvinner av seg selv
}

# ---------------------------------------------------------------- vindu og kontroller

$form = New-Object Mentor
$form.Text = 'Bindy'; $form.KeyPreview = $true
$sc = $form.DeviceDpi / 96.0 * 1.1   # 1,1 ekstra: teksten skal være lett å lese på store skjermer
function S([double]$n) { [int][Math]::Round($n * $sc) }
$peker.Skala = [single]$sc; $peker.Size = New-Object Drawing.Size((S 140), (S 140))
$form.Size = New-Object Drawing.Size((S $FormB), (S 420)); $form.Opacity = 0

$fSmå = New-Object Drawing.Font($Familie, [single](8.5 * 1.1))
$fTekst = New-Object Drawing.Font($Familie, [single](10 * 1.1))
$fKnapp = New-Object Drawing.Font($Familie, [single](9 * 1.1))
$fKnappFet = New-Object Drawing.Font($Familie, [single](9 * 1.1), [Drawing.FontStyle]::Bold)

function Ny-Boks { $b = New-Object Windows.Forms.Panel; $b.BackColor = $cFlate; return $b }
$lblSer = New-Object Windows.Forms.Label
$lblSer.ForeColor = $cDempet; $lblSer.BackColor = $cØy; $lblSer.Font = $fSmå; $lblSer.AutoEllipsis = $true; $lblSer.TextAlign = 'MiddleLeft'
$bokSvar = Ny-Boks
$svar = New-Object Windows.Forms.RichTextBox
$svar.ReadOnly = $true; $svar.BorderStyle = 'None'; $svar.BackColor = $cFlate; $svar.ForeColor = $cTekst; $svar.Font = $fTekst
$svar.ScrollBars = 'Vertical'; $svar.DetectUrls = $true
$svar.Add_LinkClicked({ param($s, $e) Kopier-Lenke $e.LinkText })   # klikk på en lenke kopierer den
$bokSvar.Controls.Add($svar)
$bokInn = Ny-Boks
$inn = New-Object Windows.Forms.TextBox
$inn.BorderStyle = 'None'; $inn.BackColor = $cFlate; $inn.ForeColor = $cTekst; $inn.Font = $fTekst
$inn.Add_HandleCreated({ [void][Vin]::SendMessage($inn.Handle, 0x1501, 1, 'Spør om noe …') })   # plassholdertekst
$bokInn.Controls.Add($inn)
$lblTips = New-Object Windows.Forms.Label
$lblTips.ForeColor = $cDempet; $lblTips.BackColor = $cØy; $lblTips.Font = $fSmå; $lblTips.TextAlign = 'MiddleLeft'
$TipsStandard = 'Enter spør  ·  Ctrl+Enter veileder  ·  Ctrl+Alt+N neste steg  ·  Esc lukker  ·  Ctrl+Alt+P pause'
$lblTips.Text = $TipsStandard
function Ny-Knapp([string]$tekst, [string]$bak, [string]$over, [string]$tekstFarge, [bool]$fet) {
    $k = New-Object Windows.Forms.Button
    $k.Text = $tekst; $k.FlatStyle = 'Flat'; $k.FlatAppearance.BorderSize = 0; $k.UseVisualStyleBackColor = $false
    $k.BackColor = (Farge $bak); $k.ForeColor = (Farge $tekstFarge); $k.Font = $(if ($fet) { $fKnappFet } else { $fKnapp }); $k.Cursor = 'Hand'
    $k.FlatAppearance.MouseOverBackColor = (Farge $over); $k.FlatAppearance.MouseDownBackColor = (Farge $over)
    return $k
}
$knappSkjerm = Ny-Knapp 'Skjerm: vindu' '#17151f' '#222035' '#d9d6ee' $false
$knappPause = Ny-Knapp 'Pause' '#17151f' '#222035' '#d9d6ee' $false
$knapp = Ny-Knapp 'Veiled meg' '#8f87c2' '#a39cd3' '#14121d' $true
$knappStopp = Ny-Knapp 'Stopp' '#3a1f22' '#4d282c' '#f0c4c0' $false
$knappLukk = Ny-Knapp ([string][char]0x2715) '#0b0a12' '#222035' '#9b98b0' $false
$knappLukk.AccessibleName = 'Lukk til tray'; $knappStopp.AccessibleName = 'Stopp'
$script:valg = @()
$tt = New-Object Windows.Forms.ToolTip
$valgKnapper = @(1..4 | ForEach-Object { $vk = Ny-Knapp 'valg' '#26233a' '#322f4a' '#ecebf3' $false; $vk.TextAlign = 'MiddleLeft'; $vk.UseMnemonic = $false; $vk.AutoEllipsis = $true; $vk.Padding = New-Object Windows.Forms.Padding(12, 0, 0, 0); $vk.Add_Click({ param($snd, $ev) if ($script:jobb) { return }; $inn.Text = "$($script:sporring): $($snd.Text)"; Send-Spørsmål $(if ($script:kallModus -eq 'start') { 'start' } else { 'spor' }) }); $vk })
foreach ($fk in @($knappSkjerm, $knappPause, $knappStopp, $knapp, $knappLukk) + $valgKnapper) {   # synlig fokusring (aksentfarge)
    $fk.Add_GotFocus({ param($snd, $ev) $snd.FlatAppearance.BorderColor = $cAksent; $snd.FlatAppearance.BorderSize = 2 })
    $fk.Add_LostFocus({ param($snd, $ev) $snd.FlatAppearance.BorderSize = 0 })
}
$bokInn.Add_Paint({ param($snd, $ev) if ($inn.Focused) { $pn = New-Object Drawing.Pen($cAksent, 2); $ev.Graphics.DrawRectangle($pn, 1, 1, $snd.Width - 3, $snd.Height - 3); $pn.Dispose() } })
$inn.Add_GotFocus({ $bokInn.Invalidate() }); $inn.Add_LostFocus({ $bokInn.Invalidate() })
$panel = @($lblSer, $bokSvar, $bokInn, $lblTips, $knappSkjerm, $knappPause, $knappStopp, $knapp, $knappLukk) + $valgKnapper
$form.Controls.AddRange($panel)
$svar.AccessibleName = 'Svar fra Bindy'; $inn.AccessibleName = 'Spørsmål til Bindy'; $knappSkjerm.AccessibleName = 'Skjerm: bytt mellom vindu, alle og av'; $knappPause.AccessibleName = 'Pause'; $knapp.AccessibleName = 'Veiled meg'
for ($vi = 0; $vi -lt $valgKnapper.Count; $vi++) { $valgKnapper[$vi].TabIndex = $vi }   # valgene først i tab-rekkefølgen
$bokInn.TabIndex = 4; $bokSvar.TabStop = $false; $knappSkjerm.TabIndex = 5; $knappPause.TabIndex = 6; $knappStopp.TabIndex = 7; $knapp.TabIndex = 8; $knappLukk.TabIndex = 9
foreach ($c in $panel) { $c.Visible = $false }

# Plasserer innholdet i det utvidede panelet (8-punkts rutenett) og beregner panelhøyden ($script:panelH).
function Legg-Ut([bool]$harSvar) {
    $linjer = [Math]::Ceiling($script:svarFull.Length / 46.0) + ($script:svarFull -split "`n").Count - 1   # grovt anslag
    $svarH = $(if ($harSvar) { [Math]::Min(200, [Math]::Max(64, $linjer * 20 + 28)) } else { 0 })
    $script:svarSynlig = $harSvar
    $ox = ($FormB - $PanelB) / 2 + 16; $oy = 8; $w = $PanelB - 32
    $lblSer.SetBounds((S ($ox + 38)), (S ($oy + 14)), (S ($w - 38 - 142)), (S 28))
    $knappLukk.SetBounds((S ($ox + $w - 30)), (S ($oy + 12)), (S 28), (S 28)); Rund-Region $knappLukk (S 8)
    $y = $oy + 64
    if ($harSvar) {
        $bokSvar.SetBounds((S $ox), (S $y), (S $w), (S $svarH)); $svar.SetBounds((S 14), (S 10), (S ($w - 28)), (S ($svarH - 20)))
        Rund-Region $bokSvar (S 12); $y += $svarH + 8
    }
    for ($vi = 0; $vi -lt $valgKnapper.Count; $vi++) { if ($vi -lt $script:valg.Count) { $valgKnapper[$vi].Text = $script:valg[$vi]; $valgKnapper[$vi].AccessibleName = $script:valg[$vi]; $tt.SetToolTip($valgKnapper[$vi], $script:valg[$vi]); $valgKnapper[$vi].SetBounds((S $ox), (S $y), (S $w), (S 36)); Rund-Region $valgKnapper[$vi] (S 10); $y += 44 } }
    $bokInn.SetBounds((S $ox), (S $y), (S $w), (S 44)); $inn.Width = S ($w - 28); $inn.Left = S 14
    $inn.Top = [int](($bokInn.Height - $inn.Height) / 2); Rund-Region $bokInn (S 12); $y += 44 + 8
    $bw = [int](($w - 24) / 4)
    $i = 0
    foreach ($k in @($knappSkjerm, $knappPause, $knappStopp, $knapp)) { $k.SetBounds((S ($ox + $i * ($bw + 8))), (S $y), (S $bw), (S 32)); Rund-Region $k (S 10); $i++ }
    $y += 32 + 8
    $lblTips.SetBounds((S $ox), (S $y), (S $w), (S 18)); $y += 18
    $script:panelH = $y + 14 - $oy
    $maksH = [Windows.Forms.Screen]::FromControl($form).WorkingArea.Height
    $form.Height = [Math]::Min($maksH, [Math]::Max((S 420), (S ($script:panelH + 24))))   # panelet klippes ikke når svar og valg er lange
    if ($script:modus -eq 'full') { $script:iHm = $script:panelH }
    Vis-Innhold
}
$script:panelH = 220; $script:svarSynlig = $false

# Innholdet vises først når øya har vokst nesten helt ut.
function Vis-Innhold {
    $ute = ($script:modus -eq 'full') -and ($script:iB -gt $PanelB * 0.9) -and ($script:iH -gt $script:iHm - 14)
    foreach ($c in $panel) { $c.Visible = $ute }
    $bokSvar.Visible = $ute -and $script:svarSynlig
    for ($vi = 0; $vi -lt $valgKnapper.Count; $vi++) { $valgKnapper[$vi].Visible = $ute -and ($vi -lt $script:valg.Count) }
    if ($ute -and $script:fokusNår) { $script:fokusNår = $false; [void][Vin]::SetForegroundWindow($form.Handle); $form.Activate(); $inn.Focus() }
}

# Skjermkoordinater til øya akkurat nå (til å ignorere klikk på den selv).
function Øy-Rekt {
    New-Object Drawing.Rectangle(($form.Left + (S (($FormB - $script:iB) / 2))), ($form.Top + (S 8)), (S $script:iB), (S $script:iH))
}

# Kortet øverst under veiledning: steget vises stort og tydelig (nummer, hvit tekst, flere linjer). Størrelsen følger teksten.
$fSteg = New-Object Drawing.Font($Familie, 16, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$fStegL = New-Object Drawing.Font($Familie, 11, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
$sfSteg = New-Object Drawing.StringFormat; $sfSteg.Trimming = 'EllipsisWord'
function Steg-Størrelse {
    if ($script:vei -and -not $script:jobb -and -not $script:pause -and -not ($script:toastTil -and [DateTime]::Now -lt $script:toastTil)) {
        $t = (Pille-Tekst) -replace '^Steg: ', ''
        if (-not $script:stegMG) { $script:stegMG = [Drawing.Graphics]::FromImage((New-Object Drawing.Bitmap(1, 1))) }
        $h = $script:stegMG.MeasureString($t, $fSteg, 380).Height
        $script:kortB = 460; $script:kortH = [Math]::Min(220, [Math]::Max(68, [int]($h + 48)))
    } else { $script:kortB = $(if ($script:vei) { 300 } else { 160 }); $script:kortH = 40 }
}
function Pille-Tekst {
    if ($script:toastTil -and [DateTime]::Now -lt $script:toastTil) { return $script:toastTekst }
    if ($script:pause) { return 'Pauset' }
    if ($script:jobb) { return $script:tenkTekst + (' ·' * ([int]($script:tikk / 3) % 3 + 1)) }
    if ($script:vei -and $script:veiSteg) { return 'Steg: ' + (($(if ($script:veiVis) { $script:veiVis } else { $script:veiSteg })) -replace '\s+', ' ') }
    if ($script:vei) { return 'Veiledning på' }
    return ''
}
function Status-Info {
    if ($script:pause) { return @('Pauset', '#bfa66a') }
    if ($script:jobb) { return @('Tenker', '#c98b84') }
    if ($script:vei) { return @('Veiledning', '#7fbf9f') }
    return @('Klar', '#8a87a3')
}

$form.Add_Paint({ param($s, $e) $st = Status-Info; Tegn-Øy $e.Graphics $sc $script:iB $script:iH $script:bob ($script:vei -and -not $script:pause) $script:ring (Pille-Tekst) $st[0] $st[1] })
$form.Add_MouseDown({   # klikk på pillen åpner panelet
    if ($script:modus -ne 'pille') { return }
    $x = (S (($FormB - $script:iB) / 2)); $y = (S 8)
    if ($_.X -ge $x -and $_.X -le $x + (S $script:iB) -and $_.Y -ge $y -and $_.Y -le $y + (S $script:iH)) { $script:fokusNår = $true; Sett-Modus 'full' }
})

# Øverst midt på skjermen, men nederst hvis målet Claude peker på ligger under øya.
function Plasser-Øy([bool]$ny) {
    $sk = $(if ($ny) { [Windows.Forms.Screen]::FromPoint([Windows.Forms.Cursor]::Position) } else { [Windows.Forms.Screen]::FromControl($form) })
    $bunn = $false
    if ($script:mål -and $script:rammeTid) {
        $iw = S $script:iBm; $ih = S $script:iHm
        $topp = New-Object Drawing.Rectangle(($sk.Bounds.Left + [int](($sk.Bounds.Width - $iw) / 2)), ($sk.Bounds.Top + (S 8)), $iw, $ih)
        $mr = New-Object Drawing.Rectangle($script:mål[0], $script:mål[1], ($script:mål[2] - $script:mål[0]), ($script:mål[3] - $script:mål[1]))
        $mr.Inflate(30, 30)
        $bunn = $topp.IntersectsWith($mr)
    }
    $y = $(if ($bunn) { $sk.WorkingArea.Bottom - (S ($script:iHm + 24)) } else { $sk.Bounds.Top })
    $form.Location = New-Object Drawing.Point(($sk.Bounds.Left + [int](($sk.Bounds.Width - $form.Width) / 2)), $y)
}

# 'skjult' (borte), 'pille' (liten, bare under veiledning eller som melding) eller 'full' (panel). Størrelsen glir i animasjonsklokka.
function Sett-Modus([string]$m) {
    if ($m -eq 'full' -and $script:modus -ne 'full') { $script:svarSynlig = [bool]$script:svarFull }
    $script:modus = $m
    switch ($m) {
        'skjult' { $script:iBm = 120; $script:iHm = 38; $script:fadeMål = 0.0; foreach ($c in $panel) { $c.Visible = $false } }
        'pille'  { Steg-Størrelse; $script:iBm = $script:kortB; $script:iHm = $script:kortH; $script:fadeMål = 0.97; foreach ($c in $panel) { $c.Visible = $false } }
        'full'   { Legg-Ut ([bool]$script:svarFull); $script:iBm = $PanelB; $script:iHm = $script:panelH; $script:fadeMål = 0.97 }
    }
    if ($m -ne 'skjult') {   # dukker opp øverst på skjermen der musa er, og vokser fra en liten pille
        $ny = -not $form.Visible
        Plasser-Øy $ny
        if ($ny) { $script:iB = 120.0; $script:iH = 38.0; $form.Opacity = 0; $form.Show() }
    }
}

# En kort melding i pillen («Pauset», «På igjen»), som forsvinner av seg selv.
function Sett-Toast([string]$t) {
    $script:toastTekst = $t; $script:toastTil = [DateTime]::Now.AddSeconds(1.8)
    if ($script:modus -eq 'skjult') { Sett-Modus 'pille'; $script:kollapsTid = [DateTime]::Now.AddSeconds(2) }
    $form.Invalidate()
}

# Esc: under veiledning krymper øya til en pille, ellers forsvinner den og bildet slettes.
function Skjul-Mentor {
    Skjul-Klipp
    $script:kollapsTid = $null
    if ($script:vei) { Sett-Modus 'pille'; return }
    Skjul-Ramme
    $script:jpeg = $null; $script:geom = $null; $script:tittel = ''   # bildet slettes
    Sett-Modus 'skjult'
}
$form.Add_KeyDown({ if ($_.KeyCode -eq 'Escape') { Skjul-Mentor } })
$inn.Add_KeyDown({
    if ($_.KeyCode -eq 'Enter') { $_.SuppressKeyPress = $true; Send-Spørsmål $(if ($_.Control) { 'start' } else { 'spor' }) }
    elseif ($_.KeyCode -eq 'Escape') { $_.SuppressKeyPress = $true; Skjul-Mentor }
})
$knapp.Add_Click({ if ($script:vei) { Neste-Steg } else { $script:knappFlash = 6; Send-Spørsmål 'start' } })
$knappLukk.Add_Click({ Skjul-Mentor })   # lukker til tray: øya skjules (pille under veiledning), Bindy kjører videre og hurtigtastene virker
# Stopp: avbryter spørsmålet som er på vei, avslutter veiledningen og fjerner ramme og peker. Bindy blir liggende i tray.
function Stopp-Alt {
    $j = $script:jobb
    if ($j) { try { $j.p.Kill() } catch {}; $script:jobb = $null; $script:bob = 0; $script:strømmer = $false; $inn.Enabled = $true }
    Stopp-Veiledning $null
    Skjul-Ramme; $peker.Hide()
    $script:musFade = 0
    $lblSer.Text = 'Stoppet'; Oppdater-Ikon; Sett-Toast 'Stoppet'
}
$knappStopp.Add_Click({ Stopp-Alt })
# Utklippslista: vises til venstre for øya når musa hviler på bindersen (eller festet i 30 s når Claude anbefaler et utklipp).
$klippForm = New-Object KlippVindu; $klippForm.BackColor = $cØy; $klippForm.Opacity = 0.97; $klippForm.Padding = New-Object Windows.Forms.Padding((S 6))
$klippLB = New-Object Windows.Forms.ListBox
$klippLB.BorderStyle = 'None'; $klippLB.BackColor = $cØy; $klippLB.DrawMode = 'OwnerDrawFixed'; $klippLB.IntegralHeight = $false; $klippLB.Dock = 'Fill'
$klippLB.ItemHeight = S 30; $klippLB.AccessibleName = 'Utklipp'
$klippForm.Controls.Add($klippLB)
$sfKlipp = New-Object Drawing.StringFormat; $sfKlipp.Trimming = 'EllipsisCharacter'; $sfKlipp.FormatFlags = 'NoWrap'; $sfKlipp.LineAlignment = 'Center'
$klippLB.Add_DrawItem({ param($snd, $e)
    if ($e.Index -lt 0) { return }
    $g = $e.Graphics; $r = $e.Bounds; $g.TextRenderingHint = 'ClearTypeGridFit'
    $sist = ($e.Index -ge $script:klipp.Count); $anb = ($script:anbefalt -and $e.Index -eq $script:klippN)
    $bak = $(if ($anb) { '#2c2848' } elseif ($e.Index -eq $snd.SelectedIndex) { '#222035' } else { '#0b0a12' })
    $br = New-Object Drawing.SolidBrush((Farge $bak)); $g.FillRectangle($br, $r); $br.Dispose()
    if ($anb) { $ab = New-Object Drawing.SolidBrush((Farge '#8f87c2')); $g.FillRectangle($ab, $r.X, ($r.Y + 4), 3, ($r.Height - 8)); $ab.Dispose() }
    $tb = New-Object Drawing.SolidBrush((Farge $(if ($sist) { '#9b98b0' } else { '#d9d6ee' })))
    $g.DrawString([string]$snd.Items[$e.Index], $fKnapp, $tb, (New-Object Drawing.RectangleF(($r.X + 12), $r.Y, ($r.Width - 20), $r.Height)), $sfKlipp); $tb.Dispose()
})
$klippLB.Add_MouseMove({ param($snd, $e) $i = $snd.IndexFromPoint($e.Location); if ($i -ge 0 -and $i -ne $snd.SelectedIndex) { $snd.SelectedIndex = $i } })
$klippLB.Add_MouseDown({ param($snd, $e)
    $i = $snd.IndexFromPoint($e.Location); if ($i -lt 0) { return }
    if ($i -ge $script:klipp.Count) { if ($script:klipp.Count) { Tøm-Klipp }; return }
    Lim-Inn $i
})
function Fyll-Klipp {
    $klippLB.BeginUpdate(); $klippLB.Items.Clear(); $i = 0
    foreach ($k in $script:klipp) { $i++; [void]$klippLB.Items.Add("$i   " + ($k -replace '\s+', ' ')) }
    [void]$klippLB.Items.Add($(if ($script:klipp.Count) { 'Tøm historikken' } else { 'Ingenting kopiert ennå' }))
    $klippLB.EndUpdate()
}
function Plasser-Klipp {
    $r = Øy-Rekt; $sk = [Windows.Forms.Screen]::FromPoint($r.Location); $wa = $sk.WorkingArea
    $b = S 340; $h = (S 30) * $klippLB.Items.Count + (S 12)
    $x = $r.Left - $b - (S 4); $y = $r.Top
    if ($x -lt $sk.Bounds.Left) { $x = $r.Left; $y = $r.Bottom + (S 6) }
    if ($y + $h -gt $wa.Bottom) { $y = $wa.Bottom - $h }
    if ($klippForm.Left -ne $x -or $klippForm.Top -ne $y -or $klippForm.Width -ne $b -or $klippForm.Height -ne $h) { $klippForm.SetBounds($x, $y, $b, $h); Rund-Region $klippForm (S 14) }
}
function Vis-Klipp([bool]$fest) {
    Fyll-Klipp; Plasser-Klipp
    if (-not $klippForm.Visible) { $klippForm.Show(); $klippLB.SelectedIndex = -1 }
    if ($fest) { $script:klippPinTil = [DateTime]::Now.AddSeconds(30) }
    $script:klippSkjulTid = $null
}
function Skjul-Klipp { $klippForm.Hide(); $script:klippPinTil = $null; $script:klippSkjulTid = $null }
# Kalles hvert 120 ms: åpner lista når musa hviler på bindersen, lukker den når musa har gått bort.
function Klipp-Hover {
    $synlig = ($script:modus -ne 'skjult') -and $form.Visible -and $form.Opacity -gt 0.5
    if (-not $synlig) { if ($klippForm.Visible) { Skjul-Klipp }; return }
    $pos = [Windows.Forms.Cursor]::Position; $r = Øy-Rekt
    $ikon = New-Object Drawing.Rectangle($r.Left, $r.Top, (S 56), [Math]::Min($r.Height, (S 56)))
    $overIkon = $ikon.Contains($pos)
    $overListe = $klippForm.Visible -and ([Drawing.Rectangle]::Inflate($klippForm.Bounds, 4, 4)).Contains($pos)
    $festet = $script:klippPinTil -and [DateTime]::Now -lt $script:klippPinTil
    if ($klippForm.Visible) { Plasser-Klipp }   # følger øya mens den vokser
    if ($overIkon -and -not $klippForm.Visible) { Vis-Klipp $false }
    elseif ($klippForm.Visible -and -not $overIkon -and -not $overListe -and -not $festet) {
        if (-not $script:klippSkjulTid) { $script:klippSkjulTid = [DateTime]::Now.AddMilliseconds(400) }
        elseif ([DateTime]::Now -gt $script:klippSkjulTid) { Skjul-Klipp }
    } elseif ($overIkon -or $overListe) { $script:klippSkjulTid = $null }
}

# Skjermmodus: 'vindu' (aktivt vindu), 'alle' (alle skjermer) eller 'av' (bare tekst).
function Sett-Skjerm([string]$modus) {
    $script:skjermModus = $modus
    $knappSkjerm.Text = @{ vindu = 'Skjerm: vindu'; alle = 'Skjerm: alle'; av = 'Skjerm: av' }[$modus]; $knappSkjerm.AccessibleName = $knappSkjerm.Text
    if ($modus -eq 'av') {
        $script:jpeg = $null; $script:geom = $null; $script:tittel = ''; $script:alle = $false; $lblSer.Text = 'Bare spørsmål, uten skjerm'
        return
    }
    $f = Fang-Etter $modus
    if (-not $f.ok) { Sett-Tips $f.grunn; return }
    Bruk-Bilde $f
}
function Bruk-Bilde($f) {   # lagrer bildet og viser hva som ses
    $script:jpeg = Til-Jpeg $f.bitmap; $script:geom = @{ L = $f.L; T = $f.T; skala = $f.skala }; $script:tittel = $f.tittel
    $script:alle = ($f.tittel -eq 'alle skjermer'); $script:bW = $f.bitmap.Width; $script:bH = $f.bitmap.Height; $f.bitmap.Dispose()
    $lblSer.Text = $(if ($f.liten) { 'Vinduet er lite: ser på alle skjermer' } elseif ($script:alle) { 'Ser på alle skjermer' } else { "Ser på: $($f.tittel)" })
}
$knappSkjerm.Add_Click({
    $neste = @{ vindu = 'alle'; alle = 'av'; av = 'vindu' }[$script:skjermModus]
    Sett-Skjerm $neste; $inn.Focus()
})
$knappPause.Add_Click({ Sett-Pause (-not $script:pause) })

# ---------------------------------------------------------------- lenker og svar

$UrlRegex = '(?i)\b(?:https?://[^\s<>")\]*`]{1,300}|(?:www\.)?(?:[a-z0-9][a-z0-9-]{0,40}\.){1,4}(?:com|org|net|no|io|dev|app|co|uk|eu|se|de)\b(?:/[^\s<>")\]*`]{0,300})?)'
$UrlRegexObj = New-Object Text.RegularExpressions.Regex($UrlRegex, 'None', [TimeSpan]::FromMilliseconds(250))   # tidsavbrudd mot ReDoS
function Sett-Tips([string]$t) { $lblTips.Text = $t; $script:tipsTil = [DateTime]::Now.AddSeconds(6) }
# Ser etter nye kopier (hopper over passordbehandlere og sperrede vinduer, og kopier markert som private).
function Les-Utklipp {
    Rydd-Klipp
    $sekv = [Vin]::GetClipboardSequenceNumber(); if ($sekv -eq $script:klippSekv) { return }   # utklippstavlen er uendret: ikke les den (leser vi hvert sekund, tvinger vi andre apper til å lage innholdet)
    $script:klippSekv = $sekv
    try {
        $d = [Windows.Forms.Clipboard]::GetDataObject()
        if (-not $d -or -not $d.GetDataPresent([Windows.Forms.DataFormats]::UnicodeText)) { return }
        $t = [string]$d.GetData([Windows.Forms.DataFormats]::UnicodeText)
        if ($t -eq $script:klippSist) { return }
        $script:klippSist = $t
        if ($d.GetDataPresent('ExcludeClipboardContentFromMonitorProcessing')) { return }
        $fg = [Vin]::GetForegroundWindow(); $sb = New-Object Text.StringBuilder 256; [void][Vin]::GetWindowText($fg, $sb, 256)
        if (Sperre-Grunn $fg $sb.ToString()) { return }
        Legg-Klipp $t
    } catch {}
}
# Limer valgt utklipp inn i vinduet brukeren kom fra. Skjer bare når brukeren trykker «Lim inn».
function Lim-Inn([int]$i = -1) {
    if (-not $script:klipp.Count) { return }
    if ($i -ge 0) { $script:klippN = [Math]::Min($i, $script:klipp.Count - 1) }
    $t = [string]$script:klipp[$script:klippN]
    try { $script:klippSist = $t; Sett-Utklipp $t } catch { Sett-Tips 'Utklippstavlen er opptatt'; return }
    $mål = $script:sistFremme
    if ($mål -eq [IntPtr]::Zero -or -not [Vin]::IsWindowVisible($mål)) { Sett-Tips 'Kopiert. Trykk Ctrl+V i feltet (fant ikke vinduet du kom fra).'; return }
    $mt = New-Object Text.StringBuilder 256; [void][Vin]::GetWindowText($mål, $mt, 256)
    if (Sperre-Grunn $mål $mt.ToString()) { Sett-Tips 'Kopiert, men ikke limt inn: dette er et passord- eller bankvindu.'; return }
    [void][Vin]::SetForegroundWindow($mål); Start-Sleep -Milliseconds 200
    if ([Vin]::GetForegroundWindow() -ne $mål) { Sett-Tips 'Kopiert. Trykk Ctrl+V selv.'; return }
    $mt2 = New-Object Text.StringBuilder 256; [void][Vin]::GetWindowText([Vin]::GetForegroundWindow(), $mt2, 256)
    if ([Vin]::GetForegroundWindow() -ne $mål -or $mt2.ToString() -ne $mt.ToString() -or (Sperre-Grunn $mål $mt2.ToString())) { Sett-Tips 'Kopiert, men vinduet endret seg. Trykk Ctrl+V selv.'; return }
    $pidM = 0; [void][Vin]::GetWindowThreadProcessId($mål, [ref]$pidM); $pnM = (Get-Process -Id $pidM -ErrorAction SilentlyContinue).ProcessName
    if ($pnM -match '^(WindowsTerminal|wt|conhost|powershell|pwsh|cmd|alacritty|mintty|wezterm|kitty|herdr|Code|Cursor|Windsurf|devenv|idea64|pycharm64)$') { Sett-Tips 'Kopiert. Terminalvinduer limes ikke inn automatisk: trykk Ctrl+V selv.'; return }
    if ([Vin]::ErHevet($mål)) { Sett-Tips 'Kopiert. Vinduet kjører som administrator, så Bindy limer ikke inn dit. Trykk Ctrl+V selv.'; return }
    [Windows.Forms.SendKeys]::SendWait('^v'); $script:anbefalt = $false; Skjul-Klipp; Sett-Toast 'Limt inn'
}
function Sett-Utklipp([string]$t) {   # Bindys egne kopier skal ikke havne i Windows utklippshistorikk eller sky-synk
    $do = New-Object Windows.Forms.DataObject; $do.SetText($t)
    $do.SetData('ExcludeClipboardContentFromMonitorProcessing', (New-Object IO.MemoryStream(,[byte[]](1, 0, 0, 0))))
    [Windows.Forms.Clipboard]::SetDataObject($do, $true)
}
function Kopier-Lenke([string]$u) {
    $u = $u.TrimEnd('.', ',', ';', ':', '!', '?')
    if ($u -notmatch '^(?i)https?://') { $u = "https://$u" }
    try { $script:klippSist = $u; Sett-Utklipp $u; Legg-Klipp $u; Sett-Tips 'Lenke kopiert til utklippstavlen' } catch { Sett-Tips 'Fikk ikke kopiert (utklippstavlen er opptatt)' }
}
# Viser svaret ferdig (eller med «skrivemaskin»-effekt hvis $skriv) og kopierer første lenke automatisk.
function Sett-Svar([string]$tekst, [bool]$skriv) {
    if ($script:rolig) { $skriv = $false }
    $tekst = ($tekst -replace '\*\*|`', '') -replace "`r?`n", "`r`n"   # fjerner markdown-rester
    $script:svarFull = $tekst; $script:visN = $(if ($skriv) { 0 } else { $tekst.Length })
    $svar.Text = $(if ($skriv) { '' } else { $tekst })
    $lenker = @(); try { $lenker = $UrlRegexObj.Matches($(if ($tekst.Length -gt 5000) { $tekst.Substring(0, 5000) } else { $tekst })) } catch {}
    if ($lenker.Count -gt 0) {
        Sett-Tips 'Klikk en lenke i svaret for å kopiere den.'
    }
}
$script:rolig = -not [Windows.Forms.SystemInformation]::UIEffectsEnabled   # Windows «Vis animasjoner» av: ingen hopp, ringer eller skrivemaskin
function Puls { if (-not $script:rolig) { $script:ring = 1.0 } }

function Oppdater-Ikon {
    if ($script:pause) { $tray.Icon = $ikonPause; $tray.Text = 'Bindy: PAUSET' }
    elseif ($script:jobb) { $tray.Icon = $ikonRød; $tray.Text = 'Bindy: sender ...' }
    elseif ($script:vei) { $tray.Icon = $ikonGrønn; $tray.Text = 'Bindy: VEILEDNING PÅ' }
    else { $tray.Icon = $ikonNormal; $tray.Text = 'Bindy (Ctrl+Alt+H)' }
    $stoppKnapp.Enabled = [bool]($script:vei -or $script:jobb); $nesteKnapp.Enabled = [bool]$script:vei; $knapp.Text = $(if ($script:vei) { "Neste steg" } else { "Veiled meg" }); $knapp.AccessibleName = $knapp.Text
    $knappPause.Text = $(if ($script:pause) { 'Fortsett' } else { 'Pause' }); $knappPause.AccessibleName = $knappPause.Text
    $knappPause.BackColor = (Farge $(if ($script:pause) { '#4a4026' } else { '#17151f' }))
    $knappPause.ForeColor = (Farge $(if ($script:pause) { '#efe0b4' } else { '#d9d6ee' }))
    $form.Invalidate()
}

# Pause: ingen fangst, ingen musehook, ingen sjekker. Veiledningen og målet blir stående til du fortsetter.
function Sett-Pause([bool]$p) {
    if ($script:pause -eq $p) { return }
    $script:pause = $p
    if ($pauseKnapp.Checked -ne $p) { $pauseKnapp.Checked = $p }
    if ($p) { [MuseKrok]::Stopp(); Skjul-Ramme; $peker.Hide(); $script:jpeg = $null; $script:geom = $null; $script:tittel = '' }   # pause: gammelt bilde slettes
    elseif ($script:vei) { $script:veiKlikkTeller = [MuseKrok]::Teller; [MuseKrok]::Start(); $script:veiUtenAkt = Get-Date }
    Oppdater-Ikon; Sett-Toast $(if ($p) { 'Pauset' } else { 'På igjen' })
}

# Starter Claude på et spørsmål med nåværende bilde (eller uten).
function Kjør-Kall([string]$modus, [string]$q, [string]$modell) {
    $medBilde = [bool]$script:jpeg
    $b = $(if ($medBilde) { $script:bW } else { 0 }); $h = $(if ($medBilde) { $script:bH } else { 0 })
    try {
        $txt = Lag-Spørsmål $q $script:logg $b $h $modus $script:veiSteg ($medBilde -and $script:alle)
        $script:jobb = Start-Claude $txt $(if ($medBilde) { $script:jpeg } else { $null }) $modell
    } catch {
        $script:jobb = $null; $inn.Enabled = $true; $svar.ForeColor = $cFeil; Sett-Svar "Kunne ikke starte Claude: $_" $false; Oppdater-Ikon; return
    }
    $script:strømmer = $false
    $script:hopp = 9; Puls; Oppdater-Ikon
}

function Send-Spørsmål([string]$modus) {
    if ($script:jobb) { return }
    if ($script:pause -and $script:skjermModus -ne 'av') { Sett-Toast 'Pauset'; return }
    if ($modus -eq 'start' -and (-not $script:jpeg -or $script:skjermModus -eq 'av')) {   # veiledning trenger bilde
        Sett-Skjerm $(if ($script:skjermModus -eq 'alle') { 'alle' } else { 'vindu' }); if (-not $script:jpeg) { Sett-Toast 'Fikk ikke bilde av skjermen, så veiledningen startet ikke.'; return }
    }
    $script:valg = @(); foreach ($vk in $valgKnapper) { $vk.Visible = $false }
    $q = $inn.Text.Trim()
    if (-not $q -and $modus -eq 'spor') {   # Enter uten tekst: fortsett på det som pågår i stedet for å finne opp et nytt spørsmål
        if ($script:vei -and $script:jpeg) {
            $script:ståttNote = 'brukeren trykket Enter uten å skrive noe fordi han er usikker på om han gjorde riktig. Vurder skjermen mot steget du ga sist, si kort hva som stemmer eller er feil, og veiled ham videre på det samme målet. Svar STATUS: GJORT, IKKE_GJORT eller FERDIG. '
            $sg = Ta-Signatur; if ($sg -and -not $sg.blokkert) { $script:veiSjekk = [Math]::Max(0, $script:veiSjekk - 1); Send-Sjekk $sg } else { Sett-Toast 'Fikk ikke sett skjermen akkurat nå.' }
            $script:ståttNote = ''; return
        }
        $sist = $script:logg | Select-Object -Last 1
        if ($sist -and ([DateTime]::Now - $sist.t).TotalMinutes -lt 10) { $q = "Jeg trykket Enter uten å skrive noe. Veiled meg videre på det forrige spørsmålet mitt: «$($sist.q)»" }
    }
    if (-not $q -and $modus -eq 'start') {   # «Veiled meg» med tomt felt: veiled på spørsmålet du nettopp stilte
        $sist = $script:logg | Select-Object -Last 1
        if ($sist -and $sist.q -and $sist.q -notmatch '^\(skjermen endret seg\)' -and ([DateTime]::Now - $sist.t).TotalMinutes -lt 30) { $q = ($sist.q -replace '^Jeg trykket Enter uten å skrive noe\. Veiled meg videre på det forrige spørsmålet mitt: «(.*)»$', '$1') }
    }
    if (-not $q) { $q = $(if ($modus -eq 'start') { 'oppgaven som står i bakgrunnsnotatet' } else { 'Hva gjør jeg nå?' }) }
    if ($modus -eq 'start') { Stopp-Veiledning $null; $script:logg.Clear(); $script:veiMål = $q; $script:veiAlle = $script:alle }   # ny veiledning: nytt mål, glemt samtale
    $script:sporring = $q; $script:kallModus = $modus; $script:alleForsøkt = $script:alle
    $script:kallSig = $(if ($script:jpeg) { Ta-Signatur } else { $null })
    Skjul-Ramme; $script:kollapsTid = $null
    $script:tenkTekst = 'Tenker'; $inn.Text = ''; $inn.Enabled = $false; $lblSer.Text = 'Tenker'
    Kjør-Kall $modus $q $ModellSpør
}

# Claude ba om mer: ta bilde av alle skjermer og send samme spørsmål på nytt (én gang per spørsmål).
function Prøv-Igjen-Alle {
    $f = Fang-Alle
    if (-not $f.ok) { Sett-Svar $f.grunn $false; return $false }
    Bruk-Bilde $f; $lblSer.Text = 'Ser på alle skjermer'
    $script:alleForsøkt = $true; if ($script:vei) { $script:veiAlle = $true }
    $script:tenkTekst = 'Ser på alle skjermer'
    Kjør-Kall $script:kallModus $script:sporring $ModellSpør
    return $true
}

# ---------------------------------------------------------------- veiledning

function Skriv-Fremdrift {
    $t = $(if (Test-Path $Notat) { Get-Content $Notat -Raw -Encoding UTF8 } else { '' })
    $i = $t.IndexOf('## Fremdrift (automatisk)'); if ($i -ge 0) { $t = $t.Substring(0, $i) }
    $gjort = ($script:veiGjort | ForEach-Object { "- gjort: $_" }) -join "`n"
    $t = $t.TrimEnd() + "`n`n## Fremdrift (automatisk)`n" + $(if ($gjort) { "$gjort`n" } else { '' }) + "- NÅ: $($script:veiSteg)`n"
    [IO.File]::WriteAllText($Notat, $t, (New-Object Text.UTF8Encoding($false)))
}

function Start-Veiledning {
    $script:veiForrige = $null;     $script:vei = $true; $script:veiHjelpt = $false; $script:veiSjekk = 0; $script:veiGjort.Clear(); $script:veiPrev = $null; $script:veiStabil = 0
    $script:veiUtenAkt = Get-Date; $script:veiSist = Get-Date; $script:veiKlikkTid = $null
    $script:veiKlikkTeller = [MuseKrok]::Teller
    if (-not $script:pause) { [MuseKrok]::Start() }
    $veiKlokke.Start(); Oppdater-Ikon
}
function Stopp-Veiledning([string]$grunn) {
    if (-not $script:vei) { return }
    $script:veiVis = ""; $script:veiIkke = $false;
    $script:vei = $false; $script:veiSteg = ''; $script:veiMål = ''; $script:veiAlle = $false; $script:mål = $null; [MuseKrok]::Stopp(); $veiKlokke.Stop()
    $peker.Hide(); Skjul-Ramme; Oppdater-Ikon
    if ($script:modus -eq 'pille') { Sett-Modus 'skjult' }
    if ($grunn) { $tray.ShowBalloonTip(4000, 'Bindy', $grunn, 'Info') }
}

# Sender et nytt bilde til Claude fordi skjermen har endret seg. $sig er signaturen vi målte rett før.
function Send-Sjekk($sig, [string]$modell = $ModellSjekk) {
    $stille = $script:stilleSjekk; $script:stilleSjekk = $false   # settes på nytt rett før kallet, så det aldri henger igjen
    if ($script:veiSjekk -ge $MaksSjekker) { Stopp-Veiledning "Veiledningen stoppet etter $MaksSjekker sjekker."; return }
    $f = Fang-Etter $(if ($script:veiAlle) { 'alle' } else { 'vindu' })
    if (-not $f.ok) { return }
    Bruk-Bilde $f
    if (-not $stille) { $script:veiSjekk++ }   # stille sjekker (uten klikk) teller ikke mot taket
    $script:veiKlikkTid = $null; $script:veiSist = Get-Date
    $script:sporring = '(skjermen endret seg)'; $script:kallModus = 'sjekk'; $script:kallSig = $sig; $script:alleForsøkt = $script:alle
    $script:tenkTekst = 'Sjekker'
    $script:stilleSjekk = $stille
    Kjør-Kall 'sjekk' '' $modell
}

# Følger med: ser etter klikk og skjermendringer (lokalt og gratis) og ber Claude om en ny vurdering når det trengs.
# Balanse: raskt etter klikk (men vent til skjermen har roet seg), sterkere modell når brukeren har klikket, og rolig uten klikk (stor endring, haiku, og et «ikke gjort» vises ikke).
function Følg-Med {
    if (-not $script:vei -or $script:jobb -or $script:pause) { return }
    $nå = Get-Date
    if (($nå - $script:veiUtenAkt).TotalMinutes -gt $StoppEtterMin) { Stopp-Veiledning "Ingen aktivitet i $StoppEtterMin minutter. Veiledningen er stoppet."; return }
    $sig = Ta-Signatur
    if (-not $sig) { return }
    if ($sig.blokkert) { return }   # sperret vindu: jeg ser ikke på det
    $diff = Sig-Diff $sig $script:veiSig; $endret = $diff -gt 4
    $rolig = $script:veiForrige -and (Sig-Diff $sig $script:veiForrige) -le 3; $script:veiForrige = $sig   # skjermen er lik forrige måling (animasjonen er ferdig)
    if ([MuseKrok]::Teller -ne $script:veiKlikkTeller) {   # nytt klikk
        $script:veiKlikkTeller = [MuseKrok]::Teller
        $kp = New-Object Drawing.Point([MuseKrok]::X, [MuseKrok]::Y)
        if (-not ($form.Visible -and (Øy-Rekt).Contains($kp))) { $script:veiKlikkTid = $nå; $script:veiKlikkPos = $kp; $script:veiUtenAkt = $nå }
    }
    $trigger = $false; $klikk = $false; $note = ''
    if ($script:veiKlikkTid) {
        $v = ($nå - $script:veiKlikkTid).TotalSeconds
        $iMål = $script:mål -and $script:veiKlikkPos.X -ge $script:mål[0] -and $script:veiKlikkPos.X -le $script:mål[2] -and $script:veiKlikkPos.Y -ge $script:mål[1] -and $script:veiKlikkPos.Y -le $script:mål[3]
        if (($v -ge 1.0 -and $endret -and $rolig) -or ($iMål -and $v -ge 0.5) -or ($v -ge 5 -and $endret)) {
            $trigger = $true; $klikk = $true
            $note = $(if ($iMål) { 'brukeren klikket INNE i det markerte målet for steget. ' } else { 'brukeren klikket UTENFOR det markerte målet for steget (kanskje et annet sted som også virker). ' })
        }
        if ($v -gt 8) { $script:veiKlikkTid = $null }   # klikk uten virkning
    }
    if ($endret) {   # skjermen har endret seg uten klikk (for eksempel et nytt vindu): vent til den har roet seg
        if ($script:veiPrev -and (Sig-Diff $sig $script:veiPrev) -le 4) { $script:veiStabil++ } else { $script:veiStabil = 0 }
        $script:veiPrev = $sig; $script:veiUtenAkt = $nå
        if ($script:veiStabil -ge 2 -and $diff -gt 9 -and -not $script:veiKlikkTid -and -not $trigger) { $trigger = $true; $note = 'ingen klikk registrert; skjermen endret seg av seg selv. ' }
    } else { $script:veiStabil = 0; $script:veiPrev = $null }
    if (-not $trigger -and -not $script:veiKlikkTid -and -not $script:veiHjelpt -and $script:veiSteg -and ($nå - $script:veiSist).TotalSeconds -ge 35) {   # brukeren står stille: steget var nok uklart
        $script:veiHjelpt = $true; $script:ståttNote = 'brukeren har stått stille i over 30 sekunder uten å klikke, så steget var nok uklart. Forklar det enklere, ÉN handling, og pek helt presist (MARKER og PEKER). Svar STATUS: IKKE_GJORT. '
        Send-Sjekk $sig $ModellSjekk; $script:ståttNote = ''; return
    }
    if ($trigger -and ($nå - $script:veiSist).TotalSeconds -ge 1) {
        $script:ståttNote = $note; $script:stilleSjekk = -not $klikk
        Send-Sjekk $sig $(if ($klikk) { $ModellSpør } else { $ModellSjekk }); $script:ståttNote = ''
    }
}

# «Neste steg»: brukeren sier at steget er gjort (eller vil hoppe over det), og Bindy gir neste. Knapp i panelet, tray-menyen og Ctrl+Alt+N.
function Neste-Steg {
    if (-not $script:vei) { Sett-Toast 'Ingen veiledning pågår'; return }
    if ($script:jobb) { Sett-Toast 'Bindy tenker. Prøv igjen om et øyeblikk.'; return }
    if ($script:pause) { Sett-Toast 'Pauset'; return }
    $sg = Ta-Signatur; if (-not $sg -or $sg.blokkert) { Sett-Toast 'Fikk ikke sett skjermen akkurat nå.'; return }
    $script:ståttNote = 'brukeren trykket «Neste steg»: regn steget du ga sist som gjort (eller hopp over det) og gi det NESTE steget med MARKER og PEKER. Svar STATUS: GJORT, eller FERDIG hvis målet er nådd. '
    $script:veiSjekk = [Math]::Max(0, $script:veiSjekk - 1); $script:veiHjelpt = $false
    Send-Sjekk $sg $ModellSpør; $script:ståttNote = ''
}

# ---------------------------------------------------------------- tray og hurtigtast

$ikonNormal = Lag-Ikon (Farge '#b4b0c9'); $ikonRød = Lag-Ikon $cFeil; $ikonGrønn = Lag-Ikon $cOk; $ikonPause = Lag-Ikon (Farge '#6b6880')
$tray = New-Object Windows.Forms.NotifyIcon
$tray.Icon = $ikonNormal; $tray.Text = 'Bindy (Ctrl+Alt+H)'; $tray.Visible = $true
$meny = New-Object Windows.Forms.ContextMenuStrip
$pauseKnapp = New-Object Windows.Forms.ToolStripMenuItem('Pause (Ctrl+Alt+P)')
$pauseKnapp.CheckOnClick = $true
$pauseKnapp.Add_CheckedChanged({ Sett-Pause $pauseKnapp.Checked })
$nesteKnapp = New-Object Windows.Forms.ToolStripMenuItem('Neste steg (Ctrl+Alt+N)'); $nesteKnapp.Enabled = $false; $nesteKnapp.Add_Click({ Neste-Steg })
$stoppKnapp = New-Object Windows.Forms.ToolStripMenuItem('Stopp (avbryt og stopp veiledning)')
$stoppKnapp.Enabled = $false
$stoppKnapp.Add_Click({ Stopp-Alt })
$glemKnapp = New-Object Windows.Forms.ToolStripMenuItem('Glem oppgaven (nytt mål)')
$glemKnapp.Add_Click({ Stopp-Veiledning $null; Arkiver-Oppgave; Skjul-Mentor; $tray.ShowBalloonTip(2500, 'Bindy', 'Oppgaven og samtalen er glemt.', 'Info') })
$apneKnapp = New-Object Windows.Forms.ToolStripMenuItem('Åpne Bindy (spør uten skjerm)')
$apneKnapp.Add_Click({ $script:fokusNår = $true; Sett-Modus 'full'; Puls })
$tomKnapp = New-Object Windows.Forms.ToolStripMenuItem('Tøm utklipp'); $tomKnapp.Add_Click({ Tøm-Klipp })
$delKnapp = New-Object Windows.Forms.ToolStripMenuItem('Del utklipp med Claude'); $delKnapp.CheckOnClick = $true; $delKnapp.Checked = $script:delKlipp
$delKnapp.Add_CheckedChanged({ $script:delKlipp = $delKnapp.Checked; try { if ($script:delKlipp) { New-Item -ItemType File -Force $script:delFil | Out-Null } else { Remove-Item $script:delFil -ErrorAction SilentlyContinue } } catch {} })
$musKnapp = New-Object Windows.Forms.ToolStripMenuItem('Musefølger'); $musKnapp.CheckOnClick = $true; $musKnapp.Checked = $script:musPå
$musKnapp.Add_CheckedChanged({ $script:musPå = $musKnapp.Checked; try { if ($script:musPå) { Remove-Item $script:musFil -ErrorAction SilentlyContinue } else { New-Item -ItemType File -Force $script:musFil | Out-Null } } catch {} })
$apneKnapp.Font = New-Object Drawing.Font("Segoe UI", [single]9.75, [Drawing.FontStyle]::Bold)
foreach ($mi in @($apneKnapp, '-', $musKnapp, $delKnapp, $tomKnapp, '-', $nesteKnapp, $pauseKnapp, $stoppKnapp, $glemKnapp, '-')) { if ($mi -eq '-') { [void]$meny.Items.Add((New-Object Windows.Forms.ToolStripSeparator)) } else { [void]$meny.Items.Add($mi) } }
[void]$meny.Items.Add('Avslutt Bindy', $null, { $tray.Visible = $false; Stopp-Veiledning $null; $form.Hide(); [Windows.Forms.Application]::Exit() })
foreach ($it in $meny.Items) { if ($it -is [Windows.Forms.ToolStripMenuItem]) { $it.Padding = New-Object Windows.Forms.Padding(0, 3, 0, 3) } }
$meny.Renderer = New-Object MorkMeny; $meny.Add_Opening({ param($s) [MorkMeny]::Rund($s) }); $meny.BackColor = [Drawing.Color]::FromArgb(36, 36, 42); $meny.ForeColor = [Drawing.Color]::FromArgb(242, 242, 245); $meny.Font = New-Object Drawing.Font("Segoe UI", [single]9.75); $meny.Padding = New-Object Windows.Forms.Padding(0, 5, 0, 5); $meny.ShowImageMargin = $false; $meny.ShowCheckMargin = $true
$tray.ContextMenuStrip = $meny
$tray.Add_DoubleClick({ $script:fokusNår = $true; Sett-Modus 'full'; Puls })
$tray.Add_MouseClick({ param($s, $e) if ($e.Button -eq 'Left') { Sett-Pause (-not $script:pause) } })   # venstreklikk på ikonet = pause/fortsett
foreach ($f in @($form, $ramme, $peker, $overlegg, $klippForm, $mus)) { [void][Vin]::Ekskluder($f) }   # Bindys vinduer kommer ikke med i skjermbilder, så ingenting skjules (ingen flimring)
$script:ekskl = $true
$script:overlayKlar = $true

# Tar imot et ferdig svar fra Claude.
function Behandle-Svar($j) {
    $inn.Enabled = $true
    $ferdig = $false
    try {
        $d = Del-Svar (Les-Svar ($j.linjer -join "`n") $j.feil.Result)
        if ($d.behov -and -not $script:alleForsøkt -and -not $script:pause -and $script:kallModus -ne 'sjekk') {   # Claude vil se mer: alle skjermene (ikke fra automatiske steg-sjekker: der har du ikke bedt om det)
            if (Prøv-Igjen-Alle) { return }
        }
        $stille = $script:stilleSjekk; $script:stilleSjekk = $false
        if ($stille -and $script:kallModus -eq 'sjekk' -and $d.status -eq 'IKKE_GJORT') { $script:veiSig = $script:kallSig; $script:veiSist = Get-Date; $script:jobb = $null; $script:bob = 0; Oppdater-Ikon; return }   # uten klikk: et «ikke gjort» vises ikke
        if (-not $d.tekst -and $d.behov) { $d.tekst = 'Jeg trenger å se mer enn dette vinduet, men fikk ikke tatt bilde av alle skjermene.' }
        [void]$script:logg.Add(@{ q = $script:sporring; a = $d.tekst; t = Get-Date })
        $svar.ForeColor = $cTekst; Sett-Svar $d.tekst (-not $script:strømmer)
        $script:valg = @($d.valg); if ($script:valg.Count) { $script:fokusNår = $true; Sett-Modus 'full'; Legg-Ut $true; $script:iHm = $script:panelH; Vis-Innhold }
        if ($script:kallModus -eq 'start' -and $d.status -ne 'SPØRSMÅL') { Start-Veiledning }   # SPØRSMÅL: Claude ber om kontekst først, veiledningen starter når brukeren svarer og trykker «Veiled meg» igjen
        if ($script:vei) {
            switch ($d.status) {
                'GJORT'  { $script:veiHjelpt = $false; if ($script:veiSteg) { [void]$script:veiGjort.Add($script:veiSteg) }; $script:veiSteg = $d.tekst; $script:veiVis = $d.tekst; $script:veiIkke = $false }
                'STEG'   { $script:veiSteg = $d.tekst; $script:veiVis = $d.tekst; $script:veiIkke = $false }
                'FERDIG' { if ($script:veiSteg) { [void]$script:veiGjort.Add($script:veiSteg) }; $script:veiSteg = 'Ferdig.'; $script:veiVis = 'Ferdig.'; $script:veiIkke = $false; $ferdig = $true }
                default  { if (-not $script:veiSteg) { $script:veiSteg = $d.tekst; $script:veiVis = $d.tekst } else { $script:veiVis = $d.tekst; $script:veiIkke = $true } }   # IKKE_GJORT: samme steg står, men kortet viser hva som mangler
            }
            Skriv-Fremdrift
            $script:veiSig = $script:kallSig; $script:veiSist = Get-Date; $script:veiUtenAkt = Get-Date
        }
        if (($d.boks -or $d.former.Count) -and $script:geom) { Vis-Mål $d.boks $d.former $d.peker }
        if ($d.skriv) { Legg-Klipp $d.skriv; $script:anbefalt = $true }   # Claude foreslår tekst: den havner øverst i utklippet, brukeren trykker «Lim inn»
        elseif ($d.lim -and $d.lim -le $script:klippSendt.Count) { $ki = $script:klipp.IndexOf($script:klippSendt[$d.lim - 1]); if ($ki -ge 0) { $script:klippN = $ki; $script:anbefalt = $true } }
        if ($script:anbefalt) { Vis-Klipp $true; Sett-Tips 'Bindy anbefaler et utklipp: klikk det i lista ved bindersen.' }
    } catch { $svar.ForeColor = $cFeil; Sett-Svar "Noe gikk galt: $_" $false }
    $script:jobb = $null; $script:bob = 0
    if (-not ($script:alle -or $script:jpeg)) { $lblSer.Text = 'Bare spørsmål, uten skjerm' }
    elseif ($script:vei) { $lblSer.Text = "Mål: $($script:veiMål)" }
    $svar.SelectionStart = 0
    if ($script:vei -and -not $ferdig -and -not $script:valg.Count) { Sett-Modus 'pille'; Puls }   # veiledning: steget vises stort og tydelig i kortet øverst
    else {
        if (-not $script:vei) { $script:fokusNår = $true }   # tastaturet virker rett etter svaret (ikke under veiledning, da stjeles fokus fra appen brukeren jobber i)
        Sett-Modus 'full'; Puls
    }
    if ($script:vei -or $ferdig) { $script:kollapsTid = [DateTime]::Now.AddSeconds($(if ($ferdig) { 8 } else { 10 })) }   # automatiske svar lukker seg selv
    if ($script:anbefalt -and $script:kollapsTid) { $script:kollapsTid = [DateTime]::Now.AddSeconds(30) }   # tid nok til å trykke «Lim inn»
    if ($ferdig) { Stopp-Veiledning 'Ferdig! Veiledningen er avsluttet.'; Arkiver-Oppgave }
    Oppdater-Ikon
}

# Klokke 1 (120 ms): leser svaret mens det strømmer inn, tar imot det ferdige svaret, lukker øya når den ikke brukes.
$klokke = New-Object Windows.Forms.Timer
$klokke.Interval = 120
$klokke.Add_Tick({
    $script:tikk++
    $fgh = [Vin]::GetForegroundWindow()   # vinduet brukeren kom fra (Lim inn går hit)
    if ($fgh -ne [IntPtr]::Zero -and $fgh -ne $form.Handle) {
        $kn = New-Object Text.StringBuilder 64; [void][Vin]::GetClassName($fgh, $kn, 64)
        if ($kn.ToString() -notmatch '^(Shell_TrayWnd|Shell_SecondaryTrayWnd|NotifyIconOverflowWindow|TopLevelWindowForOverflowXamlIsland)$') { $script:sistFremme = $fgh }
    }
    if ($script:tikk % 8 -eq 0 -and -not $script:pause) { Les-Utklipp }
    Klipp-Hover
    $j = $script:jobb
    if ($j) {
        Les-Strøm $j
        if ($j.delvis) {   # tekst på vei: vis den med en gang (ikke for automatiske sjekker, de åpner panelet først når de er ferdige)
            $vist = Rens-Delvis $j.delvis
            if ($vist -and $script:kallModus -ne 'sjekk' -and -not $j.delvis.TrimStart().StartsWith('BEHOV')) {
                $iMus = $script:kallModus -eq 'start'   # første steg vises i kortet øverst når det er ferdig, ikke i panelet
                if (-not $script:strømmer) { $script:strømmer = $true; $script:visN = 0; $script:svarFull = ''; if (-not $iMus) { Sett-Modus 'full' } }
                if ($vist -ne $script:svarFull) {
                    $gammelLinjer = [int]($script:svarFull.Length / 46)
                    $script:svarFull = $vist; $svar.Text = $vist -replace "`r?`n", "`r`n"; $script:visN = $vist.Length
                    if (-not $iMus -and [int]($vist.Length / 46) -ne $gammelLinjer) { Legg-Ut $true; $script:iHm = $script:panelH }
                }
                $lblSer.Text = 'Skriver'
            }
        } elseif ($script:hopp -eq 0 -and -not $script:rolig) { $script:bob = $(if ($script:tikk % 2) { -3 } else { 0 }) }
        if (-not $script:strømmer) { $lblSer.Text = $script:tenkTekst + (' ·' * ([int]($script:tikk / 3) % 3 + 1)) }
        $form.Invalidate()
    }
    if ($j -and $j.p.HasExited -and $j.ferdig) { Behandle-Svar $j }
    if ($script:kollapsTid -and [DateTime]::Now -gt $script:kollapsTid) {
        if ($inn.Focused -or $inn.Text -or $script:valg.Count -or $form.ContainsFocus) { $script:kollapsTid = [DateTime]::Now.AddSeconds(5) }   # du skriver: la den stå
        else { $script:kollapsTid = $null; Sett-Modus $(if ($script:vei) { 'pille' } else { 'skjult' }) }
    }
    if ($script:rammeTid -and [DateTime]::Now -gt $script:rammeTid) { Skjul-Ramme }
})
$klokke.Start()

# Pekerens animasjon, tidsbasert (uavhengig av bildefrekvens). Kalles fra musefølger-klokka (10 ms).
function Peker-Steg([double]$dt) {
    $r = $dt / 30.0
    if ($peker.Opacity -lt 0.88 -and $script:ovSkjult.Count -eq 0) { $peker.Opacity = [Math]::Min(0.88, $peker.Opacity + 0.1 * $r) }
    $peker.Puls += 0.12 * $r
    if ($peker.Skala -lt $sc - 0.01) { $peker.Skala += [single](($sc - $peker.Skala) * (1 - [Math]::Pow(0.9, $r))) }   # vokser fra musefølger-størrelse
    $dx = $script:pTx - $script:px; $dy = $script:pTy - $script:py
    $dist = [Math]::Sqrt($dx * $dx + $dy * $dy)
    if ($dist -gt 8) { $dv = (([Math]::Atan2($dy, $dx) * 180 / [Math]::PI - $peker.Vinkel + 540) % 360) - 180; $peker.Vinkel = [single]((($peker.Vinkel + $dv * (1 - [Math]::Pow(0.88, $r))) % 360 + 360) % 360) }   # snur mot målet
    $aMål = $(if ($dist -gt 30) { 0.0 } else { 0.92 + 0.08 * [Math]::Sin($peker.Puls * 1.5) })   # spissen inne under flyturen, trekkes ut (med lett sprett) ved fremme og stikker svakt mot målet
    $script:aV = ($script:aV + ($aMål - $peker.Apne) * 0.09 * $r) * [Math]::Pow(0.7, $r); $peker.Apne += [single]($script:aV * $r)
    if ([Math]::Abs($dx) -lt 1 -and [Math]::Abs($dy) -lt 1) { $script:px = $script:pTx; $script:py = $script:pTy }
    else { $k = 1 - [Math]::Pow(0.93, $r); $script:px += $dx * $k; $script:py += $dy * $k }
    $peker.Location = New-Object Drawing.Point(([int]$script:px - [int]($peker.Width / 2)), ([int]$script:py - [int]($peker.Height / 2)))
    $peker.Invalidate()
}

# Klokke 4 (16 ms): musefølgeren, en liten binders som glir etter musa i fast avstand. Flytter bare vinduet når den ikke er framme.
# Mens Bindy tenker vises et laste-ikon og en kort tekst ved siden av. Utstikkeren på bindersen peker oppover.
function Mus-Tekst {
    if (-not $script:jobb) { return '' }
    if ($script:strømmer) { return 'Skriver svar…' }
    return "$($script:tenkTekst)…"
}
$script:musMG = [Drawing.Graphics]::FromImage((New-Object Drawing.Bitmap(1, 1)))   # gjenbrukt for måling av tekstbredde
function Tegn-Mus([string]$tekst, [int]$vinkel, [double]$ret, [double]$alfa = 1.0, [bool]$venstre = $false) {
    $b = 40
    if ($tekst) { $b = 40 + 4 + 30 + [int][Math]::Ceiling($script:musMG.MeasureString($tekst, $fSmå).Width) }
    $xi = $(if ($venstre) { $b - 40 } else { 0 })   # ikonets plass: pillen står på motsatt side når den ellers ville gå utenfor skjermkanten
    $bmp = New-Object Drawing.Bitmap($b, 40, [Drawing.Imaging.PixelFormat]::Format32bppPArgb)
    $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $st = $g.Save(); $g.TranslateTransform($xi + 18, 19); $g.RotateTransform([single](180 + $ret + 90)); $g.TranslateTransform(-18, -19)   # utstikkeren opp i hvile (ret = -90), ellers i bevegelsesretningen
    [Binders]::Tegn($g, 12, 4, 30, [Drawing.Color]::FromArgb(11, 10, 18), 5); [Binders]::Tegn($g, 12, 4, 30, [Drawing.Color]::FromArgb(196, 192, 222), 2.5)
    $g.Restore($st)
    if ($tekst) {
        $x0 = $(if ($venstre) { 0 } else { 44 }); $w = $b - 44
        $pill = New-Object Drawing.Drawing2D.GraphicsPath
        $pill.AddArc($x0, 6, 28, 28, 90, 180); $pill.AddArc($x0 + $w - 28, 6, 28, 28, 270, 180); $pill.CloseFigure()
        $bak = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb([int](225 * $alfa), 11, 10, 18)); $g.FillPath($bak, $pill); $bak.Dispose(); $pill.Dispose()
        $pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb([int](196 * $alfa), 196, 192, 222), 2); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
        $g.DrawArc($pen, $x0 + 9, 13, 14, 14, $vinkel, 250); $pen.Dispose()
        $tb = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb([int](217 * $alfa), 217, 214, 238)); $sf = New-Object Drawing.StringFormat; $sf.LineAlignment = 'Center'
        $g.DrawString($tekst, $fSmå, $tb, (New-Object Drawing.RectangleF(($x0 + 30), 6, ($w - 30), 28)), $sf); $tb.Dispose(); $sf.Dispose()
    }
    $g.Dispose(); return $bmp
}
$script:musTekst = $null; $script:musVinkel = 0; $script:musBmp = $null; $script:musB = 40; $script:musVenstre = $false; $script:musWaR = 99999
$script:musRefT = 0; $script:musRefX = [Windows.Forms.Cursor]::Position.X; $script:musRefY = [Windows.Forms.Cursor]::Position.Y
$script:musRet = -90.0; $script:musRetMål = -90.0; $script:musStille = 0; $script:musCX = 0; $script:musCY = 0
$musKlokke = New-Object Windows.Forms.Timer
$musKlokke.Interval = 10
$script:musSW = [Diagnostics.Stopwatch]::StartNew(); $script:musTid = 0; $script:musTegnT = 0
[void][Vin]::timeBeginPeriod(1)
$musKlokke.Add_Tick({ try {
    $nu = $script:musSW.ElapsedMilliseconds; $dt = [Math]::Min(100, [Math]::Max(1, $nu - $script:musTid)); $script:musTid = $nu
    if ($peker.Visible) { Peker-Steg $dt }
    if ($script:pause -or -not $script:musPå) { if ($script:musVist) { $mus.Hide(); $script:musVist = $false; $script:musX = $null; $script:musFramme = $false }; return }
    if ($musInn.Visible) { return }   # skrivefeltet står ved siden av: bindersen holder seg i ro
    if ($peker.Visible -and $script:jobb) { $script:musX = $script:px - 20; $script:musY = $script:py - 20; $script:musFramme = $false; $script:musRet = -90.0; $peker.Hide() }   # Bindy tenker: bindersen går tilbake til å følge musa (og flyr ut igjen med neste svar)
    if ($peker.Visible) {   # veiledning: det er denne bindersen som flyr til målet (pekeren overtar), og den kommer tilbake herfra når pekeren er ferdig
        if ($script:musVist) { $mus.Hide(); $script:musVist = $false }
        $script:musX = $script:px - 20; $script:musY = $script:py - 20; $script:musFramme = $false; $script:musRet = -90.0; return
    }
    $tekst = Mus-Tekst; $ny = $false; $alfa = 1.0
    if ($tekst) { $script:musSist = $tekst; $script:musFade = 12 }
    elseif ($script:musFade -gt 0 -and $script:musSist) {   # myk fade ut når tenkingen er ferdig (ikke med «reduser animasjon»)
        if ($script:rolig) { $script:musFade = 0 } else { $script:musFade -= $dt / 16.0; $tekst = $script:musSist; $alfa = [Math]::Max(0, $script:musFade / 12.0); $ny = $true }
    }
    if ($tekst) { if (-not $script:rolig) { $script:musVinkel = ($script:musVinkel + 0.5 * $dt) % 360 }; if (-not $script:musBmp -or (-not $script:rolig -and ($nu - $script:musTegnT) -ge 33)) { $ny = $true } }
    if ($tekst -ne $script:musTekst) { $script:musTekst = $tekst; $ny = $true }
    $c = [Windows.Forms.Cursor]::Position
    $cdx = $c.X - $script:musCX; $cdy = $c.Y - $script:musCY
    if (($nu - $script:musRefT) -ge 25) {   # retningen måles over 25 ms-vinduer (jevnere enn hver tikk)
        $rx = $c.X - $script:musRefX; $ry = $c.Y - $script:musRefY
        if ([Math]::Abs($rx) + [Math]::Abs($ry) -ge 3) { $script:musRetMål = [Math]::Atan2($ry, $rx) * 180 / [Math]::PI; $script:musStille = 0 }   # utstikkeren peker i bevegelsesretningen
        else { $script:musStille += $nu - $script:musRefT }
        $script:musRefT = $nu; $script:musRefX = $c.X; $script:musRefY = $c.Y
    }
    if ($script:musStille -gt 100 -or $script:rolig) { $script:musRetMål = -90.0 }   # musa har stoppet (eller «reduser animasjon»): rett opp
    $dv = (($script:musRetMål - $script:musRet + 540) % 360) - 180
    if ([Math]::Abs($dv) -gt 0.5) { $script:musRet += $dv * $(if ($script:rolig) { 1 } else { 1 - [Math]::Exp(-$dt / 70.0) }); $ny = $true }
    $v = ($null -ne $script:musX) -and ($script:musX + $script:musB -gt $script:musWaR)   # pillen vil gå utenfor høyre kant: legg den til venstre for ikonet
    if ($v -ne $script:musVenstre) { $script:musVenstre = $v; $ny = $true }
    $vx = $(if ($script:musVenstre) { $script:musB - 40 } else { 0 })   # vinduet starter så langt til venstre for ikonet
    if ($ny -or -not $script:musBmp) {
        $gammel = $script:musBmp; $script:musBmp = Tegn-Mus $tekst $script:musVinkel $script:musRet $alfa $script:musVenstre; $script:musB = $script:musBmp.Width; $script:musTegnT = $nu
        $vx = $(if ($script:musVenstre) { $script:musB - 40 } else { 0 })
        if ($gammel) { $gammel.Dispose() }
        if ($script:musVist) { $mus.Vis($script:musBmp, [int][Math]::Round($script:musX) - $vx, [int][Math]::Round($script:musY)) }
    }
    if ($script:musFramme -and -not $ny -and $cdx -eq 0 -and $cdy -eq 0) { return }   # musa i ro og ikonet framme: ingenting å gjøre
    $script:musCX = $c.X; $script:musCY = $c.Y; $script:musFramme = $false
    $wa = [Windows.Forms.Screen]::FromPoint($c).WorkingArea; $script:musWaR = $wa.Right
    $m = Mus-Mål $c.X $c.Y 40 40 $wa   # ikonet holder seg alltid ved musa; bare pillen flippes
    if ($null -eq $script:musX) { $script:musX = [double]$m[0]; $script:musY = [double]$m[1] }
    else {
        $dx = $m[0] - $script:musX; $dy = $m[1] - $script:musY
        if ([Math]::Abs($dx) -lt 1 -and [Math]::Abs($dy) -lt 1) { $script:musFramme = $true; if ($dx -eq 0 -and $dy -eq 0) { return }; $script:musX = [double]$m[0]; $script:musY = [double]$m[1] }
        else { $k = $(if ($script:rolig) { 1 } else { 1 - [Math]::Exp(-$dt / 45.0) }); $script:musX += $dx * $k; $script:musY += $dy * $k }
    }
    $wx = [int][Math]::Round($script:musX) - $vx; $wy = [int][Math]::Round($script:musY)
    if (-not $script:musVist) { $mus.Show(); $mus.Vis($script:musBmp, $wx, $wy); $script:musVist = $true }
    else { $mus.Flytt($wx, $wy) }
} catch { try { Add-Content (Join-Path $Mappe 'bindy-feil.log') "$(Get-Date -Format s) musefølger: $_" } catch {} } })
$musKlokke.Start()

# Skrivefeltet som dukker opp ved bindersen når du trykker hurtigtasten. Enter spør, Ctrl+Enter veileder, Esc eller å klikke bort lukker.
$musInn = New-Object InnVindu; $musInn.BackColor = (Farge '#4a4672'); $musInn.Text = 'Spør Bindy'; $musInn.AccessibleName = 'Spør Bindy'; $musInn.Padding = New-Object Windows.Forms.Padding(0); $musInn.Size = New-Object Drawing.Size((S 340), (S 44))
$cInnFlate = Farge '#1a1827'
$musInnPanel = New-Object Windows.Forms.Panel; $musInnPanel.Dock = 'Fill'; $musInnPanel.BackColor = $cInnFlate; $musInnPanel.Padding = New-Object Windows.Forms.Padding((S 22), (S 11), (S 18), (S 11))
$musInnTb = New-Object Windows.Forms.TextBox; $musInnTb.BorderStyle = 'None'; $musInnTb.BackColor = $cInnFlate; $musInnTb.ForeColor = $cTekst; $musInnTb.Font = $fTekst; $musInnTb.Dock = 'Fill'
$musInnTb.Multiline = $true; $musInnTb.WordWrap = $true; $musInnTb.ScrollBars = 'None'; $musInnTb.AcceptsReturn = $true   # ellers får ikke KeyDown Enter i et felt med flere linjer, og Enter blir bare en ny linje
$musInnTb.AccessibleName = 'Spør Bindy'
$musInnHint = New-Object Windows.Forms.Label; $musInnHint.Text = 'Spør (Enter)  ·  veiled (Ctrl+Enter)'; $musInnHint.ForeColor = $cDempet; $musInnHint.BackColor = $cInnFlate; $musInnHint.Font = $fTekst; $musInnHint.AutoSize = $true; $musInnHint.Location = New-Object Drawing.Point((S 22), (S 11)); $musInnHint.AccessibleName = 'Hjelpetekst'
$musInnHint.Add_Click({ $musInnTb.Focus() })
$musInnPanel.Controls.Add($musInnTb); $musInnPanel.Controls.Add($musInnHint); $musInnHint.BringToFront(); $musInn.Controls.Add($musInnPanel)
# Kanten tegnes på panelet med samme avrunding som vinduet (en kant som bare var vindusbakgrunn forsvant i de runde hjørnene).
$musInnPanel.Add_Resize({ $musInnPanel.Invalidate() })
$musInnPanel.Add_Paint({ param($snd, $ev)
    $g = $ev.Graphics; $g.SmoothingMode = 'AntiAlias'
    $w = $snd.Width - 1; $h = $snd.Height - 1; $d = [Math]::Min($snd.Height, 52) - 1
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    $p.AddArc(0.75, 0.75, $d, $d, 180, 90); $p.AddArc($w - $d - 0.75, 0.75, $d, $d, 270, 90); $p.AddArc($w - $d - 0.75, $h - $d - 0.75, $d, $d, 0, 90); $p.AddArc(0.75, $h - $d - 0.75, $d, $d, 90, 90); $p.CloseFigure()
    $fokus = $musInnTb.Focused   # lys aksentkant mens du skriver her
    $pn = New-Object Drawing.Pen($(if ($fokus) { $cAksent } else { Farge '#4a4672' }), $(if ($fokus) { 2.0 } else { 1.5 })); $g.DrawPath($pn, $p); $pn.Dispose(); $p.Dispose()
})
$script:musInnLukker = $false
# Vinduet vokser og krymper med teksten du skriver. Over 60 % av skjermhøyden får feltet rullefelt.
function Mus-Størr {
    $wa = [Windows.Forms.Screen]::FromControl($musInn).WorkingArea
    $t = $musInnTb.Text; if (-not $t) { $t = ' ' }; if ($t.EndsWith("`n")) { $t += ' ' }
    $m = [Windows.Forms.TextRenderer]::MeasureText($t, $musInnTb.Font, (New-Object Drawing.Size(($musInnTb.Width), 0)), [Windows.Forms.TextFormatFlags]::WordBreak -bor [Windows.Forms.TextFormatFlags]::NoPadding)
    $maks = [int]($wa.Height * 0.6); $ønsket = $m.Height + $musInnPanel.Padding.Vertical + 4
    $musInnTb.ScrollBars = $(if ($ønsket -gt $maks) { 'Vertical' } else { 'None' })
    $h = [Math]::Max((S 44), [Math]::Min($maks, $ønsket))
    $musInnHint.Visible = -not $musInnTb.Text; $musInnHint.Left = S 30
    if ($h -ne $musInn.Height) { $y = [Math]::Max($wa.Top, [Math]::Min($musInn.Top, $wa.Bottom - $h)); $musInn.SetBounds($musInn.Left, $y, $musInn.Width, $h) }
    $musInnPanel.Invalidate()
}
$musInnTb.Add_TextChanged({ if ($musInn.Visible) { Mus-Størr } })
$musInnTb.Add_GotFocus({ $musInnPanel.Invalidate() }); $musInnTb.Add_LostFocus({ $musInnPanel.Invalidate() })
function Skjul-MusInn { $script:musInnLukker = $true; $musInn.Hide(); $script:musInnLukker = $false }
function Vis-MusInn {
    $c = [Windows.Forms.Cursor]::Position
    if ($null -eq $script:musX) { $m = Mus-Mål $c.X $c.Y 40 40 ([Windows.Forms.Screen]::FromPoint($c).WorkingArea); $mx = $m[0]; $my = $m[1] } else { $mx = [int]$script:musX; $my = [int]$script:musY }
    $wa = [Windows.Forms.Screen]::FromPoint($c).WorkingArea
    $musInnTb.Text = ''; $musInn.Height = S 44;
    $x = $mx + 44; if ($x + $musInn.Width -gt $wa.Right) { $x = [Math]::Max($wa.Left, $mx - 4 - $musInn.Width) }
    $y = [Math]::Min([Math]::Max($wa.Top, $my + 20 - [int]($musInn.Height / 2)), $wa.Bottom - $musInn.Height)
    $musInn.Location = New-Object Drawing.Point($x, $y); $musInn.Show(); Mus-Størr; [Vin]::Topp($musInn)
    [void][Vin]::SetForegroundWindow($musInn.Handle); $musInn.Activate(); $musInnTb.Focus()
    if ([Vin]::GetForegroundWindow() -ne $musInn.Handle) { Skjul-MusInn; Skjul-Mentor }   # fikk ikke fokus: lukk i stedet for å la bildet bli liggende
}
# Enter: skrivefeltet lukkes og bindersen svarer i en taleboks. Får ikke spørsmålet gå av gårde, åpnes feltet igjen med teksten.
function Mus-Spør {
    $q = $musInnTb.Text; $inn.Text = $q
    Skjul-MusInn
    Send-Spørsmål 'spor'
    if (-not $script:jobb) { Vis-MusInn; $musInnTb.Text = $q; $musInnTb.SelectionStart = $musInnTb.Text.Length }
}
$musInnTb.Add_KeyDown({
    $ks = $_.KeyCode.ToString()   # Enter heter «Return» i .NET
    if ($ks -eq 'Return' -and $_.Shift -and -not $_.Control) { $musInnTb.SelectedText = "`r`n"; $_.SuppressKeyPress = $true }   # Shift+Enter: ny linje
    elseif ($ks -eq 'Return' -and $script:jobb) { $_.SuppressKeyPress = $true; Sett-Toast 'Bindy tenker. Prøv igjen om et øyeblikk.' }
    elseif ($ks -eq 'Return') { $_.SuppressKeyPress = $true; if ($_.Control) { $inn.Text = $musInnTb.Text; Skjul-MusInn; Send-Spørsmål 'start' } else { Mus-Spør } }
    elseif ($ks -eq 'Escape') { $_.SuppressKeyPress = $true; Skjul-MusInn; Skjul-Mentor }
})
$musInn.Add_Deactivate({ if ($musInn.Visible -and -not $script:musInnLukker) { Skjul-MusInn; Skjul-Mentor } })   # klikket bort: bildet slettes

[void][Vin]::Ekskluder($musInn)

# Klokke 2 (700 ms): oppfølgingen under veiledning.
$veiKlokke = New-Object Windows.Forms.Timer
$veiKlokke.Interval = 250
$veiKlokke.Add_Tick({ try { Følg-Med } catch { } })

# Klokke 3 (15 ms, tidsbasert): animasjoner: øya vokser og krymper, tones inn og ut, binders hopper, ring, skrivemaskin, peker.
$animKlokke = New-Object Windows.Forms.Timer
$animKlokke.Interval = 15
$script:animSW = [Diagnostics.Stopwatch]::StartNew(); $script:animSist = 0; $script:animAkk = 0
$animKlokke.Add_Tick({
    $tegn = $false
    $nu = $script:animSW.ElapsedMilliseconds; $dt = [Math]::Min(100, [Math]::Max(1, $nu - $script:animSist)); $script:animSist = $nu; $r = $dt / 30.0
    $script:animAkk += $dt; $trinn = $script:animAkk -ge 30; if ($trinn) { $script:animAkk -= 30 }   # tellere (hopp, blink, skrivemaskin) går i 30 ms-trinn
    $o = $form.Opacity; $m = $script:fadeMål   # tone inn/ut
    if ([Math]::Abs($o - $m) -gt 0.001 -and $script:ovSkjult.Count -eq 0) {
        $o = $(if ($o -lt $m) { [Math]::Min($m, $o + 0.14 * $r) } else { [Math]::Max($m, $o - 0.12 * $r) }); $form.Opacity = $o
        if ($o -le 0.001 -and $m -eq 0) {
            $form.Hide()
            if (-not $script:vei) { $inn.Text = ''; $svar.Text = ''; $script:svarFull = ''; $script:svarSynlig = $false }
        }
    }
    if ([Math]::Abs($script:iB - $script:iBm) -gt 0.4 -or [Math]::Abs($script:iH - $script:iHm) -gt 0.4) {   # øya glir mot målstørrelsen
        $kb = 1 - [Math]::Pow(0.72, $r); $script:iB += ($script:iBm - $script:iB) * $kb; $script:iH += ($script:iHm - $script:iH) * $kb; $tegn = $true
        Vis-Innhold
    } elseif ($script:iB -ne $script:iBm -or $script:iH -ne $script:iHm) { $script:iB = $script:iBm; $script:iH = $script:iHm; $tegn = $true; Vis-Innhold }
    if ($script:rolig) { $script:hopp = 0 }
    if ($script:hopp -gt 0 -and $trinn) { $script:hopp--; $script:bob = -[int](8 * [Math]::Sin([Math]::PI * (1 - $script:hopp / 9.0))); $tegn = $true }
    if ($script:ring -gt 0) { $script:ring = [Math]::Max(0, $script:ring - 0.045 * $r); $tegn = $true }
    if ($trinn -and -not $script:strømmer -and $script:svarFull -and $script:visN -lt $script:svarFull.Length) {   # skrivemaskin (ikke når svaret strømmet inn)
        $script:visN = [Math]::Min($script:svarFull.Length, $script:visN + [Math]::Max(2, [int]($script:svarFull.Length / 25)))
        $svar.Text = $script:svarFull.Substring(0, $script:visN)
    }
    if ($script:knappFlash -gt 0 -and $trinn) { $script:knappFlash--; $knapp.BackColor = $(if ($script:knappFlash % 2) { Farge '#b3acd9' } else { Farge '#8f87c2' }) }
    if ($script:tipsTil -and [DateTime]::Now -gt $script:tipsTil) { $lblTips.Text = $TipsStandard; $script:tipsTil = $null }
    if ($script:toastTil -and [DateTime]::Now -gt $script:toastTil) { $script:toastTil = $null; $tegn = $true }
    if ($tegn -or ($script:jobb -and $trinn)) { $form.Invalidate() }
    if (($script:toppT = 1 + [int]$script:toppT) % 5 -eq 0) { foreach ($f in @($overlegg, $ramme, $peker, $mus, $musInn)) { [Vin]::Topp($f) } }   # hold tegningen over oppgavelinja og menyer
    if ($script:ovShapes -and $overlegg.Visible) {
        $script:ovFrame++; $alder = ([DateTime]::Now - $script:ovStart).TotalSeconds
        if ($alder -lt 1.4 -or $script:ovFrame % 4 -eq 0 -or $script:ovNy) { $script:ovNy = $false; Tegn-Overlegg }
    }
})
$animKlokke.Start()

$hk = New-Object HurtigtastVindu
$tray.ShowBalloonTip(5000, 'Bindy', $(if ($script:ClaudeSti) { 'Bindy kjører. Trykk Ctrl+Alt+H for å spørre, eller dobbeltklikk binders-ikonet.' } else { 'Fant ikke claude. Installer Claude Code og logg inn (se docs/INSTALLASJON.md), start så Bindy på nytt.' }), $(if ($script:ClaudeSti) { 'Info' } else { 'Warning' }))
if (-not $hk.Registrer(1, 0x4003, 0x48)) { $tray.ShowBalloonTip(5000, 'Bindy', 'Ctrl+Alt+H er opptatt. Kjører Bindy allerede, eller har en annen app tatt den?', 'Warning') }   # H: spør med skjerm
if (-not $hk.Registrer(2, 0x4003, 0x4A)) { $tray.ShowBalloonTip(5000, 'Bindy', 'Ctrl+Alt+J er opptatt. Kjører Bindy allerede, eller har en annen app tatt den?', 'Warning') }   # J: bare spørsmål
if (-not $hk.Registrer(3, 0x4003, 0x50)) { $tray.ShowBalloonTip(5000, 'Bindy', 'Ctrl+Alt+P er opptatt. Kjører Bindy allerede, eller har en annen app tatt den?', 'Warning') }   # P: pause
if (-not $hk.Registrer(4, 0x4003, 0x4E)) { $tray.ShowBalloonTip(5000, 'Bindy', 'Ctrl+Alt+N er opptatt.', 'Warning') }   # N: neste steg
$hk.add_Trykket({ param($id) try {
    if ($id -eq 3) { Sett-Pause (-not $script:pause); return }
    if ($id -eq 4) { Neste-Steg; return }
    if ($script:jobb) { return }
    if ($script:pause -and $id -eq 1) { Sett-Toast 'Pauset. Ctrl+Alt+P for å fortsette'; return }
    $script:kollapsTid = $null
    $svar.Text = ''; $script:svarFull = ''; $script:svarSynlig = $false; $inn.Text = ''
    if ($id -eq 2) {   # bare spørsmål, ingen skjerm
        Sett-Skjerm 'av'
    } else {
        Skjul-Ramme; if ($script:vei) { $peker.Hide() }
        $f = Fang-Etter 'vindu'
        if (-not $f.ok) { $tray.ShowBalloonTip(3000, 'Bindy', $f.grunn, 'Warning'); return }
        $script:skjermModus = $(if ($f.liten) { 'alle' } else { 'vindu' }); $knappSkjerm.Text = $(if ($f.liten) { 'Skjerm: alle' } else { 'Skjerm: vindu' })
        Bruk-Bilde $f
    }
    Vis-MusInn
} catch { Add-Content (Join-Path $Mappe 'bindy-feil.log') "$(Get-Date -Format s) $_"; $tray.ShowBalloonTip(4000, 'Bindy', "Feil: $_", 'Error') } })

try { [Windows.Forms.Application]::Run() } finally { $hk.Dispose(); [MuseKrok]::Stopp(); [void][Vin]::timeEndPeriod(1) }
