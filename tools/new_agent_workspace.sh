#!/bin/sh
# Creates an isolated build + test workspace for one agent:
#   agents/<name>/HXFix  (copy of HXFix source)
#   agents/<name>/game   (own System copy; Maps/Textures/Sounds/Music are junctions to ../game)
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
NAME=$1
DEST="$ROOT/agents/$NAME"
rm -rf "$DEST"
mkdir -p "$DEST/game"
cp -r "$ROOT/HXFix" "$DEST/HXFix"
cp -r "$ROOT/game/System" "$DEST/game/System"
cp -r "$ROOT/game/Help" "$DEST/game/Help"
for d in Maps Textures Sounds Music; do
	powershell -NoProfile -Command "New-Item -ItemType Junction -Path '$(cygpath -w "$DEST/game/$d")' -Target '$(cygpath -w "$ROOT/game/$d")' | Out-Null"
done
rm -f "$DEST/game/System/"*.log "$DEST/game/System/HXFix.ini"
echo "$DEST"
