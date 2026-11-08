// Runs bindy.ps1 (from the same folder) inside this process, so the script windows get this executable's UI access (uiAccess).
// Takes no arguments, so nothing from outside can control what is run.
using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;

public static class BindyHost {
    [STAThread]
    public static int Main() {
        bool ny; Mutex enkelt = new Mutex(true, @"Local"+(char)92+"BindyStart", out ny);   // only one Bindy at a time
        if (!ny) return 0;
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string skript = Path.Combine(dir, "bindy.ps1");
        if (!File.Exists(skript)) return 1;
        // Do not load modules from folders the user can write to: only the ones Windows ships.
        Environment.SetEnvironmentVariable("PSModulePath", Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\Modules"));
        Runspace rs = RunspaceFactory.CreateRunspace();
        rs.ApartmentState = ApartmentState.STA;
        rs.ThreadOptions = PSThreadOptions.UseCurrentThread;
        rs.Open();
        Environment.CurrentDirectory = dir;
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
