// Superguide executor: clicks, scrolls, types, hotkeys and opens apps. Every action goes through Port() first, so the hard limits
// live here in signed code and cannot be changed by what Claude answers. Results are "OK" or "FEIL:<code>[:detail]", never silent.
// Compiled into BindyStart.exe (so SendInput runs with its UI access) and also loadable with Add-Type for tests (scripts\test-utforer.ps1).
// snarvei: coordinates assume system DPI awareness (bindy.ps1 calls SetProcessDPIAware); mixed-DPI multi-monitor needs per-monitor awareness.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Automation;

public static class SgUtforer {
    // ---- Win32 ----
    [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx, dy; public uint data, flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort vk, scan; public uint flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] struct INPUTU { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public INPUTU u; }
    [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cb, time; }
    [StructLayout(LayoutKind.Sequential)] struct PT { public int x, y; }
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] i, int size);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO i);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(PT p);
    [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr h, uint f);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [StructLayout(LayoutKind.Sequential)] struct GUITHREADINFO { public int cb, flags; public IntPtr active, focus, capture, menu, move, caret; public int l, t, r, b; }
    [DllImport("user32.dll")] static extern bool GetGUIThreadInfo(uint thread, ref GUITHREADINFO i);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);

    // ---- State and limits (Start() resets) ----
    static string sperret, sperretProsess;
    static bool klar;
    static volatile bool stopp;
    static int steg, maxSteg = 40, apninger;
    const int MaxApninger = 30, MinPauseMs = 300;
    static DateTime start, sist = DateTime.MinValue;
    static uint egenInput;
    static int maxSek = 300;
    static readonly object lås = new object();
    // Needs Henrik's own click: payments, deleting, uninstalling, sending, security settings. Matched on window title and element name.
    static readonly Regex Bekreft = new Regex("uninstall|avinstaller|delete|slett|formater|format (disk|drive|station)|betal|payment|purchase|checkout|kjøp|buy now|^send$|send (e-?post|melding|message|email)|firewall|brannmur|defender|user account control|brukerkontokontroll|smartscreen|reset this pc|tilbakestill pc|empty recycle|tøm papirkurv", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    // Typing here would be running code: terminals and the registry always need Henrik himself.
    static readonly Regex ProsessKreverHenrik = new Regex("^(cmd|powershell|powershell_ise|pwsh|windowsterminal|wt|conhost|regedit|mmc)$", RegexOptions.IgnoreCase);
    static readonly Regex AppNekt = new Regex("uninstall|avinstaller|setup|install|regedit|cmd|powershell|terminal|command prompt|ledetekst", RegexOptions.IgnoreCase);

    // Set the block lists (the same patterns bindy.ps1 uses for screenshots). Without this every action is refused.
    public static void Init(string tittelMonster, string prosessMonster) {
        if (string.IsNullOrEmpty(tittelMonster) || string.IsNullOrEmpty(prosessMonster)) { klar = false; return; }
        new Regex(tittelMonster); new Regex(prosessMonster);   // throws on a bad pattern: better than running unprotected
        sperret = tittelMonster; sperretProsess = prosessMonster; klar = true;
    }
    public static void Start(int maksSteg, int maksSekunder) {
        lock (lås) {
            maxSteg = Math.Max(1, Math.Min(maksSteg, 200)); maxSek = Math.Max(10, Math.Min(maksSekunder, 1800));
            steg = 0; apninger = 0; stopp = false; start = DateTime.Now; sist = DateTime.MinValue; egenInput = SisteInput();
        }
    }
    public static void Stopp() { stopp = true; }
    public static bool ErStoppet { get { return stopp; } }
    public static int Steg { get { return steg; } }

    // ---- Public actions ----
    public static string Klikk(int x, int y) { return Mus("KLIKK", x, y, 0x0002, 0x0004, 1); }
    public static string Dobbeltklikk(int x, int y) { return Mus("DKLIKK", x, y, 0x0002, 0x0004, 2); }
    public static string HoyreKlikk(int x, int y) { return Mus("HKLIKK", x, y, 0x0008, 0x0010, 1); }

    public static string Scroll(int x, int y, string retning, int mengde) {
        int d = (retning == "opp" ? 1 : retning == "ned" ? -1 : 0);
        if (d == 0 || mengde < 1 || mengde > 20) return Svar("SCROLL", "FEIL:UGYLDIG:retning/mengde");
        string g = Port("SCROLL", true, x, y); if (g != null) return Svar("SCROLL", g);
        SetCursorPos(x, y);
        INPUT[] i = new INPUT[1]; i[0].type = 0; i[0].u.mi.flags = 0x0800; i[0].u.mi.data = (uint)(d * mengde * 120);
        return Send("SCROLL", i);
    }

    public static string Skriv(string tekst) {
        if (tekst == null || tekst.Length < 1 || tekst.Length > 500) return Svar("SKRIV", "FEIL:UGYLDIG:lengde");
        foreach (char c in tekst) if (char.IsControl(c)) return Svar("SKRIV", "FEIL:UGYLDIG:kontrolltegn (bruk Tast for Enter)");
        string g = Port("SKRIV", false, 0, 0); if (g != null) return Svar("SKRIV", g);
        string pw = FokusPassord(); if (pw != null) return Svar("SKRIV", pw);
        List<INPUT> l = new List<INPUT>();
        foreach (char c in tekst) { l.Add(Ki(0, c, 0x0004)); l.Add(Ki(0, c, 0x0004 | 0x0002)); }
        return Send("SKRIV", l.ToArray());
    }

    // "ctrl+s", "alt+f4", "enter", "win+d". Win combinations other than d/e/i/s/a are refused (Win+R and friends run code).
    public static string Tast(string kombinasjon) {
        ushort[] mods; ushort key; string fe = Les(kombinasjon, out mods, out key);
        if (fe != null) return Svar("TAST", fe);
        string g = Port("TAST", false, 0, 0); if (g != null) return Svar("TAST", g);
        List<INPUT> l = new List<INPUT>();
        foreach (ushort m in mods) l.Add(Ki(m, 0, 0));
        l.Add(Ki(key, 0, ErUtvidet(key) ? 0x0001u : 0)); l.Add(Ki(key, 0, (ErUtvidet(key) ? 0x0001u : 0) | 0x0002));
        for (int k = mods.Length - 1; k >= 0; k--) l.Add(Ki(mods[k], 0, 0x0002));
        return Send("TAST", l.ToArray());
    }

    // Opens an app from Get-StartApps by its AppID (bindy.ps1 does the name lookup).
    public static string ApneApp(string appId) {
        if (appId == null || !Regex.IsMatch(appId, @"^[\w.!\-\\ ]{1,256}$") || AppNekt.IsMatch(appId)) return Svar("APP", "FEIL:UGYLDIG:app-id");
        string g = Port("APP", false, 0, 0); if (g != null) return Svar("APP", g);
        lock (lås) { if (apninger >= MaxApninger) return Svar("APP", "FEIL:TAK_APP"); apninger++; }
        try { Process.Start("explorer.exe", "shell:AppsFolder\\" + appId); } catch (Exception e) { return Svar("APP", "FEIL:START:" + e.Message); }
        return Svar("APP", "OK");
    }

    // Finds an element by name in the foreground window: "OK:x:y" (centre) or an error. Button-like elements first.
    public static string FinnElement(string navn) {
        if (string.IsNullOrEmpty(navn) || navn.Length > 100) return Svar("FINN", "FEIL:UGYLDIG:navn");
        string g = Port("FINN", false, 0, 0); if (g != null) return Svar("FINN", g);
        string res = null;
        bool ferdig = MedTidsavbrudd(delegate {
            AutomationElement rot = AutomationElement.FromHandle(GetForegroundWindow());
            AutomationElement e = rot.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.NameProperty, navn));
            if (e == null) { res = "FEIL:IKKE_FUNNET"; return; }
            System.Windows.Rect r = e.Current.BoundingRectangle;
            res = (r.IsEmpty || r.Width < 1) ? "FEIL:IKKE_FUNNET:utenfor skjermen" : "OK:" + (int)(r.X + r.Width / 2) + ":" + (int)(r.Y + r.Height / 2);
        });
        return Svar("FINN", ferdig ? res : "FEIL:UIA_TIDSAVBRUDD");
    }

    // Waits in 50 ms slices so Stopp()/Esc/user input ends it within a fraction of a second.
    public static string Vent(int ms) {
        if (ms < 0 || ms > 10000) return Svar("VENT", "FEIL:UGYLDIG:ms");
        DateTime slutt = DateTime.Now.AddMilliseconds(ms);
        while (DateTime.Now < slutt) { string s = Avbrudd(); if (s != null) return Svar("VENT", s); Thread.Sleep(50); }
        return "OK";
    }

    // ---- Gate ----
    static string Avbrudd() {   // stop conditions that need no window: Stopp(), Esc held, Henrik touched mouse/keyboard
        if (stopp) return "FEIL:STOPPET";
        if ((GetAsyncKeyState(0x1B) & 0x8000) != 0) { stopp = true; return "FEIL:STOPPET:Esc"; }
        if (SisteInput() != egenInput) { stopp = true; return "FEIL:BRUKER_RORTE"; }
        return null;
    }

    // Returns null when the action may run, otherwise the error. Every action passes here.
    static string Port(string handling, bool harPunkt, int x, int y) {
        if (!klar) return "FEIL:IKKE_KLAR";
        string a = Avbrudd(); if (a != null) return a;
        lock (lås) {
            if (steg >= maxSteg) return "FEIL:TAK_STEG";
            if ((DateTime.Now - start).TotalSeconds > maxSek) return "FEIL:TAK_TID";
        }
        TimeSpan siden = DateTime.Now - sist;
        if (siden.TotalMilliseconds < MinPauseMs) { string v = Vent(MinPauseMs - (int)siden.TotalMilliseconds); if (v != "OK") return v.Substring(v.IndexOf("FEIL")); }
        IntPtr fg = GetForegroundWindow();
        if (fg == IntPtr.Zero) return "FEIL:UAC:ingen vindu i forgrunnen (sikkert skrivebord?). Trykk selv.";
        string v1 = VinduDom(fg); if (v1 != null) return v1;
        if (harPunkt) {
            int vx = GetSystemMetrics(76), vy = GetSystemMetrics(77), vb = GetSystemMetrics(78), vh = GetSystemMetrics(79);
            if (x < vx || y < vy || x >= vx + vb || y >= vy + vh) return "FEIL:UGYLDIG:utenfor skjermen";
            PT p; p.x = x; p.y = y; IntPtr child = WindowFromPoint(p); IntPtr under = GetAncestor(child, 2);
            if (ErPassordHwnd(child)) return "FEIL:PASSORDFELT";
            if (under != IntPtr.Zero) { string v2 = VinduDom(under); if (v2 != null) return v2; }
            string el = null;
            if (!MedTidsavbrudd(delegate {
                AutomationElement e = AutomationElement.FromPoint(new System.Windows.Point(x, y));
                if (e == null) return;
                if ((bool)e.GetCurrentPropertyValue(AutomationElement.IsPasswordProperty)) el = "FEIL:PASSORDFELT";
                else if (Bekreft.IsMatch(e.Current.Name ?? "")) el = "FEIL:KREVER_HENRIK:" + Kort(e.Current.Name);
            })) return "FEIL:UIA_TIDSAVBRUDD";
            if (el != null) return el;
        }
        return null;
    }

    static string VinduDom(IntPtr h) {
        StringBuilder sb = new StringBuilder(512); GetWindowText(h, sb, 512); string t = sb.ToString();
        string pn = ProsessNavn(h);
        if (pn == "consent" || pn == "LogonUI" || pn == "SecureDesktop") return "FEIL:UAC:Trykk selv.";
        if (Regex.IsMatch(t, sperret, RegexOptions.IgnoreCase) || Regex.IsMatch(pn, sperretProsess, RegexOptions.IgnoreCase)) return "FEIL:SPERRET:" + Kort(t);
        if (ProsessKreverHenrik.IsMatch(pn)) return "FEIL:KREVER_HENRIK:" + pn;
        if (Bekreft.IsMatch(t)) return "FEIL:KREVER_HENRIK:" + Kort(t);
        return null;
    }
    // UIA's IsPassword depends on the control's provider, so also read the Win32 edit style ES_PASSWORD.
    static bool ErPassordHwnd(IntPtr h) {
        if (h == IntPtr.Zero) return false;
        StringBuilder k = new StringBuilder(128); GetClassName(h, k, 128);
        return k.ToString().IndexOf("EDIT", StringComparison.OrdinalIgnoreCase) >= 0 && (GetWindowLong(h, -16) & 0x20) != 0;
    }
    static string FokusPassord() {
        GUITHREADINFO gi = new GUITHREADINFO(); gi.cb = Marshal.SizeOf(typeof(GUITHREADINFO));
        if (GetGUIThreadInfo(0, ref gi) && ErPassordHwnd(gi.focus)) return "FEIL:PASSORDFELT";
        string res = null;
        if (!MedTidsavbrudd(delegate {
            AutomationElement e = AutomationElement.FocusedElement;
            if (e == null) { res = "FEIL:UIA_TIDSAVBRUDD:ukjent fokus"; return; }   // refuse to type into something unknown
            if ((bool)e.GetCurrentPropertyValue(AutomationElement.IsPasswordProperty)) res = "FEIL:PASSORDFELT";
        })) return "FEIL:UIA_TIDSAVBRUDD";
        return res;
    }

    // ---- Helpers ----
    static string Mus(string navn, int x, int y, uint ned, uint opp, int antall) {
        string g = Port(navn, true, x, y); if (g != null) return Svar(navn, g);
        SetCursorPos(x, y);
        INPUT[] i = new INPUT[2 * antall];
        for (int k = 0; k < antall; k++) { i[2 * k].type = 0; i[2 * k].u.mi.flags = ned; i[2 * k + 1].type = 0; i[2 * k + 1].u.mi.flags = opp; }
        return Send(navn, i);
    }
    static string Send(string navn, INPUT[] i) {
        uint n = SendInput((uint)i.Length, i, Marshal.SizeOf(typeof(INPUT)));
        uint v = SisteInput();   // Windows stamps injected input a moment after SendInput returns: wait until the stamp stops moving
        for (int k = 0; k < 15; k++) { Thread.Sleep(20); uint v2 = SisteInput(); if (v2 == v) break; v = v2; }
        lock (lås) { steg++; sist = DateTime.Now; egenInput = v; }
        return Svar(navn, n == i.Length ? "OK" : "FEIL:SENDINPUT:" + n + "/" + i.Length + " (blokkert av et vindu med høyere rettigheter?)");
    }
    static INPUT Ki(ushort vk, ushort scan, uint flags) {
        INPUT i = new INPUT(); i.type = 1; i.u.ki.vk = vk; i.u.ki.scan = scan; i.u.ki.flags = flags; return i;
    }
    static bool ErUtvidet(ushort k) { return (k >= 0x21 && k <= 0x28) || k == 0x2D || k == 0x2E; }   // arrows, home/end, pgup/pgdn, ins/del
    static uint SisteInput() { LASTINPUTINFO l = new LASTINPUTINFO(); l.cb = 8; GetLastInputInfo(ref l); return l.time; }
    static string ProsessNavn(IntPtr h) {
        try { uint pid; GetWindowThreadProcessId(h, out pid); return Process.GetProcessById((int)pid).ProcessName; } catch { return ""; }
    }
    static string Kort(string s) { s = (s ?? "").Replace("\r", " ").Replace("\n", " "); return s.Length > 60 ? s.Substring(0, 60) : s; }
    // UIA can hang on a frozen window: run on a thread we may abandon.
    static bool MedTidsavbrudd(ThreadStart f) {
        Exception feil = null; Thread t = new Thread(delegate() { try { f(); } catch (Exception e) { feil = e; } });
        t.IsBackground = true; t.SetApartmentState(ApartmentState.MTA); t.Start();
        if (!t.Join(1500)) return false;
        return feil == null;
    }
    static string Les(string s, out ushort[] mods, out ushort key) {
        mods = new ushort[0]; key = 0;
        if (string.IsNullOrEmpty(s) || s.Length > 30) return "FEIL:UGYLDIG:tast";
        string[] d = s.ToLowerInvariant().Split('+'); List<ushort> m = new List<ushort>(); bool win = false; string tast = d[d.Length - 1];
        for (int k = 0; k < d.Length - 1; k++) {
            ushort v = d[k] == "ctrl" ? (ushort)0x11 : d[k] == "alt" ? (ushort)0x12 : d[k] == "shift" ? (ushort)0x10 : d[k] == "win" ? (ushort)0x5B : (ushort)0;
            if (v == 0 || m.Contains(v)) return "FEIL:UGYLDIG:modifikator";
            if (v == 0x5B) win = true; m.Add(v);
        }
        if (tast.Length == 1 && ((tast[0] >= 'a' && tast[0] <= 'z') || (tast[0] >= '0' && tast[0] <= '9'))) key = (ushort)char.ToUpperInvariant(tast[0]);
        else {
            Dictionary<string, ushort> n = new Dictionary<string, ushort> { { "enter", 0x0D }, { "tab", 0x09 }, { "esc", 0x1B }, { "space", 0x20 }, { "backspace", 0x08 }, { "delete", 0x2E }, { "home", 0x24 }, { "end", 0x23 }, { "pgup", 0x21 }, { "pgdn", 0x22 }, { "up", 0x26 }, { "down", 0x28 }, { "left", 0x25 }, { "right", 0x27 } };
            int f;
            if (n.ContainsKey(tast)) key = n[tast];
            else if (tast.Length > 1 && tast[0] == 'f' && int.TryParse(tast.Substring(1), out f) && f >= 1 && f <= 12) key = (ushort)(0x6F + f);
            else return "FEIL:UGYLDIG:tast";
        }
        if (win && !(m.Count == 1 && (tast == "d" || tast == "e" || tast == "i" || tast == "s" || tast == "a"))) return "FEIL:UGYLDIG:win-kombinasjon nektet";
        if (key == 0x2E && m.Contains(0x11) && m.Contains(0x12)) return "FEIL:UGYLDIG:ctrl+alt+delete nektet";
        mods = m.ToArray(); return null;
    }
    // Log: time, action, result. Never the typed text or screenshots.
    static string Svar(string handling, string res) {
        try {
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Bindy"); Directory.CreateDirectory(dir);
            string f = Path.Combine(dir, "superguide.log");
            if (File.Exists(f) && new FileInfo(f).Length > 262144) { File.Delete(f + ".old"); File.Move(f, f + ".old"); }
            File.AppendAllText(f, DateTime.Now.ToString("s") + " " + handling + " " + res + Environment.NewLine);
        } catch { }
        return res;
    }
}
