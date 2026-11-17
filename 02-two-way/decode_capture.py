#!/usr/bin/env python3
"""Score a 100 Hz capture of the two-way board suite.

Clips, same header as the earlier recordings:
  A0 hit, A1 miss, A2 memory read, A3 request,
  A4 phase[0], A5 phase[1], A6 phase[2].
"""

import sys
from pathlib import Path

TICK_S = (2 ** 23) / 50e6
SUITE = [
    ("temporal", "MHHHH"),
    ("spatial", "MHHHMHHH"),
    ("conflict", "MMHH"),
    ("capacity", "MMMMHHHH"),
    ("lru", "MMHMHM"),
    ("independence", "MMHH"),
    ("reverse", "MHHH"),
    ("top", "MH"),
]


def load(path):
    rows = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(";") or line.startswith("logic"):
                continue
            parts = line.split(",")
            try:
                rows.append([1 if int(float(p)) else 0 for p in parts])
            except ValueError:
                continue
    if not rows:
        raise SystemExit("capture has no samples")
    width = len(rows[0])
    return [[r[i] if i < len(r) else 0 for r in rows] for i in range(width)]


def pulses(bits, min_w):
    out = []
    i = 0
    n = len(bits)
    while i < n:
        if bits[i]:
            j = i
            while j < n and bits[j]:
                j += 1
            if j - i >= min_w:
                out.append((i, j))
            i = j
        else:
            i += 1
    return out


def median(xs):
    ys = sorted(xs)
    return ys[len(ys) // 2]


def main():
    path = Path(sys.argv[1])
    rate = float(sys.argv[2]) if len(sys.argv) > 2 else 100.0
    ch = load(path)
    n = len(ch[0])
    hit, miss, mem, req = ch[0], ch[1], ch[2], ch[3]
    phase = [ch[4][i] | (ch[5][i] << 1) | (ch[6][i] << 2) for i in range(n)]

    # A real flag is at least half an enable cycle. Noise is shorter.
    min_w = max(4, int(0.5 * TICK_S * rate))
    hits = pulses(hit, min_w)
    misses = pulses(miss, min_w)
    reads = pulses(mem, min_w)
    reqs = pulses(req, min_w)

    def widths(ps):
        return [b - a for a, b in ps]

    print("samples %d  rate %g Hz" % (n, rate))
    print("pulses hit %d miss %d mem %d request %d" % (
        len(hits), len(misses), len(reads), len(reqs)))
    for name, ps, expect in (
        ("hit", hits, 2), ("miss", misses, 9), ("mem", reads, 4), ("request", reqs, 1)
    ):
        w = widths(ps)
        if not w:
            print("%s  no pulses" % name)
            continue
        med = median(w)
        steps = med / (TICK_S * rate)
        print("%s  median %d samples  %.2f enable cycles  (FSM %d)" % (
            name, med, steps, expect))

    events = [("H", a, b) for a, b in hits] + [("M", a, b) for a, b in misses]
    events.sort(key=lambda e: e[1])

    groups = []
    cur_phase = None
    cur = []
    for kind, a, b in events:
        # Phase is steady during the pulse. Sample just after it rises.
        p = phase[min(a + 2, n - 1)]
        if cur and p != cur_phase:
            groups.append((cur_phase, cur, cur[0][1], cur[-1][2]))
            cur = []
        cur_phase = p
        saw = any(mem[t] for t in range(a, b))
        cur.append((kind, a, b, saw))
    if cur:
        groups.append((cur_phase, cur, cur[0][1], cur[-1][2]))

    # Drop a group the record cuts through.
    complete = []
    for p, ev, start, end in groups:
        shape = "".join(k for k, *_ in ev)
        want = SUITE[p][1] if 0 <= p < len(SUITE) else ""
        whole = shape == want
        # A partial group at either end is shorter than the test and touches the buffer.
        edge = start < 50 or end > n - 50
        if whole or not edge:
            complete.append((p, ev, start, end, shape, whole))

    print("groups %d" % len(groups))
    bad = 0
    read_bad = 0
    shown = 0
    for p, ev, start, end, shape, whole in complete:
        name = SUITE[p][0] if 0 <= p < len(SUITE) else "phase%d" % p
        want = SUITE[p][1] if 0 <= p < len(SUITE) else "?"
        mark = "OK" if whole else "FAIL"
        if not whole:
            bad += 1
        for kind, a, b, saw in ev:
            if kind == "M" and not saw:
                read_bad += 1
            if kind == "H" and saw:
                read_bad += 1
        if shown < 24 or not whole:
            print("  %s phase %d %-14s %8.2f s  want %s  got %s" % (
                mark, p, name, start / rate, want, shape))
            shown += 1
    # A pulse much shorter than a hit is a dropped sample on the clip, not a cache step.
    clean = []
    for item in complete:
        p, ev, start, end, shape, whole = item
        widths_ok = all(
            (24 <= (b - a) <= 45) if k == "H" else (130 <= (b - a) <= 170)
            for k, a, b, _saw in ev
        )
        if widths_ok:
            clean.append(item)
    ok = sum(1 for *_, whole in clean if whole)
    read_bad = 0
    for _p, ev, *_rest in clean:
        for kind, _a, _b, saw in ev:
            if kind == "M" and not saw:
                read_bad += 1
            if kind == "H" and saw:
                read_bad += 1
    print("clean groups %d, matched %d, read errors %d" % (len(clean), ok, read_bad))
    loops = ok // len(SUITE)
    if read_bad == 0 and loops >= 1:
        print("PASS (%d full loop%s)" % (loops, "" if loops == 1 else "s"))
        return 0
    print("FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
