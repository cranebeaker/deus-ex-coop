@echo off
rem Continues the saved co-op game (autosaved when your group enters a new map, or type CoopSave
rem in the console). Same as "Host Co-op (IP).bat", on the saved map, UDP port 7790.
cd /d "%~dp0"
set MAP=
if exist HXFixSave.ini for /f "tokens=2 delims==" %%a in ('findstr /b /c:"SavedMap=" HXFixSave.ini') do set MAP=%%a
if "%MAP%"=="" (
	echo No saved game found. Host a game first with "Host Co-op (IP).bat": it saves automatically
	echo when your group enters a new map.
	pause
	exit /b 1
)
start "" HX.exe "%MAP%?Listen?Game=HXFix.HXFixGameInfo?HXFixLoad=1"
