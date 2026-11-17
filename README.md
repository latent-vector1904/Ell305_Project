# Cache simulator

Direct-mapped, two-way, and fully associative cache designs, plus the C++ model, the board recordings, and the write-up.

## Layout

| Folder | What it is |
|---|---|
| `src/cpp` | C++ model. `make check` runs the hit/miss checks. |
| `src/web` | Single-page view of the same model. Open `index.html` in a browser. |
| `01-direct-mapped/04-first-image` | First board image. One address, repeated. |
| `01-direct-mapped/03-version-two` | Temporal test, then the neighbouring bytes. |
| `01-direct-mapped/02-version-three` | Full exam: conflict, capacity, replacement, and the rest. |
| `02-two-way` | Two-way set-associative image. |
| `03-fully-associative` | Fully associative LRU image. |
| `01-direct-mapped/05-early-board` | Earlier board design. |
| `bitstream` | Flash images and the board flash script. |
| `fpga/shrike-gen` | Project generator used to build the board projects. |
| `report` | Write-up. `vfinal.pdf` is the current report. |
| `software` | Dependency lists, plus the Icarus Verilog package the simulators use. |
| `versions.md` | How the three direct-mapped board versions differ. |

Place-and-route logs cited by the report are kept next to the bitstreams (`PNR_TIMING.log`, `PNR_RESOURCE.log`). Synthesis dumps, LaTeX auxiliaries, and the diagram-tool caches were removed.

## Software in `software/`

| Path | What it is |
|---|---|
| `software/iverilog` | Icarus Verilog 12.0. `iverilog_12.0-3_amd64.deb` is the package. `usr/` is the extracted copy the simulators use. |
| `software/node-packages` | `package.json` for Mermaid CLI and WaveDrom. Install with `npm ci` inside that folder. Node.js 22 is expected on `PATH`. |
| `software/python` | `requirements.txt` for CairoSVG and its dependencies. Install with `pip install -r software/python/requirements.txt`. |

The simulators copy Icarus into `/tmp/cache-sim-iverilog` before they run. Icarus cannot live in a path that contains a space, and this folder name has one.

A C++ compiler (`g++`), Python 3, and Node.js are expected from the system. Rebuilding the PDF also needs `pdflatex` and `biber`. Building a new FPGA bitstream needs the Shrike place-and-route tools, which are installed on the machine that produced these images and are not in this archive.

Installed copies of Node, `node_modules`, and Python `site-packages` are not in this folder. The Node binary alone is larger than GitHub’s 100 MB file limit.

## Run

```bash
make check
python3 03-fully-associative/run_sim.py
bash 02-two-way/run_sim.sh
bash fpga/shrike_fixed/run_sim.sh
```

Figure rebuilds, after installing the Node and Python packages above:

```bash
bash report/build.sh
```
