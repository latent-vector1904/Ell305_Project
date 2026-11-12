#!/usr/bin/bash
# Simulate one pass of the suite and check hit and miss cycle counts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
python3 "$ROOT/gen_test.py"

# Icarus breaks when its own install path contains a space, so stage it.
IVL_ROOT="${TMPDIR:-/tmp}/cache-sim-iverilog"
BUNDLED="$REPO/software/iverilog"
if [[ -d "$BUNDLED/usr" && ! -x "$IVL_ROOT/usr/bin/iverilog" ]]; then
    mkdir -p "$IVL_ROOT"
    cp -a "$BUNDLED/usr" "$IVL_ROOT/"
fi
if [[ -x "$IVL_ROOT/usr/bin/iverilog" ]]; then
    IVL="$IVL_ROOT/usr/bin/iverilog"
    VVP="$IVL_ROOT/usr/bin/vvp"
    B=(-B "$IVL_ROOT/usr/lib/x86_64-linux-gnu/ivl")
elif [[ -x "$HOME/ivlroot/bin/iverilog" ]]; then
    IVL="$HOME/ivlroot/bin/iverilog"
    VVP="$HOME/ivlroot/bin/vvp"
    B=(-B "$HOME/ivlroot/lib/x86_64-linux-gnu/ivl")
else
    IVL=iverilog
    VVP=vvp
    B=()
fi

"$IVL" "${B[@]}" -g2012 -o /tmp/tb_set_assoc.vvp \
    "$ROOT/ffpga/src/cache_sim_top.v" \
    "$ROOT/ffpga/src/exam_seq.v" \
    "$ROOT/ffpga/src/address_decoder.v" \
    "$ROOT/ffpga/src/cache_storage.v" \
    "$ROOT/ffpga/src/main_memory.v" \
    "$ROOT/ffpga/src/block_fetch_controller.v" \
    "$ROOT/ffpga/src/cache_controller.v" \
    "$ROOT/tb_exam.v"
"$VVP" /tmp/tb_set_assoc.vvp | tee "$ROOT/sim_results.txt"
