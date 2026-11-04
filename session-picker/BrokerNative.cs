using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
public static class SessionProcess {
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct StartupInfo {
    public int Size; public string Reserved; public string Desktop; public string Title;
    public int X,Y,XSize,YSize,XCount,YCount,Fill,Flags; public short Show,ReservedSize;
    public IntPtr ReservedPointer,Input,Output,Error;
  }
  [StructLayout(LayoutKind.Sequential)] struct ProcessInfo {public IntPtr Process,Thread;public int ProcessId,ThreadId;}
  [DllImport("wtsapi32.dll",SetLastError=true)] static extern bool WTSQueryUserToken(int session,out IntPtr token);
  [DllImport("userenv.dll",SetLastError=true)] static extern bool CreateEnvironmentBlock(out IntPtr environment,IntPtr token,bool inherit);
  [DllImport("userenv.dll")] static extern bool DestroyEnvironmentBlock(IntPtr environment);
  [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcessAsUser(IntPtr token,string application,StringBuilder command,IntPtr processAttributes,IntPtr threadAttributes,bool inherit,int flags,IntPtr environment,string directory,ref StartupInfo startup,out ProcessInfo process);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
  public static void Start(int session,string executable,string command,string directory) {
    IntPtr token=IntPtr.Zero,environment=IntPtr.Zero;
    try {
      if(!WTSQueryUserToken(session,out token)) throw new Win32Exception();
      if(!CreateEnvironmentBlock(out environment,token,false)) throw new Win32Exception();
      var startup=new StartupInfo {Size=Marshal.SizeOf(typeof(StartupInfo)),Desktop="winsta0\\default",Flags=1,Show=0};
      ProcessInfo process;
      if(!CreateProcessAsUser(token,executable,new StringBuilder(command),IntPtr.Zero,IntPtr.Zero,false,0x400|0x08000000,environment,directory,ref startup,out process)) throw new Win32Exception();
      CloseHandle(process.Thread); CloseHandle(process.Process);
    } finally { if(environment!=IntPtr.Zero)DestroyEnvironmentBlock(environment); if(token!=IntPtr.Zero)CloseHandle(token); }
  }
}
