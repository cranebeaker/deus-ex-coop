# Prints the last lines of an Unreal Engine 1 game's on-screen log window (the log file only
# flushes on a clean exit). Uses SendMessageTimeout, so a hung game can't hang the caller.
param([int]$ProcessId, [int]$Lines = 15)
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class LogText {
	delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessageTimeout(IntPtr h, int msg, IntPtr w, StringBuilder l, int flags, int ms, out IntPtr res);
	[DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr h, int msg, IntPtr w, IntPtr l, int flags, int ms, out IntPtr res);
	public static string Get(uint want) {
		var o = new List<string>();
		EnumWindows((h, l) => {
			uint pid; GetWindowThreadProcessId(h, out pid);
			if (pid != want) return true;
			EnumChildWindows(h, (ch, l2) => {
				var cc = new StringBuilder(256); GetClassName(ch, cc, 256);
				if (!cc.ToString().Contains("EditTerminal")) return true;
				IntPtr n;
				if (SendMessageTimeout(ch, 0x000E, IntPtr.Zero, IntPtr.Zero, 2, 2000, out n) == IntPtr.Zero) { o.Add("(log window not responding)"); return true; }
				var sb = new StringBuilder((int)n + 2); IntPtr r;
				SendMessageTimeout(ch, 0x000D, (IntPtr)((int)n + 1), sb, 2, 2000, out r);
				o.Add(sb.ToString());
				return true;
			}, IntPtr.Zero);
			return true;
		}, IntPtr.Zero);
		return string.Join("\n", o);
	}
}
"@
$text = [LogText]::Get([uint32]$ProcessId)
($text -split "`r?`n" | Where-Object { $_ -ne "" } | Select-Object -Last $Lines) -join "`n"
