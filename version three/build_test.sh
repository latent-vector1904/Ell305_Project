#!/usr/bin/bash
# Read test_template.txt, rewrite the address ROM, and build a bitstream
# in a directory whose path has no space. The tools reject this folder's name.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SHRIKE="$(cd "$ROOT/../shrike-gen" && pwd)"
STAGE="${CACHE_BUILD_DIR:-$HOME/cache_sim_build}"
YOSYS="/opt/go-configure-sw-hub/bin/external/yosys/v59/yosys"

python3 "$ROOT/gen_test.py"

if [[ ! -x "$YOSYS" ]]; then
    echo "The address list is in the Verilog. Go Configure is not installed, so the bitstream was not rebuilt."
    echo "The file already on the board is the previous list until you run this script on the machine that has the tools."
    exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/ffpga/src" "$STAGE/shrike_gen"
cp "$SHRIKE/Makefile" "$STAGE/Makefile"
cp "$SHRIKE/shrike_gen/"*.py "$STAGE/shrike_gen/"
cp "$ROOT/ffpga/src/"*.v "$STAGE/ffpga/src/"
cp "$ROOT/io_map.pcf" "$STAGE/io_map.pcf"
cat > "$STAGE/shrike.mk" << 'EOF'
PROJECT      := cache_sim_v3
TOP          := cache_sim_top
PROJECT_TYPE := verilog
EOF
# Project mode starts only when a .ffpga file is present. make update rewrites it.
touch "$STAGE/cache_sim_v3.ffpga"

make -C "$STAGE"
mkdir -p "$ROOT/ffpga/build/bitstream"
cp "$STAGE/ffpga/build/bitstream/"FPGA_bitstream_*.bin "$ROOT/ffpga/build/bitstream/"
echo "Bitstream copied to $ROOT/ffpga/build/bitstream/"
echo "Flash that MCU image. It asks for the addresses now in test_template.txt."
