# Developing HXFix

Workspace layout (only HXFix/, steamlink/, tools/ and dist/src/ are in git; the rest you
create locally from your own game and the official HX build):

- downloads/HX-0.9.89.4.zip: last official build (2019-06-04), from https://builds.hx.hanfling.de/testing/
- hx-0.9.89.4/: the extracted build
- game/: isolated copy of Steam Deus Ex GOTY (1112fm) with HX installed. Never touch the Steam install.
- src/Classes/: HX's 960 UnrealScript classes (~120k lines), dumped with tools/dump_uscript.py (no defaultproperties)
- ref/: stock Core/Engine/DeusEx/Extension/IpDrv script source, same tool. Steam packages only keep partial source.
- HXFix/: our fix package. Build with `HXFix/build.sh` (copies into game/, registers in HX.ini, runs `HCC.exe make`).

## Rules
- Do not rebuild HX.u. `HCC batchexport` asserts on a class with no ScriptText, so defaults can't be round-tripped,
  and HX.dll (no source) depends on the variable layout of native classes (HXPlayerPawn, HXDecoration, HXActor, ...).
- Fixes go in HXFix as subclasses: GameInfos and player classes are picked from .int entries, actors and
  MissionScripts via HXMutator ModifyActorClass / ModifyInventoryClass / ModifyMissionScriptClass.
- HCC needs Windows paths for output dirs and can't create nested directories.

## Running
- Dedicated server: `game/System/HCC.exe server "01_NYC_UNATCOIsland?Game=HXFix.HXFixGameInfo" -log=HXServer.log`
- Client: game/System/HX.exe. Forward UDP 7790-7792 to host over the internet.

## Fixes and backlog
See BUGS.md. Test helpers in HXFixGameInfo: `?HXFixTestExit=<sec>` quits cleanly (logs only flush on clean exit),
`?HXFixTestTravel=<map>` adds a test note and travels. Run several servers in parallel with distinct `?Port=`.

## Community
- Deus Ex Community HQ Discord (hosts HX), Steam group deusexmulti, Die4Ever (HXRandomizer).

## Native code (HX.dll)
Decompiled with Ghidra headless: `re/out/HX.dll.c` (2,773 functions, C++ names preserved), index in
`re/out/HX.dll.functions.tsv`, extract one with `re/fn.sh '<regex>'`. Script: tools/ghidra_scripts/DecompileAll.java.

## Automated tests (no human playtest needed)
- One test: `powershell -File tools/run_live_test.ps1 -Game <abs game dir> -Test HXFixTestMuscle -Map 01_NYC_UNATCOIsland -Clients 1 -Timeout 300`
  starts a listen host and real clients on this PC and prints `RESULT: PASS/FAIL`. A client that crashes or hangs on
  exit fails the run, with the crash dialog text.
- Options: `-Port`, `-Extra "?HXFixNetEmu=PktLag=150,PktLoss=5"` (internet-like lag and loss on every player),
  `-ClientGame <dir>` (clients from another install, e.g. one without HXFix to test the download),
  `-SteamMock` (connect through HXCoop with the mock steam_api.dll in `System/HXCoopMock`).
- Whole suite: `tools/run_live_suite.sh [game dir] [port] [extra url] [out dir]`, list in `tools/live_suite.txt`,
  env `SUITE_LIST=<file>` and `SUITE_STEAM=1`. Summary goes to `<out dir>/summary.txt`.
- Tests are `HXFixTest*` classes (HXFixTestBase): steps run on the server, `ClientCmd` makes a real client run a
  console command so client to server RPCs are exercised.

## Steam relay (HXCoop)
`steamlink/hxcoop.c`, built by `steamlink/build.sh` (Docker image with i686 mingw). See
`steamlink/mock/` for the mock used in tests. Release zip: `tools/make_release.sh <version>`.

## Live two-player test on one PC (by hand)
Host: `HX.exe "01_NYC_UNATCOIsland?Listen?Game=HXFix.HXFixGameInfo?Mutator=HXFix.HXFixTestSoak" -log=Host.log`
Client: `HX.exe 127.0.0.1:7790 INI=ClientHX.ini USERINI=ClientUser.ini -log=Client.log`
Both use SoftDrv (two D3D windows fight over exclusive mode). FirstRun=1100 skips the setup wizard.
Logs are locked until the game exits; close with `taskkill //IM HX.exe` (no /F) to flush.
Agent workspaces (agents/*) are disposable copies; recreate with tools/new_agent_workspace.sh <name>.
