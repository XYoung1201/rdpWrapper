using System;
using System.Drawing;
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
// Flat, light colours for the tray menu instead of the default gradients.
public class TrayMenuColors : ProfessionalColorTable {
  static readonly Color Back=Color.White, Hover=Color.FromArgb(232,240,254), Edge=Color.FromArgb(226,232,240);
  public override Color ToolStripDropDownBackground { get { return Back; } }
  public override Color ImageMarginGradientBegin { get { return Back; } }
  public override Color ImageMarginGradientMiddle { get { return Back; } }
  public override Color ImageMarginGradientEnd { get { return Back; } }
  public override Color MenuBorder { get { return Edge; } }
  public override Color MenuItemBorder { get { return Hover; } }
  public override Color MenuItemSelected { get { return Hover; } }
  public override Color MenuItemSelectedGradientBegin { get { return Hover; } }
  public override Color MenuItemSelectedGradientEnd { get { return Hover; } }
  public override Color MenuItemPressedGradientBegin { get { return Hover; } }
  public override Color MenuItemPressedGradientEnd { get { return Hover; } }
  public override Color SeparatorDark { get { return Edge; } }
  public override Color SeparatorLight { get { return Back; } }
}
