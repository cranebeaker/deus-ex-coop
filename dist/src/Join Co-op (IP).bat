@echo off
rem Fallback without Steam: joins a host by IP address.
cd /d "%~dp0"
set IP=%1
if "%IP%"=="" set /p IP=Host IP address: 
start "" HX.exe %IP%:7790
