#!/usr/bin/env python3
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent
repo = root.parents[1]
stage = Path("/tmp/lrusrc")
if stage.exists():
    shutil.rmtree(stage)
stage.mkdir()
shutil.copytree(root / "src", stage / "src")
shutil.copy(root / "tb_lru.v", stage / "tb_lru.v")

# Icarus breaks when its own install path contains a space, so stage it.
staged = Path("/tmp/cache-sim-iverilog")
bundled = repo / "software" / "iverilog" / "usr"
if not (staged / "usr" / "bin" / "iverilog").is_file():
    staged.mkdir(parents=True, exist_ok=True)
    shutil.copytree(bundled, staged / "usr", dirs_exist_ok=True)
ivl_root = staged / "usr"
iverilog = ivl_root / "bin" / "iverilog"
vvp = ivl_root / "bin" / "vvp"
ivl_lib = ivl_root / "lib" / "x86_64-linux-gnu" / "ivl"
src = [
    stage / "src" / "main_memory.v",
    stage / "src" / "block_fetch_controller.v",
    stage / "src" / "lru_cache.v",
    stage / "tb_lru.v",
]
out = Path("/tmp/lru.vvp")
compile_cmd = [str(iverilog), f"-B{ivl_lib}", "-g2012", "-o", str(out), *map(str, src)]
c = subprocess.run(compile_cmd, text=True, capture_output=True)
sys.stderr.write(c.stderr)
sys.stderr.write(c.stdout)
if c.returncode != 0:
    sys.exit(c.returncode)
r = subprocess.run([str(vvp), f"-M{ivl_lib}", str(out)], text=True, capture_output=True)
sys.stdout.write(r.stdout)
sys.stderr.write(r.stderr)
log = root / "sim_results.txt"
log.write_text(r.stdout)
# vvp returns 0 even when $finish(1) on some builds; trust the banner.
if "ALL TESTS PASSED" not in r.stdout:
    sys.exit(1)
sys.exit(0)
