#!/usr/bin/bash
# Build the LRU board bitstream in a directory whose path has no space.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SHRIKE="$(cd "$ROOT/../shrike-gen" && pwd)"
STAGE="${CACHE_BUILD_DIR:-$HOME/cache_lru_build}"
GCSW="${GCSW:-/usr/local/go-configure-sw-hub/bin/external}"

python3 "$ROOT/gen_board_seq.py"

rm -rf "$STAGE"
mkdir -p "$STAGE/ffpga/src" "$STAGE/ffpga/build" "$STAGE/shrike_gen"
cp "$SHRIKE/Makefile" "$STAGE/Makefile"
cp "$SHRIKE/shrike_gen/"*.py "$STAGE/shrike_gen/"
cp "$ROOT/ffpga/src/"*.v "$STAGE/ffpga/src/"
cp "$ROOT/io_map.pcf" "$STAGE/io_map.pcf"
# Fixed device descriptor consumed by eda-placer. Not a floorplan we edit.
printf '1K\n\nM\n' > "$STAGE/ffpga/build/floorplanspec.fp"
cat > "$STAGE/shrike.mk" << 'EOF'
PROJECT      := lru_cache_board
TOP          := cache_sim_top
PROJECT_TYPE := verilog
EOF
touch "$STAGE/lru_cache_board.ffpga"

make -C "$STAGE" GCSW="$GCSW"
mkdir -p "$ROOT/ffpga/build/bitstream"
cp "$STAGE/ffpga/build/bitstream/"FPGA_bitstream_*.bin "$ROOT/ffpga/build/bitstream/"
echo "Bitstream copied to $ROOT/ffpga/build/bitstream/"
