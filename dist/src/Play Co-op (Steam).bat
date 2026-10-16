@echo off
rem Host or join HX co-op through Steam (no IP address or port forwarding needed).
cd /d "%~dp0HXCoop"
start "" HXCoop.exe %*
