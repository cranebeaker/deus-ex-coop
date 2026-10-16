#!/bin/bash
# Builds HXCoop.exe and the mock steam_api.dll (both 32 bit) with i686 mingw in the kfx-build image.
D=$(cygpath -w "$(dirname "$(readlink -f "$0")")")
MSYS_NO_PATHCONV=1 docker run --rm -v "$D:/s" kfx-build bash -c "
	i686-w64-mingw32-gcc -O2 -Wall -o /s/HXCoop.exe /s/hxcoop.c -lws2_32 -static -s &&
	i686-w64-mingw32-gcc -O2 -Wall -shared -o /s/mock/mock_steam_api.dll /s/mock/mock_steam_api.c -lws2_32 -Wl,--kill-at -static-libgcc -s"
