@echo off
rem Fallback without Steam: hosts on UDP port 7790. Friends need your IP and an open port.
rem Optional: a map to start on, e.g.  "Host Co-op (IP).bat" 02_NYC_BatteryPark
cd /d "%~dp0"
set MAP=%1
if "%MAP%"=="" set MAP=01_NYC_UNATCOIsland
start "" HX.exe "%MAP%?Listen?Game=HXFix.HXFixGameInfo"
