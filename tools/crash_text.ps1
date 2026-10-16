# Prints the text of the "Critical Error" dialog of process <Pid> (UE1 crash history), if any.
param([int]$ProcessId)
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class CrashText {
	delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, StringBuilder l);
	[DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);
	static string Text(IntPtr h) {
		int n = (int)SendMessage(h, 0x000E, IntPtr.Zero, IntPtr.Zero);
		var sb = new StringBuilder(n + 2); SendMessage(h, 0x000D, (IntPtr)(n + 1), sb); return sb.ToString();
	}
	public static string Get(uint want) {
		var outp = new List<string>();
		EnumWindows((h, l) => {
			uint pid; GetWindowThreadProcessId(h, out pid);
			if (pid != want) return true;
			var t = new StringBuilder(256); GetWindowText(h, t, 256);
			if (t.ToString() != "Critical Error") return true;
			EnumChildWindows(h, (c, l2) => { var s = Text(c); if (s.Length > 0) outp.Add(s); return true; }, IntPtr.Zero);
			return true;
		}, IntPtr.Zero);
		return string.Join("\n", outp);
	}
}
"@
[CrashText]::Get([uint32]$ProcessId)
