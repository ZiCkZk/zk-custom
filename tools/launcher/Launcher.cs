// ZK-Custom.exe - lanzador del asistente.
// Pide permisos de administrador (manifest) y abre Wizard.ps1 con PowerShell, sin ventana de consola.
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("ZK-Custom")]
[assembly: System.Reflection.AssemblyProduct("ZK-Custom")]
[assembly: System.Reflection.AssemblyDescription("Personalizador visual de Windows 11")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]

static class Program
{
    [STAThread]
    static int Main(string[] args)
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string script = Path.Combine(dir, "Wizard.ps1");
        if (!File.Exists(script))
        {
            MessageBox.Show("No encuentro Wizard.ps1 junto a ZK-Custom.exe.\nMantén el .exe dentro de la carpeta del proyecto.",
                            "ZK-Custom", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        string ps = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
        var psi = new ProcessStartInfo(ps,
            "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\" " + string.Join(" ", args))
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            WorkingDirectory = dir
        };
        try { Process.Start(psi); }
        catch (Exception ex)
        {
            MessageBox.Show("No se pudo abrir el asistente:\n" + ex.Message, "ZK-Custom", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        return 0;
    }
}
