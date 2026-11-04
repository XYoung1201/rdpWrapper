using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class SessionNative {
  [StructLayout(LayoutKind.Sequential)] struct SessionInfo { public int Id; public IntPtr Name; public int State; }
  public class Session { public int Id; public string Name; public string User; public string Domain; public string Client; public int State; public int Protocol; }
  [DllImport("wtsapi32.dll", SetLastError=true)] static extern bool WTSEnumerateSessions(IntPtr server, int reserved, int version, out IntPtr buffer, out int count);
  [DllImport("wtsapi32.dll", SetLastError=true)] static extern bool WTSQuerySessionInformation(IntPtr server, int id, int info, out IntPtr buffer, out int length);
  [DllImport("wtsapi32.dll")] static extern void WTSFreeMemory(IntPtr buffer);
  [DllImport("wtsapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool WTSConnectSessionW(int source, int destination, string password, bool wait);
  [DllImport("wtsapi32.dll", SetLastError=true)] public static extern bool WTSLogoffSession(IntPtr server, int id, bool wait);
  static string Text(int id, int info) {
    IntPtr p; int size;
    if (!WTSQuerySessionInformation(IntPtr.Zero,id,info,out p,out size)) return "";
    try { return Marshal.PtrToStringAnsi(p) ?? ""; } finally { WTSFreeMemory(p); }
  }
  static int Protocol(int id) {
    IntPtr p; int size;
    if (!WTSQuerySessionInformation(IntPtr.Zero,id,16,out p,out size)) return -1;
    try { return Marshal.ReadInt16(p); } finally { WTSFreeMemory(p); }
  }
  public static Session[] List() {
    IntPtr p; int count;
    if (!WTSEnumerateSessions(IntPtr.Zero,0,1,out p,out count)) throw new System.ComponentModel.Win32Exception();
    var result = new List<Session>();
    try {
      int size = Marshal.SizeOf(typeof(SessionInfo));
      for(int i=0;i<count;i++) {
        var s=(SessionInfo)Marshal.PtrToStructure(IntPtr.Add(p,i*size),typeof(SessionInfo));
        result.Add(new Session {Id=s.Id,Name=Marshal.PtrToStringAnsi(s.Name),State=s.State,User=Text(s.Id,5),Domain=Text(s.Id,7),Client=Text(s.Id,10),Protocol=Protocol(s.Id)});
      }
    } finally { WTSFreeMemory(p); }
    return result.ToArray();
  }
}
