# Cache sim waveform report

Source: `shrike_fixed/waves/cache_sim.vcd`

## Results

| Exp | Pattern | Reqs | Hits | Misses | Hit rate | Notes |
|-----|---------|------|------|--------|----------|-------|
| 0 | always 0x00 | 4 | 3 | 1 | 75% | cold miss then hits |
| 1 | sequential 0..7 | 8 | 6 | 2 | 75% | miss at block starts 0x00 & 0x04 |
| 2 | alt 0x00/0x10 | 4 | 0 | 4 | 0% | conflict misses (same index) |
| 3 | 0x00/40/80/C0 | 4 | 0 | 4 | 0% | cold misses, different tags |

## Completed transactions

| time(ns) | exp | addr | hit/miss | data |
|----------|-----|------|----------|------|
| 150 | 0 | 0x01 | MISS | 0x01 |
| 200 | 0 | 0x03 | HIT | 0x03 |
| 250 | 0 | 0x03 | HIT | 0x03 |
| 300 | 0 | 0x03 | HIT | 0x03 |
| 470 | 1 | 0x01 | MISS | 0x01 |
| 520 | 1 | 0x03 | HIT | 0x01 |
| 570 | 1 | 0x02 | HIT | 0x02 |
| 620 | 1 | 0x03 | HIT | 0x03 |
| 740 | 1 | 0x05 | MISS | 0x05 |
| 790 | 1 | 0x05 | HIT | 0x05 |
| 840 | 1 | 0x06 | HIT | 0x06 |
| 890 | 1 | 0x07 | HIT | 0x07 |
| 1060 | 2 | 0x01 | MISS | 0x01 |
| 1120 | 2 | 0x11 | MISS | 0x11 |
| 1180 | 2 | 0x01 | MISS | 0x01 |
| 1240 | 2 | 0x11 | MISS | 0x11 |
| 1410 | 3 | 0x01 | MISS | 0x01 |
| 1470 | 3 | 0x41 | MISS | 0x41 |
| 1530 | 3 | 0x81 | MISS | 0x40 |
| 1590 | 3 | 0xC1 | MISS | 0x80 |

## ASCII wave — Experiment 0 (first ~320 ns)
Each column ≈ 10 ns (one clock).

rst                  x¯¯¯____________________________¯
req                  x____¯___________¯____¯____¯_____
done                 x______________¯____¯____¯____¯__
cache_hit            x__________________¯¯___¯¯___¯¯__
cache_miss           x______¯¯¯¯¯¯¯¯¯_________________
mem_read_internal    x_______¯¯¯¯__¯¯¯¯_______________
fetch_req            x______¯¯¯¯¯¯¯___________________
fetch_done           x____________¯_____¯_____________
address              X00000000000000000000000000000000
                     X00000000123330123333333333333333

## Bug note (data path)
`fetch_req` stays high until `fetch_done` is observed; the fetch FSM returns to IDLE one cycle earlier and can start a **spurious extra fetch**. That shows up as `mem_tx = misses+1` on exps 2/3 and **wrong `data_out` on misses after the first** (value is one block behind). Hit/miss detection itself is correct.

Open the full wave with: `gtkwave shrike_fixed/waves/cache_sim.vcd`