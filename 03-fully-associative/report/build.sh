#!/bin/bash
# Rebuild the LRU comparison report from the single tex source.
set -euo pipefail
cd "$(dirname "$0")"
REPO="$(cd ../../.. && pwd)"
export PATH="$REPO/software/node-runtime/bin:${HOME}/.TinyTeX/bin/x86_64-linux:${PATH}"
export PYTHONPATH="$REPO/software/python/site-packages${PYTHONPATH:+:$PYTHONPATH}"
BIN="$REPO/software/node-packages/node_modules/.bin"
PY="python3"
PUP="$REPO/report/puppeteer.json"
mkdir -p fig

"$PY" - << 'PY'
import re
import pathlib
tex = pathlib.Path("lru_comparison.tex").read_text()
pat = re.compile(
    r"\\begin\{filecontents\}\[[^\]]*\]\{([^}]+)\}(.*?)\\end\{filecontents\}",
    re.S,
)
found = pat.findall(tex)
if not found:
    raise SystemExit("no diagram sources found in the tex file")
for name, body in found:
    path = pathlib.Path(name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body.strip("\n") + "\n")
print(f"extracted {len(found)} diagram sources")
PY

shopt -s nullglob
for f in fig/*.mmd; do
  "$BIN/mmdc" -i "$f" -o "${f%.mmd}.pdf" -b white -p "$PUP" -q
done
for f in fig/*.json; do
  "$BIN/wavedrom-cli" -i "$f" -s "${f%.json}.svg"
  "$PY" -c 'import cairosvg, sys; cairosvg.svg2pdf(url=sys.argv[1], write_to=sys.argv[2])' \
    "${f%.json}.svg" "${f%.json}.pdf"
done

pdflatex -interaction=nonstopmode lru_comparison.tex
biber lru_comparison
pdflatex -interaction=nonstopmode lru_comparison.tex
pdflatex -interaction=nonstopmode lru_comparison.tex
echo "PDF: $(pwd)/lru_comparison.pdf"
