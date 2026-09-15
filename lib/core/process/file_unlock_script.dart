/// Runs on the machine owning the destination file. Restart Manager identifies
/// actual file users; executable names and command-line substrings are not used.
const fileUnlockScript = r'''
function Unlock-DeployFile([string]$file) {
  if (!(Test-Path -LiteralPath $file -PathType Leaf)) { return }
  $fullPath = [IO.Path]::GetFullPath($file)
  try {
    if (-not ('JADeployLocks' -as [type])) {
      Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
public static class JADeployLocks {
  [StructLayout(LayoutKind.Sequential)] public struct UniqueProcess {
    public int Id; public System.Runtime.InteropServices.ComTypes.FILETIME Start;
  }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct Info {
    public UniqueProcess Process;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string Name;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string Service;
    public int Type; public uint Status; public uint Session;
    [MarshalAs(UnmanagedType.Bool)] public bool Restartable;
  }
  [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)] static extern int RmStartSession(out uint h, int flags, StringBuilder key);
  [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)] static extern int RmRegisterResources(uint h, uint n, string[] files, uint apps, IntPtr processes, uint services, IntPtr names);
  [DllImport("rstrtmgr.dll")] static extern int RmGetList(uint h, out uint needed, ref uint count, [In, Out] Info[] info, ref uint reasons);
  [DllImport("rstrtmgr.dll")] static extern int RmEndSession(uint h);
  public static Info[] Users(string file) {
    uint h; int code = RmStartSession(out h, 0, new StringBuilder(33));
    if (code != 0) throw new Win32Exception(code);
    try {
      code = RmRegisterResources(h, 1, new string[] { file }, 0, IntPtr.Zero, 0, IntPtr.Zero);
      if (code != 0) throw new Win32Exception(code);
      uint needed, count = 0, reasons = 0;
      code = RmGetList(h, out needed, ref count, null, ref reasons);
      for (int attempt=0; code==234 && attempt<5; attempt++) {
        count = needed; Info[] list = new Info[count];
        code = RmGetList(h, out needed, ref count, list, ref reasons);
        if (code==0) { Array.Resize(ref list, (int)count); return list; }
      }
      if (code != 0) throw new Win32Exception(code);
      return new Info[0];
    } finally { RmEndSession(h); }
  }
  public static string CloseUser(Info info, int protectedId) {
    if (info.Process.Id <= 4 || info.Process.Id == protectedId || info.Type == 3 || info.Type == 1000)
      throw new InvalidOperationException("Protected process/service holds the destination file");
    Process process;
    try { process = Process.GetProcessById(info.Process.Id); }
    catch (ArgumentException) { return null; }
    using (process) {
      long expected = ((long)info.Process.Start.dwHighDateTime << 32) | (uint)info.Process.Start.dwLowDateTime;
      if (process.StartTime.ToUniversalTime().ToFileTimeUtc() != expected) return null;
      string name = process.ProcessName;
      if (name == "ja_remote" || name == "wsmprovhost" || name == "explorer")
        throw new InvalidOperationException("Protected application holds the destination file");
      process.Kill();
      if (!process.WaitForExit(3000)) throw new TimeoutException("Lock holder did not exit");
      return "AUTO_KILL PID=" + info.Process.Id + " NAME=" + name;
    }
  }
}
'@
    }
    foreach ($holder in [JADeployLocks]::Users($fullPath)) {
      $result = [JADeployLocks]::CloseUser($holder, $PID)
      if ($result) { Write-Output "$result FILE=$file" }
    }
  } catch {}
}
''';
