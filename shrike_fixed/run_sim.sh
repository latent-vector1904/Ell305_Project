#!/usr/bin/env bash
# Simulate shrike_fixed and dump VCD waveforms.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# Icarus Verilog breaks on paths with spaces; use a space-free staging dir.
STAGE="${TMPDIR:-/tmp}/shrike_sim_$$"
IVL_ROOT="${TMPDIR:-/tmp}/cache-sim-iverilog"

if [[ ! -x "$IVL_ROOT/usr/bin/iverilog" ]]; then
  TOOLS_SRC="$(cd "$ROOT/../../software/iverilog" 2>/dev/null && pwd || true)"
  if [[ -z "${TOOLS_SRC}" || ! -x "$TOOLS_SRC/usr/bin/iverilog" ]]; then
    echo "Missing Icarus Verilog. Use software/iverilog in this project." >&2
    exit 1
  fi
  mkdir -p "$IVL_ROOT"
  cp -a "$TOOLS_SRC/usr" "$IVL_ROOT/"
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/waves" "$ROOT/waves"
cp "$ROOT"/*.v "$STAGE/"
cd "$STAGE"

IVL="$IVL_ROOT/usr/lib/x86_64-linux-gnu/ivl"
"$IVL_ROOT/usr/bin/iverilog" -B"$IVL" -o sim.vvp \
  address_decoder.v block_fetch_controller.v cache_controller.v \
  cache_storage.v main_memory.v performance_counter.v \
  test_generator.v tb_cache_sim.v

"$IVL_ROOT/usr/bin/vvp" -M"$IVL" sim.vvp

cp -a waves/. "$ROOT/waves/"
cp -f sim.vvp "$ROOT/sim.vvp"
echo "Wrote $ROOT/waves/cache_sim.vcd and $ROOT/waves/results.txt"
rm -rf "$STAGE"
