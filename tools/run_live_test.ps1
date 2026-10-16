# Runs one live HXFix test: a listen server host plus N real clients on this PC.
#   powershell -NoProfile -File tools/run_live_test.ps1 -Game <...\game> -Test HXFixTestMuscle [-Map 01_NYC_UNATCOIsland] [-Port 7790] [-Clients 1] [-Timeout 240]
# The test (HXFixTestBase subclass) logs PASS/FAIL lines and exits the host when done.
# Prints the HXFixTest lines from all logs and returns exit code 0 only if DONE with fail=0.
param(
	[Parameter(Mandatory=$true)][string]$Game,
	[Parameter(Mandatory=$true)][string]$Test,
	[string]$Map = "01_NYC_UNATCOIsland",
	[int]$Port = 7790,
	[int]$Clients = 1,
	[int]$Timeout = 240,
	[string]$Extra = "",       # More host URL options, e.g. "?HXFixNetEmu=PktLag=150"
	[string]$ClientGame = "",  # Run the clients from another game copy (e.g. one without HXFix)
	[switch]$SteamMock         # Connect through HXCoop.exe (System\HXCoopMock, mock steam_api.dll)
)
$ErrorActionPreference = "Stop"
$sys = Join-Path $Game "System"
$exe = Join-Path $sys "HX.exe"
if ($ClientGame -eq "") { $ClientGame = $Game }
$csys = Join-Path $ClientGame "System"
$cexe = Join-Path $csys "HX.exe"

# One-time per game copy: skip the setup wizard, software renderer, windowed, separate client ini.
$ini = Join-Path $sys "HX.ini"
(Get-Content $ini) -replace '^FirstRun=0$','FirstRun=1100' `
	-replace '^GameRenderDevice=D3DDrv.D3DRenderDevice$','GameRenderDevice=SoftDrv.SoftwareRenderDevice' `
	-replace '^StartupFullscreen=True$','StartupFullscreen=False' `
	-replace '^CaptureMouse=True$','CaptureMouse=False' | Set-Content $ini
$cini = Join-Path $csys "HX.ini"
if ($csys -ne $sys) {
	(Get-Content $cini) -replace '^FirstRun=0$','FirstRun=1100' `
		-replace '^GameRenderDevice=D3DDrv.D3DRenderDevice$','GameRenderDevice=SoftDrv.SoftwareRenderDevice' `
		-replace '^StartupFullscreen=True$','StartupFullscreen=False' `
		-replace '^CaptureMouse=True$','CaptureMouse=False' | Set-Content $cini
}
for ($i = 1; $i -le $Clients; $i++) {
	Copy-Item $cini (Join-Path $csys "Client$i.ini") -Force
	$userIni = Join-Path $csys "Client${i}User.ini"
	(Get-Content (Join-Path $csys "HXUser.ini")) -replace '^Name=.*$',"Name=Tester$i" | Set-Content $userIni
}

$hostLog = "Host_$Test.log"
Remove-Item (Join-Path $sys $hostLog) -ErrorAction SilentlyContinue
$hostUrl = "${Map}?Listen?Port=${Port}?Game=HXFix.HXFixGameInfo?HXFixTest=${Test}${Extra}"
# Steam mode: HXCoop.exe starts HX.exe itself; the game process is its child.
function Get-GameChild($parent) {
	for ($t = 0; $t -lt 40; $t++) {
		$c = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($parent.Id) AND Name='HX.exe'" | Select-Object -First 1
		if ($c) { return Get-Process -Id $c.ProcessId }
		Start-Sleep -Milliseconds 250
	}
	return $null
}
$relays = @()
if ($SteamMock) {
	$env:KFX_MOCK_STEAM_PORT_BASE = "$($Port + 40000)"
	$env:KFX_MOCK_STEAM_NAME = "Host"
	$coop = Join-Path $sys "HXCoopMock\HXCoop.exe"
	$relay = Start-Process -FilePath $coop -ArgumentList "host", $Map, "--port", $Port, "--url-extra", "`"?HXFixTest=${Test}${Extra}`"", "--hx-args", "`"-log=$hostLog`"" -WorkingDirectory (Split-Path $coop) -PassThru
	$relays += $relay
	$hostProc = Get-GameChild $relay
	if (-not $hostProc) { Write-Output "run_live_test: HXCoop host did not start HX"; $hostProc = $relay }
} else {
	$hostProc = Start-Process -FilePath $exe -ArgumentList "`"$hostUrl`"", "-log=$hostLog" -WorkingDirectory $sys -PassThru
}
Start-Sleep -Seconds 15

$clientProcs = @()
for ($i = 1; $i -le $Clients; $i++) {
	$clientLog = "Client${i}_$Test.log"
	Remove-Item (Join-Path $csys $clientLog) -ErrorAction SilentlyContinue
	if ($SteamMock) {
		$env:KFX_MOCK_STEAM_NAME = "Client$i"
		$coop = Join-Path $csys "HXCoopMock\HXCoop.exe"
		$relay = Start-Process -FilePath $coop -ArgumentList "join", "--hx-args", "`"INI=Client$i.ini USERINI=Client${i}User.ini -log=$clientLog`"" -WorkingDirectory (Split-Path $coop) -PassThru
		$relays += $relay
		$child = Get-GameChild $relay
		if ($child) { $clientProcs += $child } else { Write-Output "run_live_test: HXCoop client $i did not start HX" }
	} else {
		$clientProcs += Start-Process -FilePath $cexe -ArgumentList "127.0.0.1:${Port}", "INI=Client$i.ini", "USERINI=Client${i}User.ini", "-log=$clientLog" -WorkingDirectory $csys -PassThru
	}
	Start-Sleep -Seconds 3
}

if (-not $hostProc.WaitForExit($Timeout * 1000)) {
	Write-Output "run_live_test: host did not exit within $Timeout s, closing"
	$hostProc.CloseMainWindow() | Out-Null
	if (-not $hostProc.WaitForExit(10000)) { $hostProc.Kill() }
}
# A crashed game sits on its "Critical Error" box and never flushes its log,
# so look at the window and at whether it closes when asked.
$crashed = @()
foreach ($c in $clientProcs) {
	$c.Refresh()
	if (-not $c.HasExited -and $c.MainWindowTitle -match 'Critical Error') { $crashed += "client pid $($c.Id) showed Critical Error" }
	if (-not $c.HasExited) {
		$c.CloseMainWindow() | Out-Null
		if (-not $c.WaitForExit(20000)) {
			$c.Refresh()
			# Read the dialog or log before killing it.
			$crashed += "client pid $($c.Id) did not close (window '$($c.MainWindowTitle)'), killed"
			$text = & (Join-Path $PSScriptRoot "crash_text.ps1") -ProcessId $c.Id
			if ($text) { $crashed += "client pid $($c.Id) crash text: $text" }
			else {
				$tail = & (Join-Path $PSScriptRoot "log_text.ps1") -ProcessId $c.Id
				if ($tail) { $crashed += "client pid $($c.Id) on-screen log tail:`n$tail" }
			}
			$c.Kill()
		}
	}
}
foreach ($r in $relays) {
	if (-not $r.WaitForExit(5000)) { & taskkill /PID $r.Id /T /F 2>&1 | Out-Null }
}
Start-Sleep -Seconds 2

$ok = $false
foreach ($log in @($hostLog) + (1..$Clients | ForEach-Object { "Client${_}_$Test.log" })) {
	$path = Join-Path $(if ($log -eq $hostLog) { $sys } else { $csys }) $log
	if (-not (Test-Path $path)) { Write-Output "== $log missing"; continue }
	$text = [IO.File]::ReadAllText($path)
	Write-Output "== $log"
	($text -split "`r?`n") | Where-Object { $_ -match 'HXFixTest|Accessed None|Critical|Runaway|General protection' } | Select-Object -Last 80
	if ($log -eq $hostLog -and $text -match "HXFixTest: DONE \S+ pass=\d+ fail=0") { $ok = $true }
}
foreach ($m in $crashed) { Write-Output "run_live_test: CRASH $m"; $ok = $false }
if ($ok) { Write-Output "RESULT: PASS"; exit 0 } else { Write-Output "RESULT: FAIL"; exit 1 }
