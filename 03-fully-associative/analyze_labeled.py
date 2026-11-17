#!/usr/bin/env python3
"""Score a labeled LRU capture. Phase bits are A4, A5, A6 (bit 0, 1, 2)."""

import sys
from collections import Counter

NAMES = {
    0: "temporal",
    1: "spatial",
    2: "conflict",
    3: "capacity",
    4: "replacement",
    5: "independence",
    6: "reverse",
    7: "top",
}
VICTIM = {0: "victim_00", 1: "victim_04", 2: "victim_08", 3: "victim_0c"}
PREDICT = {
    "temporal": (5, 1),
    "spatial": (8, 2),
    "conflict": (4, 2),
    "capacity": (8, 4),
    "replacement": (4, 2),
    "independence": (4, 2),
    "reverse": (4, 1),
    "top": (2, 1),
    "victim_00": (13, 6),
    "victim_04": (13, 6),
    "victim_08": (13, 6),
    "victim_0c": (13, 6),
}
EXPECT = {
    "temporal": "MHHHH",
    "spatial": "MHHHMHHH",
    "conflict": "MMHH",
    "capacity": "MMMMHHHH",
    "replacement": "MHMH",
    "independence": "MMHH",
    "reverse": "MHHH",
    "top": "MH",
    "victim_00": "MMMMHHHMHHHHM",
    "victim_04": "MMMMHHHMHHHHM",
    "victim_08": "MMMMHHHMHHHHM",
    "victim_0c": "MMMMHHHMHHHHM",
}


def load(path):
    rows = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(";") or line.startswith("logic"):
                continue
            rows.append([int(x) for x in line.split(",")])
    return rows


def pulses(bits, min_w):
    out = []
    start = None
    for i, b in enumerate(bits):
        if b and start is None:
            start = i
        elif not b and start is not None:
            if i - start >= min_w:
                out.append((start, i))
            start = None
    return out


def median(xs):
    ys = sorted(xs)
    return ys[len(ys) // 2]


def main():
    rows = load(sys.argv[1])
    n = len(rows)
    hit = [r[0] for r in rows]
    miss = [r[1] for r in rows]
    rd = [r[2] for r in rows]
    req = [r[3] for r in rows]
    phase = [r[4] | (r[5] << 1) | (r[6] << 2) for r in rows]
    tick = median([b - a for a, b in pulses(req, 8)])
    print("samples %d  request_tick_samples %d  (one cache step)" % (n, tick))

    events = []
    i = 0
    while i < n:
        if hit[i] or miss[i]:
            kind = "M" if miss[i] else "H"
            j = i
            saw = False
            while j < n and (miss[j] if kind == "M" else hit[j]):
                if rd[j]:
                    saw = True
                j += 1
            if j - i >= tick // 2:
                # Phase is steady during the pulse. Sample the middle.
                mid = (i + j) // 2
                events.append({
                    "kind": kind, "start": i, "end": j,
                    "width": j - i, "read": saw, "phase": phase[mid],
                })
            i = j + 1
        else:
            i += 1

    groups = []
    cur = []
    for e in events:
        if cur and e["start"] - cur[-1]["end"] > 5 * tick:
            groups.append(cur)
            cur = []
        cur.append(e)
    if cur:
        groups.append(cur)

    hit_w = [e["width"] for e in events if e["kind"] == "H"]
    miss_w = [e["width"] for e in events if e["kind"] == "M"]
    read_w = [b - a for a, b in pulses(rd, tick // 2)]
    print("hit_pulses %d median_samples %d  steps %.2f" % (
        len(hit_w), median(hit_w), median(hit_w) / tick))
    print("miss_pulses %d median_samples %d  steps %.2f" % (
        len(miss_w), median(miss_w), median(miss_w) / tick))
    print("read_pulses %d median_samples %d  steps %.2f" % (
        len(read_w), median(read_w), median(read_w) / tick))

    print("group phase shape misses/accesses read_ok name")
    ok = 0
    bad_read = 0
    for g in groups:
        shape = "".join(e["kind"] for e in g)
        # Majority phase inside the group.
        ph = Counter(e["phase"] for e in g).most_common(1)[0][0]
        misses = shape.count("M")
        name = VICTIM.get(ph, NAMES[ph]) if shape == "MMMMHHHMHHHHM" else NAMES.get(ph, "phase%d" % ph)
        pred = PREDICT.get(name)
        match = pred is not None and pred == (len(g), misses) and EXPECT.get(name) == shape
        reads_ok = all((e["kind"] == "M") == e["read"] for e in g)
        if not reads_ok:
            bad_read += 1
        if match:
            ok += 1
        print("  %s p=%d %-16s %d/%d  read %s  %s" % (
            "OK" if match else "..", ph, shape, misses, len(g),
            "ok" if reads_ok else "FAIL", name if match or shape in EXPECT.values() else ""))
    print("matched_groups %d  read_failures %d" % (ok, bad_read))


if __name__ == "__main__":
    main()
