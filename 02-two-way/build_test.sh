#!/usr/bin/bash
# Rebuild the address ROM, then place and route in a directory with no space
# in its path. Go Configure rejects this project's folder name.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SHRIKE="$(cd "$ROOT/../shrike-gen" && pwd)"
STAGE="${CACHE_BUILD_DIR:-$HOME/set_assoc_build}"
if [[ -x /usr/local/go-configure-sw-hub/bin/external/yosys/v59/yosys ]]; then
    GCSW="/usr/local/go-configure-sw-hub/bin/external"
else
    GCSW="/opt/go-configure-sw-hub/bin/external"
fi
YOSYS="$GCSW/yosys/v59/yosys"

python3 "$ROOT/gen_test.py"

if [[ ! -x "$YOSYS" ]]; then
    echo "The address list is in the Verilog. Go Configure is not installed, so the bitstream was not built."
    echo "Run ./run_sim.sh to check the cache. Run this script again on the machine that has the tools before flashing."
    exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/ffpga/src" "$STAGE/shrike_gen"
cp "$SHRIKE/Makefile" "$STAGE/Makefile"
cp "$SHRIKE/shrike_gen/"*.py "$STAGE/shrike_gen/"
cp "$ROOT/ffpga/src/"*.v "$STAGE/ffpga/src/"
cp "$ROOT/io_map.pcf" "$STAGE/io_map.pcf"
cat > "$STAGE/shrike.mk" << 'EOF'
PROJECT      := set_assoc
TOP          := cache_sim_top
PROJECT_TYPE := verilog
EOF
touch "$STAGE/set_assoc.ffpga"
mkdir -p "$STAGE/ffpga/build"
printf '1K\n\nM\n' > "$STAGE/ffpga/build/floorplanspec.fp"

make -C "$STAGE" GCSW="$GCSW"
mkdir -p "$ROOT/ffpga/build/bitstream"
cp "$STAGE/ffpga/build/bitstream/"FPGA_bitstream_*.bin "$ROOT/ffpga/build/bitstream/"
echo "Bitstream copied to $ROOT/ffpga/build/bitstream/"
echo "Flash FPGA_bitstream_MCU.bin. The clips stay on the same header pins."
