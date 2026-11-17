#!/usr/bin/env python3
"""Turn test_template.txt into the sequencer ROM and the expected results.

The model is the board cache: 2 sets, 2 ways, 4-byte lines.
Index is address bit 2. Tag is address[7:3].
An empty way is used before the least-recently-used way.
"""

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE / "test_template.txt"
PREVIEW = HERE / "test_preview.txt"
SEQ = HERE / "ffpga" / "src" / "exam_seq.v"
TB = HERE / "tb_exam.v"
MAX_TESTS = 8
MAX_ADDRS = 64
HIT_CYCLES = 2
MISS_PENALTY = 7


def parse(text):
    tests = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if ":" in line:
            name, rest = line.split(":", 1)
            name = name.strip() or f"test{len(tests)}"
        else:
            name, rest = f"test{len(tests)}", line
        addrs = []
        for tok in rest.replace(",", " ").split():
            try:
                value = int(tok, 16)
            except ValueError:
                sys.exit(f"{TEMPLATE.name}:{lineno}: {tok!r} is not a hex address")
            if not 0 <= value <= 0xFF:
                sys.exit(f"{TEMPLATE.name}:{lineno}: {tok} is outside 00..FF")
            addrs.append(value)
        if not addrs:
            sys.exit(f"{TEMPLATE.name}:{lineno}: {name} has no addresses")
        tests.append((name, addrs))
    if not tests:
        sys.exit(f"{TEMPLATE.name}: no addresses")
    if len(tests) > MAX_TESTS:
        sys.exit(f"{len(tests)} tests. phase is 3 bits, so the sequencer holds {MAX_TESTS}.")
    count = sum(len(a) for _, a in tests)
    if count > MAX_ADDRS:
        sys.exit(f"{count} addresses. The sequencer index is 6 bits, so the list holds {MAX_ADDRS}.")
    return tests


def predict(tests):
    rows = []
    for phase, (name, addrs) in enumerate(tests):
        ways = [[None, None] for _ in range(2)]
        lru = [0, 0]
        shaped = []
        for addr in addrs:
            index = (addr >> 2) & 1
            tag = addr >> 3
            hit_way = next((w for w in range(2) if ways[index][w] == tag), None)
            if hit_way is None:
                empty = [w for w in range(2) if ways[index][w] is None]
                victim = min(empty) if empty else lru[index]
                ways[index][victim] = tag
                lru[index] = 1 - victim
                shaped.append((addr, False))
            else:
                lru[index] = 1 - hit_way
                shaped.append((addr, True))
        rows.append((phase, name, shaped))
    return rows


def rom_text(tests):
    flat = [a for _, addrs in tests for a in addrs]
    ends = []
    cursor = -1
    for _, addrs in tests:
        cursor += len(addrs)
        ends.append(cursor)
    last = len(flat) - 1
    case = "\n".join(
        f"                6'd{i}: rom = 8'h{addr:02X};" for i, addr in enumerate(flat)
    )
    end_expr = " || ".join(f"(i == 6'd{i})" for i in ends)
    phases = []
    for phase, end in enumerate(ends):
        if phase == 0:
            phases.append(f"            if (i <= 6'd{end}) phase_of = 3'd{phase};")
        elif phase == len(ends) - 1:
            phases.append(f"            else phase_of = 3'd{phase};")
        else:
            phases.append(f"            else if (i <= 6'd{end}) phase_of = 3'd{phase};")
    return f"""    localparam LAST = 6'd{last};

    function [7:0] rom;
        input [5:0] i;
        begin
            case (i)
{case}
                default: rom = 8'h00;
            endcase
        end
    endfunction

    function is_end;
        input [5:0] i;
        begin
            is_end = {end_expr};
        end
    endfunction

    function [2:0] phase_of;
        input [5:0] i;
        begin
{chr(10).join(phases)}
        end
    endfunction
"""


def expect_text(rows):
    flat = [(addr, hit) for _, _, shaped in rows for addr, hit in shaped]
    lines = []
    for i, (addr, hit) in enumerate(flat):
        miss = 0 if hit else 1
        lines.append(f"                {i}: expected = {{1'b{miss}, 8'h{addr:02X}}};")
    body = "\n".join(lines)
    return f"""    localparam NADDR = {len(flat)};

    function [8:0] expected;
        input integer i;
        begin
            case (i)
{body}
                default: expected = 9'h1ff;
            endcase
        end
    endfunction
"""


def splice(path, begin, end, body):
    text = path.read_text()
    b = text.find(begin)
    e = text.find(end)
    if b < 0 or e < 0 or e < b:
        sys.exit(f"{path.name} is missing the generated-block markers")
    e += len(end)
    path.write_text(text[:b] + begin + "\n" + body + end + text[e:])


def preview(rows):
    lines = [
        "2-way set-associative, 2 sets of 2 ways, 4 bytes per line.",
        "The cache is empty at the start of each test.",
        "Predicted from the address map. Simulation must match this shape.",
        f"Hit time {HIT_CYCLES} enable cycles. Miss penalty {MISS_PENALTY} enable cycles.",
        "AMAT = 2 + miss rate x 7, in enable cycles. One enable cycle is 2^23 clocks of 50 MHz.",
        "M = miss, H = hit.",
        "",
    ]
    total_n = 0
    total_m = 0
    for phase, name, shaped in rows:
        n = len(shaped)
        m = sum(1 for _, hit in shaped if not hit)
        rate = m / n
        amat = HIT_CYCLES + rate * MISS_PENALTY
        shape = " ".join("H" if hit else "M" for _, hit in shaped)
        lines.append(
            f"{phase}  {name:<14} {shape:<20} misses {m}/{n}  AMAT {amat:.2f}"
        )
        for addr, hit in shaped:
            lines.append(f"      {addr:02X}  {'HIT' if hit else 'MISS'}")
        lines.append("")
        total_n += n
        total_m += m
    lines.append(f"{len(rows)} tests, {total_n} addresses, {total_m} misses.")
    return "\n".join(lines) + "\n"


def main():
    tests = parse(TEMPLATE.read_text())
    rows = predict(tests)
    text = preview(rows)
    PREVIEW.write_text(text)
    splice(SEQ, "    // BEGIN GENERATED ROM", "    // END GENERATED ROM", rom_text(tests))
    splice(TB, "    // BEGIN GENERATED EXPECT", "    // END GENERATED EXPECT", expect_text(rows))
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
