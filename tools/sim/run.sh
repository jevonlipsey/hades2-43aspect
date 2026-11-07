#!/bin/bash
# tools/sim/run.sh <out dir> <patched RoomLogic.lua> FLOW... : runs each flow against vanilla and the patched file
set -u
cd "$(dirname "$0")/../.."
OUT=$1; PATCHED=$2; shift 2
LUA=.cache/lua-5.2.4/src/lua
mkdir -p "$OUT"
for F in "$@"; do
  FLOW=$F $LUA tools/sim/sim.lua original/Scripts original/RoomLogic.lua tools/sim/scenarios/screens.lua "$OUT/$F.vanilla.json" 2>&1 | tail -2
  FLOW=$F $LUA tools/sim/sim.lua original/Scripts "$PATCHED" tools/sim/scenarios/screens.lua "$OUT/$F.patched.json" 2>&1 | tail -2
  python3 -I -c "
import json,sys;d=json.load(open(sys.argv[1]));print(sys.argv[2],d['Ok'],d['Status'][:400].replace(chr(10),' | '),len(d['Log']))" "$OUT/$F.patched.json" "$F"
done
