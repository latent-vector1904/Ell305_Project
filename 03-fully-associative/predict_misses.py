#!/usr/bin/env python3
"""Independent LRU model. Not the Verilog. Predict miss counts before the RTL run."""

BLOCKS = [0x00, 0x04, 0x08, 0x0C]


def fresh():
    return {
        "valid": [False] * 4,
        "tag": [None] * 4,
        "age": [0, 1, 2, 3],  # 0 = most recently used
    }


def touch(st, w):
    old = st["age"][w]
    for j in range(4):
        if j == w:
            st["age"][j] = 0
        elif st["age"][j] < old:
            st["age"][j] += 1


def victim(st):
    for j in range(4):
        if not st["valid"][j]:
            return j
    oldest = -1
    best = 0
    for j in range(4):
        if st["age"][j] >= oldest:
            oldest = st["age"][j]
            best = j
    return best


def access(st, addr):
    tag = addr >> 2
    for j in range(4):
        if st["valid"][j] and st["tag"][j] == tag:
            touch(st, j)
            return False
    w = victim(st)
    st["valid"][w] = True
    st["tag"][w] = tag
    touch(st, w)
    return True


def run(name, addrs):
    st = fresh()
    misses = sum(1 for a in addrs if access(st, a))
    return name, len(addrs), misses, len(addrs) - misses


def victim_seq(v):
    seq = list(BLOCKS)
    seq += [b for k, b in enumerate(BLOCKS) if k != v]
    seq.append(0x10)
    seq += [b for k, b in enumerate(BLOCKS) if k != v]
    seq.append(0x10)
    seq.append(BLOCKS[v])
    return seq


def main():
    tests = [
        run("temporal", [0x00] * 5),
        run("spatial", [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]),
        run("conflict", [0x00, 0x10, 0x00, 0x10]),
        run("capacity", [0x00, 0x04, 0x08, 0x0C, 0x00, 0x04, 0x08, 0x0C]),
        run("replacement", [0x00, 0x00, 0x10, 0x00]),
        run("independence", [0x00, 0x04, 0x00, 0x04]),
        run("reverse", [0x03, 0x02, 0x01, 0x00]),
        run("top", [0xFC, 0xFF]),
    ]
    for v, base in enumerate(BLOCKS):
        tests.append(run("victim_%02x" % base, victim_seq(v)))
    print("predicted  test            acc  miss  hit   miss_rate")
    for name, n, m, h in tests:
        print("  %-14s %3d  %3d  %3d   %d/%d" % (name, n, m, h, m, n))


if __name__ == "__main__":
    main()
