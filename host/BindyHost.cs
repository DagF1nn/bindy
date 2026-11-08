// Kjører bindy.ps1 (fra samme mappe) inni denne prosessen, så skriptets vinduer får denne eksefilas UI-tilgang (uiAccess).
// Tar ingen argumenter, så ingenting utenfra kan styre hva som kjøres.
using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;

public static class BindyHost {
    [STAThread]
    public static int Main() {
        bool ny; Mutex enkelt = new Mutex(true, @"Local"+(char)92+"BindyStart", out ny);   // bare én Bindy om gangen
        if (!ny) return 0;
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string skript = Path.Combine(dir, "bindy.ps1");
        if (!File.Exists(skript)) return 1;
        Runspace rs = RunspaceFactory.CreateRunspace();
        rs.ApartmentState = ApartmentState.STA;
        rs.ThreadOptions = PSThreadOptions.UseCurrentThread;
        rs.Open();
        Environment.CurrentDirectory = dir;
        // Ikke last moduler fra brukerens skrivbare mapper: bare Windows egne.
        Environment.SetEnvironmentVariable("PSModulePath", Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\Modules"));
        try {
            using (Pipeline p = rs.CreatePipeline()) {
                p.Commands.AddScript("Set-ExecutionPolicy -Scope Process Bypass -Force; & '" + skript.Replace("'", "''") + "'");
                p.Invoke();
            }
        } catch (Exception e) {
            Directory.CreateDirectory(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Bindy"));
            File.AppendAllText(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Bindy", "bindy-host-feil.log"), DateTime.Now + " " + e + Environment.NewLine);
            return 2;
        }
        GC.KeepAlive(enkelt);
        return 0;
    }
}
