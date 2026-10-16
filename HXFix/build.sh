#!/bin/sh
# Copies HXFix into the test game copy and rebuilds HXFix.u with HCC.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GAME="$ROOT/game"
rm -rf "$GAME/HXFix" "$GAME/System/HXFix.u"
mkdir -p "$GAME/HXFix"
cp -r "$ROOT/HXFix/Classes" "$GAME/HXFix/"
cp "$ROOT/HXFix/System/HXFix.int" "$GAME/System/"
for ini in HX.ini HXDefault.ini; do
	grep -q "^EditPackages=HXFix" "$GAME/System/$ini" || sed -i 's/^EditPackages=HX\r\?$/&\nEditPackages=HXFix/' "$GAME/System/$ini"
	grep -q "^ServerPackages=HXFix" "$GAME/System/$ini" || sed -i 's/^ServerPackages=HX\r\?$/&\nServerPackages=HXFix/' "$GAME/System/$ini"
done
# Use the fixed server query actor.
sed -i 's/^ServerActors=HX\.HXUdpServerQuery/ServerActors=HXFix.HXFixUdpServerQuery/' "$GAME/System/HX.ini" "$GAME/System/HXDefault.ini"
cd "$GAME/System" && ./HCC.exe make
