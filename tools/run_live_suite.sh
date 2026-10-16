#!/bin/sh
# Runs every test in tools/live_suite.txt sequentially, writes <out>/summary.txt.
#   tools/run_live_suite.sh [game dir] [port] [extra host URL options] [out dir]
# Defaults: game/, 7790, none, re/suite. Example with internet like conditions:
#   tools/run_live_suite.sh agents/netemu/game 7820 "?HXFixNetEmu=PktLag=150,PktLoss=5" re/suite-netemu
# SUITE_LIST=<file> runs another list in the same format. SUITE_STEAM=1 connects through HXCoop + mock Steam.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GAME=${1:-$ROOT/game}; PORT=${2:-7790}; EXTRA=$3; OUT=${4:-$ROOT/re/suite}
case "$GAME" in /*) ;; *) GAME="$ROOT/$GAME";; esac
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT";; esac
mkdir -p "$OUT"; : > "$OUT/summary.txt"
grep -v "^#" "${SUITE_LIST:-$ROOT/tools/live_suite.txt}" | while read t map clients timeout; do
	[ -z "$t" ] && continue
	log="$OUT/${t}_${map}.txt"
	powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/tools/run_live_test.ps1")" -Game "$(cygpath -w "$GAME")" -Test "$t" -Map "$map" -Port "$PORT" -Clients "$clients" -Timeout "$timeout" -Extra "$EXTRA" ${SUITE_STEAM:+-SteamMock} > "$log" 2>&1 < /dev/null
	res=$(grep -o "RESULT: [A-Z]*" "$log" | tail -1); done_line=$(grep -a -o "DONE .*" "$log" | tail -1)
	echo "$t $map -> ${res:-RESULT: NONE} ($done_line)" | tee -a "$OUT/summary.txt"
done
echo "SUITE FINISHED $(grep -c 'RESULT: PASS' "$OUT/summary.txt") pass / $(grep -c -v 'RESULT: PASS' "$OUT/summary.txt") not pass" | tee -a "$OUT/summary.txt"
