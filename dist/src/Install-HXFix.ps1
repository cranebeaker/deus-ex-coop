# Installs HX 0.9.89.4 (downloaded from its official build server), HXFix and HXCoop
# into a Deus Ex: Game of the Year Edition folder.
#   powershell -ExecutionPolicy Bypass -File Install-HXFix.ps1 [-DeusEx "<Deus Ex folder>"]
param([string]$DeusEx = "", [switch]$NoShortcut)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$hxUrl = "https://builds.hx.hanfling.de/testing/HX-0.9.89.4.zip"
$hxSha = "95FE3B1FCAE3A834601B4FCDF5A6CA393AAB1452F6165E82F345BD77769C3D5A"

function Find-DeusEx {
	$candidates = @(
		"${env:ProgramFiles(x86)}\Steam\steamapps\common\Deus Ex",
		"$env:ProgramFiles\Steam\steamapps\common\Deus Ex",
		"${env:ProgramFiles(x86)}\GOG Galaxy\Games\Deus Ex",
		"C:\GOG Games\Deus Ex GOTY",
		"C:\GOG Games\Deus Ex"
	)
	$vdf = "${env:ProgramFiles(x86)}\Steam\steamapps\libraryfolders.vdf"
	if (Test-Path $vdf) {
		foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
			$candidates += (Join-Path ($m.Groups[1].Value -replace '\\\\','\') "steamapps\common\Deus Ex")
		}
	}
	return $candidates | Where-Object { Test-Path (Join-Path $_ "System\DeusEx.u") } | Select-Object -First 1
}

if ($DeusEx -eq "") { $DeusEx = Find-DeusEx }
if (-not $DeusEx) { $DeusEx = Read-Host "Deus Ex not found. Paste the folder that contains the System folder" }
$sys = Join-Path $DeusEx "System"
if (-not (Test-Path (Join-Path $sys "DeusEx.u"))) { throw "No Deus Ex install at $DeusEx" }
Write-Host "Installing into $DeusEx"

# 1. HX itself, unless it's already there.
if (-not (Test-Path (Join-Path $sys "HX.u"))) {
	$zip = Join-Path $here "HX-0.9.89.4.zip"
	if (-not (Test-Path $zip)) {
		Write-Host "Downloading HX 0.9.89.4 from $hxUrl"
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		Invoke-WebRequest -Uri $hxUrl -OutFile $zip -UseBasicParsing
	}
	if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $hxSha) { throw "HX-0.9.89.4.zip has the wrong checksum, delete it and run again." }
	$tmp = Join-Path $env:TEMP "hx-install-$PID"
	Expand-Archive $zip $tmp -Force
	Copy-Item (Join-Path $tmp "System\*") $sys -Force
	New-Item -ItemType Directory -Force (Join-Path $DeusEx "Help\HX") | Out-Null
	Copy-Item (Join-Path $tmp "Help\HX\*") (Join-Path $DeusEx "Help\HX") -Force
	Remove-Item $tmp -Recurse -Force
} else {
	Write-Host "HX is already installed."
}

# 2. HXFix.
Copy-Item (Join-Path $here "System\HXFix.u"), (Join-Path $here "System\HXFix.int") $sys -Force

# Register HXFix: joining players download it from the host; use the fixed server query.
foreach ($name in "HXDefault.ini", "HX.ini") {
	$ini = Join-Path $sys $name
	if (-not (Test-Path $ini)) { continue }
	$out = New-Object System.Collections.Generic.List[string]
	foreach ($l in (Get-Content $ini)) {
		if ($l -match '^(ServerPackages|EditPackages)=HXFix$') { continue }
		if ($l -match '^ServerActors=HX\.HXUdpServerQuery$') { $l = 'ServerActors=HXFix.HXFixUdpServerQuery' }
		$out.Add($l)
		if ($l -eq 'ServerPackages=HX') { $out.Add('ServerPackages=HXFix') }
		if ($l -eq 'EditPackages=HX') { $out.Add('EditPackages=HXFix') }
	}
	Set-Content $ini $out
}

# 3. HXCoop (Steam relay) and the launchers.
$coop = Join-Path $sys "HXCoop"
New-Item -ItemType Directory -Force $coop | Out-Null
Copy-Item (Join-Path $here "HXCoop\*") $coop -Force
Copy-Item (Join-Path $here "Play Co-op (Steam).bat"), (Join-Path $here "Host Co-op (IP).bat"), (Join-Path $here "Join Co-op (IP).bat") $sys -Force

# Desktop shortcut to the Steam launcher.
if (-not $NoShortcut) { try {
	$lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "Deus Ex Co-op.lnk"
	$s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
	$s.TargetPath = Join-Path $coop "HXCoop.exe"
	$s.WorkingDirectory = $coop
	$s.Save()
	Write-Host "Added a 'Deus Ex Co-op' shortcut to the desktop."
} catch { } }

Write-Host ""
Write-Host "Done. Start Steam, then open 'Deus Ex Co-op' on your desktop:"
Write-Host "  1 = host a game, 2 = join a friend who is hosting."
