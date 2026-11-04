using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class SessionWatcher : NativeWindow, IDisposable {
  public int Connections { get; private set; }
  [DllImport("wtsapi32.dll", SetLastError=true)] static extern bool WTSRegisterSessionNotification(IntPtr handle,int flags);
  [DllImport("wtsapi32.dll")] static extern bool WTSUnRegisterSessionNotification(IntPtr handle);
  public SessionWatcher() {
    CreateHandle(new CreateParams());
    if(!WTSRegisterSessionNotification(Handle,0)) throw new System.ComponentModel.Win32Exception();
  }
  protected override void WndProc(ref Message message) {
    if(message.Msg==0x2B1) {
      int change=message.WParam.ToInt32();
      // Local console attach, remote attach, and workstation unlock.
      if(change==1 || change==3 || change==8) Connections++;
    }
    base.WndProc(ref message);
  }
  public void Dispose(){WTSUnRegisterSessionNotification(Handle);DestroyHandle();}
}
