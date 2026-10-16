#!/bin/sh
# Builds the player zip dist/build/DeusEx-Coop-<version>.zip from:
#   dist/src (installer, launchers, readme), game/System/HXFix.u + HXFix.int (run HXFix/build.sh first),
#   steamlink/HXCoop.exe (steamlink/build.sh) and steamlink/redist/steam_api.dll
#   (Steamworks.NET 2025.164.1 Windows-x86, sha256 fdafb7c6...65da, not in git).
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VER=${1:-$(date +%Y.%m.%d)}
OUT="$ROOT/dist/build/DeusEx-Coop"
rm -rf "$OUT" && mkdir -p "$OUT/System" "$OUT/HXCoop"
cp "$ROOT/dist/src/"*.bat "$ROOT/dist/src/"*.ps1 "$ROOT/dist/src/"*.txt "$OUT/"
cp "$ROOT/game/System/HXFix.u" "$ROOT/HXFix/System/HXFix.int" "$OUT/System/"
cp "$ROOT/steamlink/HXCoop.exe" "$ROOT/steamlink/redist/steam_api.dll" "$OUT/HXCoop/"
printf '480' > "$OUT/HXCoop/steam_appid.txt"
echo "$VER" > "$OUT/VERSION.txt"
ZIP="$ROOT/dist/build/DeusEx-Coop-$VER.zip"
rm -f "$ZIP"
powershell -NoProfile -Command "Compress-Archive -Path '$(cygpath -w "$OUT")\*' -DestinationPath '$(cygpath -w "$ZIP")'"
echo "$ZIP"
