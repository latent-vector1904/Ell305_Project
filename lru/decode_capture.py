#!/usr/bin/env python3
"""Read a sigrok CSV capture of the LRU board suite and score every test."""

import csv
import sys
from pathlib import Path

# One slow tick is 2^23 / 50e6 seconds at DIV_MSB = 22.
TICK_S = (2 ** 23) / 50e6

# Shapes the sequencer repeats, in order. M = miss, H = hit.
SUITE = [
    ("temporal", "MHHHH"),
    ("spatial", "MHHHMHHH"),
    ("conflict", "MMHH"),
    ("capacity", "MMMMHHHH"),
    ("replacement", "MHMH"),
    ("independence", "MMHH"),
    ("reverse", "MHHH"),
    ("top", "MH"),
    ("victim_00", "MMMMHHHMHHHHM"),
    ("victim_04", "MMMMHHHMHHHHM"),
    ("victim_08", "MMMMHHHMHHHHM"),
    ("victim_0c", "MMMMHHHMHHHHM"),
]


def load_csv(path):
    names = ["A0", "A1", "A2", "A3", "A4", "A5", "A6", "A7",
             "B0", "B1", "B2", "B3", "B4", "B5", "B6", "B7"]
    rows = []
    with open(path, newline="") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(";") or line.startswith("logic"):
                if line.startswith("; Channels"):
                    # "; Channels (16/16): A0, A1, ..."
                    rhs = line.split(":", 1)[-1]
                    found = [p.strip() for p in rhs.split(",") if p.strip()]
                    if found:
                        names = found
                continue
            parts = line.split(",")
            try:
                rows.append([1 if int(float(p)) else 0 for p in parts])
            except ValueError:
                continue
    if not rows:
        raise SystemExit("capture has no samples")
    width = len(rows[0])
    chans = [[r[i] if i < len(r) else 0 for r in rows] for i in range(width)]
    if len(names) < width:
        names = names + ["ch%d" % i for i in range(len(names), width)]
    return names[:width], chans


def _bits(rows, start):
    if not rows:
        return []
    width = max(len(r) for r in rows) - start
    chans = [[] for _ in range(width)]
    for r in rows:
        for i in range(width):
            cell = r[start + i].strip() if start + i < len(r) else "0"
            chans[i].append(1 if cell in ("1", "1.0") else 0)
    return chans


def runs(bits):
    """High and low runs as (level, start, length)."""
    if not bits:
        return []
    out = []
    level = bits[0]
    begin = 0
    for i in range(1, len(bits)):
        if bits[i] != level:
            out.append((level, begin, i - begin))
            level = bits[i]
            begin = i
    out.append((level, begin, len(bits) - begin))
    return out


def high_pulses(bits):
    return [(s, n) for level, s, n in runs(bits) if level == 1]


def median(xs):
    if not xs:
        return 0
    ys = sorted(xs)
    return ys[len(ys) // 2]


def classify(names, chans, rate):
    """Return dict role -> channel index. Tick length comes from the data."""
    stats = []
    for i, bits in enumerate(chans):
        pulses = high_pulses(bits)
        edges = sum(1 for a, b in zip(bits, bits[1:]) if a != b)
        stats.append({
            "i": i,
            "name": names[i] if i < len(names) else "ch%d" % i,
            "edges": edges,
            "pulses": pulses,
            "widths": [n for _s, n in pulses],
            "high": sum(bits),
            "n": len(bits),
        })

    active = [s for s in stats if s["edges"] >= 4]
    print("Active channels:")
    for s in active:
        w = s["widths"]
        short = sorted(w)[:8]
        print("  %s edges=%d pulses=%d median=%d shortest=%s" % (
            s["name"], s["edges"], len(w), median(w), short))

    # The request line pulses once per access, so it has the most edges
    # unless the slow debug clock is also clipped. That clock is high for
    # about half the record. A miss line can also sit near half-duty, but
    # it never has the most edges.
    clock = None
    if active:
        most = max(active, key=lambda s: s["edges"])
        lows = [n for level, _s, n in runs(chans[most["i"]]) if level == 0]
        if lows and most["n"] and 0.40 <= (most["high"] / most["n"]) <= 0.60:
            hi = median(most["widths"]) if most["widths"] else 0
            lo = median(lows)
            if hi >= 2 and abs(hi - lo) <= 0.25 * max(hi, lo):
                clock = most
    tick = None
    if clock is not None:
        # clk_out is high for half a tick, so a tick is two median half-periods.
        tick = 2 * median(clock["widths"])
        print("Clock %s, tick ~ %d samples (%.3f s)" % (
            clock["name"], tick, tick / rate))

    # Pulse channels are the ones that are not the clock and not a slow phase bit.
    pulse_ch = []
    for s in active:
        if clock is not None and s["i"] == clock["i"]:
            continue
        if not s["widths"]:
            continue
        med = median(s["widths"])
        # Phase bits stay high for a whole test, many times a miss.
        if tick and med > tick * 15:
            print("Skip %s as a slow level (median %d)" % (s["name"], med))
            continue
        if not tick and med > rate * 3:
            print("Skip %s as a slow level (median %d)" % (s["name"], med))
            continue
        pulse_ch.append(s)

    if tick is None and pulse_ch:
        # Shortest cluster is one tick (request, and done if it is wired).
        shortest = min(median(s["widths"]) for s in pulse_ch)
        tick = max(shortest, 1)
        print("Tick from shortest pulses: %d samples (%.3f s)" % (tick, tick / rate))

    def near(width, ticks, tol=0.45):
        return abs(width - ticks * tick) <= max(3, tol * ticks * tick)

    roles = {}
    for s in pulse_ch:
        med = median(s["widths"])
        # Prefer the longer class when a channel mixes widths; miss is the long one.
        if near(med, 9, 0.35) or (tick and med > 6 * tick):
            role = "miss"
        elif near(med, 4, 0.35):
            role = "mem_read"
        elif near(med, 2, 0.4):
            role = "hit"
        elif near(med, 1, 0.55):
            role = "request"
        else:
            role = None
        print("  role guess %s median=%d -> %s" % (s["name"], med, role))
        if role:
            # Keep the channel whose median is closest to the ideal.
            ideal = {"miss": 9, "mem_read": 4, "hit": 2, "request": 1}[role]
            prev = roles.get(role)
            if prev is None or abs(med - ideal * tick) < abs(median(prev["widths"]) - ideal * tick):
                roles[role] = s
    if clock is not None:
        roles["clock"] = clock
    return roles, tick


def events_from(hit_bits, miss_bits, read_bits, tick):
    """One event per hit or miss pulse. Gap splits tests."""
    n = len(hit_bits)
    events = []
    i = 0
    min_w = max(2, int(tick * 0.5))
    while i < n:
        if hit_bits[i] or miss_bits[i]:
            kind = "M" if miss_bits[i] else "H"
            j = i
            saw_read = False
            while j < n and ((miss_bits[j] if kind == "M" else hit_bits[j]) or (j - i) < 2):
                if read_bits is not None and read_bits[j]:
                    saw_read = True
                # Stop when this pulse has fallen and stayed low.
                if kind == "M" and not miss_bits[j] and j > i:
                    break
                if kind == "H" and not hit_bits[j] and j > i:
                    break
                j += 1
            # Walk back to the actual falling edge.
            while j > i and not (miss_bits[j - 1] if kind == "M" else hit_bits[j - 1]):
                j -= 1
            width = j - i
            if width >= min_w:
                events.append({"kind": kind, "start": i, "end": j, "read": saw_read})
            i = max(j + 1, i + 1)
        else:
            i += 1

    # Group by the quiet stretch between pulses. Inside a test the
    # result-to-result hole is about 3 ticks. Between tests it is about 8.
    groups = []
    cur = []
    for e in events:
        if cur:
            gap = e["start"] - cur[-1]["end"]
            if gap > 5 * tick:
                groups.append(cur)
                cur = []
        cur.append(e)
    if cur:
        groups.append(cur)
    return groups


def shapes(groups):
    return ["".join(e["kind"] for e in g) for g in groups]


def score(groups):
    got = shapes(groups)
    print("Groups (%d):" % len(got))
    for i, s in enumerate(got):
        print("  %2d %s" % (i, s))
    best = None
    if not got:
        return got, best
    for offset in range(len(got)):
        for start in range(len(SUITE)):
            details = []
            k = 0
            while offset + k < len(got):
                name, shape = SUITE[(start + k) % len(SUITE)]
                seen = got[offset + k]
                match = seen == shape
                details.append((name, shape, seen, match))
                k += 1
                if not match:
                    break
            ok = sum(1 for d in details if d[3])
            # A mismatch stops the run, so ok is the matching prefix.
            if best is None or ok > best[0] or (ok == best[0] and len(details) > best[1]):
                best = (ok, len(details), offset, start, details)
    return got, best


def check_reads(groups, roles):
    bad = 0
    if "mem_read" not in roles:
        print("Memory-read channel was not in this capture.")
        return 0
    for gi, g in enumerate(groups):
        for e in g:
            if e["kind"] == "M" and not e["read"]:
                print("FAIL group %d miss at sample %d has no memory read" % (gi, e["start"]))
                bad += 1
            if e["kind"] == "H" and e["read"]:
                print("FAIL group %d hit at sample %d has a memory read" % (gi, e["start"]))
                bad += 1
    return bad


def main():
    path = Path(sys.argv[1])
    rate = float(sys.argv[2]) if len(sys.argv) > 2 else 100.0
    names, chans = load_csv(path)
    print("Samples %d  channels %d  rate %s Hz" % (len(chans[0]) if chans else 0, len(chans), rate))
    roles, tick = classify(names, chans, rate)
    if "hit" not in roles or "miss" not in roles or tick is None:
        print("Could not find hit and miss channels.")
        return 1
    print("Using hit=%s miss=%s read=%s request=%s" % (
        roles["hit"]["name"], roles["miss"]["name"],
        roles.get("mem_read", {}).get("name", "-"),
        roles.get("request", {}).get("name", "-")))
    read_ch = roles.get("mem_read")
    groups = events_from(
        chans[roles["hit"]["i"]],
        chans[roles["miss"]["i"]],
        chans[read_ch["i"]] if read_ch else None,
        tick,
    )
    got, best = score(groups)
    read_bad = check_reads(groups, roles)
    if not best or best[0] == 0:
        print("No test group matched the LRU suite.")
        return 1
    ok, checked, offset, start, details = best
    print("Aligned at group %d, suite index %d: %d/%d tests matched" % (offset, start, ok, checked))
    for name, want, seen, match in details:
        mark = "OK" if match else "FAIL"
        print("  %s  %-14s want %s  got %s" % (mark, name, want, seen))
    if read_bad == 0 and ok >= len(SUITE):
        loops = ok // len(SUITE)
        print("ALL CAPTURED TESTS PASSED (%d full loop%s)" % (loops, "" if loops == 1 else "s"))
        return 0
    if read_bad == 0 and ok == checked and checked >= 8:
        print("PARTIAL PASS %d tests, capture ended inside the suite" % ok)
        return 1
    print("CAPTURE MISMATCH")
    return 1


if __name__ == "__main__":
    sys.exit(main())
