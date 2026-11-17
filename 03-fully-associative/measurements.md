# LRU cache: record of the work, and the numbers for the report

This file is the source for the report tables. The miss counts were predicted from the replacement rule before the register-transfer simulation was counted, and the logic analyzer then showed the same counts.

The comparison report in `lru/report/` was written from simulation only. It says the LRU cache had not been on the logic analyzer. That sentence is out of date. The bitstream below was flashed to the Shrike Lite and recorded on the Zeroplus LAP-C 16032.

## What was built

Fully associative cache, same capacity as the direct-mapped board design.

- Main memory is 256 bytes. The byte at an address is the address.
- The cache is 4 lines of 4 bytes, 16 bytes.
- The block tag is `address[7:2]`. The byte offset is `address[1:0]`. A block may sit in any line.
- Age 0 is most recently used. Age 3 is least recently used. An empty line is taken before any valid line is evicted. The empty line with the lowest index wins. If every line is valid, the greatest age wins, and a tie goes to the higher index.
- A miss reads the aligned 4-byte line once. A hit does not read memory.
- The fetch unit ignores a new request on the cycle `fetch_done` is still high, so one miss cannot start a second fill.

Two copies of the logic exist.

| Copy | Where | Role |
|---|---|---|
| Simulation | `lru/src/` | No clock enable. This is the design the long testbench runs. |
| Board | `03-fully-associative/ffpga/src/` | Same steps, but only when `ce` is high. |

On the board, `ce` is one pulse every \(2^{23}\) cycles of the 50 MHz oscillator (`DIV_MSB = 22` in `cache_sim_top`). One cache step is therefore exactly 8,388,608 oscillator cycles, which is 0.16777216 s. The stretch is only so the analyzer can see the pulses. It does not change how many steps a hit or a miss takes.

The place-and-route of `03-fully-associative/ffpga/build/bitstream/FPGA_bitstream_MCU.bin` used 35% of the logic blocks, 32% of the LUTs, and 17% of the flip-flops. It was flashed with `shrike.flash()` over the board's MicroPython port.

The analyzer clips that are switching:

| Signal | Header | FPGA pin | Analyzer channel |
|---|---|---|---|
| Hit | F15 | PIN_6 | A0 |
| Miss | F14 | PIN_5 | A1 |
| Memory read | F17 | PIN_8 | A2 |
| Request | F18 | PIN_9 | A3 |
| Test number bit 0 | F10 | PIN_1 | A4 |
| Test number bit 1 | F11 | PIN_2 | A5 |
| Test number bit 2 | F8 | PIN_23 | A6 |

Seven clips change. An eighth clip, if it is on the pod, is not attached to a pin that toggles. `done` (PIN_20) and the slow clock (PIN_3) are not in this recording.

The test number is the phase output. Tests 0 through 7 are one code each. Only three bits are brought out, so the four victim tests that follow reuse codes 0, 1, 2, and 3. Their shape is thirteen pulses, which none of the first eight tests have, so the label and the shape together name the test.

| Phase | Test |
|---|---|
| 0 | Temporal, or later the victim at `0x00` |
| 1 | Spatial, or later the victim at `0x04` |
| 2 | Conflict, or later the victim at `0x08` |
| 3 | Capacity, or later the victim at `0x0C` |
| 4 | Replacement |
| 5 | Independence |
| 6 | Reverse line |
| 7 | Top of memory |

## What the earlier simulation already covered

`lru/tb_lru.v` on `lru/src/`, Icarus Verilog 12.0, re-run for this note. The banner is `ALL TESTS PASSED`.

- 1,498 accesses: 1,076 hits, 422 misses.
- Every miss read memory (422). No hit did (0).
- The returned byte equalled the address on every access.
- Hit and miss were never both true.
- The sweep walks all 64 blocks for temporal reuse and for spatial reuse, then the free-line case, all four LRU victims, and a capacity walk of the whole memory. The last four blocks of that walk (`0xF0`, `0xF4`, `0xF8`, `0xFC`) still hit, and the next older block misses.

That sweep is too long for one analyzer record at this divider. The twelve tests below are the ones that have a distinct shape, and they are the ones on the board.

## Predicted miss counts, written before the RTL was counted

The prediction is `lru/predict_misses.py`. It is a separate model of the same rule: four tags, empty line first, otherwise the oldest age. It does not read the Verilog.

A direct-mapped column is included for the eight tests that both organisations can be given. Its rule is index `address[3:2]`, tag `address[7:4]`, one line per index. The victim tests are an LRU question. Under direct mapping, `0x10` always evicts the line that holds `0x00`, so those four tests are not the same experiment and are left blank there.

| Test | Addresses | Predicted LRU | Predicted direct-mapped |
|---|---|---|---|
| Temporal | `0x00` five times | 1 / 5 | 1 / 5 |
| Spatial | `0x00` through `0x07` | 2 / 8 | 2 / 8 |
| Conflict | `0x00`, `0x10`, `0x00`, `0x10` | 2 / 4 | 4 / 4 |
| Capacity | `0x00`, `0x04`, `0x08`, `0x0C`, then the same four | 4 / 8 | 4 / 8 |
| Replacement | `0x00`, `0x00`, `0x10`, `0x00` | 2 / 4 | 3 / 4 |
| Independence | `0x00`, `0x04`, `0x00`, `0x04` | 2 / 4 | 2 / 4 |
| Reverse | `0x03`, `0x02`, `0x01`, `0x00` | 1 / 4 | 1 / 4 |
| Top | `0xFC`, `0xFF` | 1 / 2 | 1 / 2 |
| Victim `0x00` | fill four, refresh the other three, bring in `0x10`, check | 6 / 13 | — |
| Victim `0x04` | same, leaving `0x04` untouched | 6 / 13 | — |
| Victim `0x08` | same, leaving `0x08` untouched | 6 / 13 | — |
| Victim `0x0C` | same, leaving `0x0C` untouched | 6 / 13 | — |

Why the two columns differ:

- Conflict. `0x00` and `0x10` are different blocks. Direct mapping gives both index 0, so each one throws the other out: four misses. The LRU cache still has free lines, so the third and fourth accesses hit.
- Replacement. Direct mapping overwrites `0x00` with `0x10`, so the last `0x00` misses (3 / 4). The LRU cache puts `0x10` in a free line, so the last `0x00` hits (2 / 4).
- Capacity. Four blocks, four lines, no shared index. Both organisations miss four times and then hit four times.
- Each victim. After the four fills, the untouched line is the oldest. `0x10` replaces that line and no other. The three refreshed lines and `0x10` hit. The untouched address misses. That is 6 misses and 7 hits.

## The RTL confirmed the prediction

`lru/tb_latency.v` on the board RTL, with `ce` tied high so one simulator clock is one cache step. Every count matched the table above. The returned byte matched the address. All 39 misses read memory. None of the 52 hits did.

| Test | Accesses | Misses | Hits | Miss rate |
|---|---|---|---|---|
| Temporal | 5 | 1 | 4 | 1/5 = 20% |
| Spatial | 8 | 2 | 6 | 2/8 = 25% |
| Conflict | 4 | 2 | 2 | 2/4 = 50% |
| Capacity | 8 | 4 | 4 | 4/8 = 50% |
| Replacement | 4 | 2 | 2 | 2/4 = 50% |
| Independence | 4 | 2 | 2 | 2/4 = 50% |
| Reverse | 4 | 1 | 3 | 1/4 = 25% |
| Top | 2 | 1 | 1 | 1/2 = 50% |
| Victim `0x00` | 13 | 6 | 7 | 6/13 = 46.2% |
| Victim `0x04` | 13 | 6 | 7 | 6/13 = 46.2% |
| Victim `0x08` | 13 | 6 | 7 | 6/13 = 46.2% |
| Victim `0x0C` | 13 | 6 | 7 | 6/13 = 46.2% |

The direct-mapped conflict example, 4/4 = 100%, is the other organisation. It is not what this cache does.

The long sweep's miss rate is 422/1498 = 211/749 = 28.2%. Its hit time and miss penalty are the same numbers as below, because neither depends on the address.

## Miss penalty in 50 MHz cycles

Latency is the number of cache steps from the cycle that enters `COMPARE` until the cycle `done` is high. One cache step is \(2^{23} = 8{,}388{,}608\) cycles of the 50 MHz clock.

A hit of `0x00` after that line was resident:

| Step | Cache | Fetch | Hit | Done | Data |
|---|---|---|---|---|---|
| 0 | COMPARE | idle | 0 | 0 | — |
| 1 | RETURN | idle | 1 | 0 | — |
| 2 | IDLE | idle | 1 | 1 | `0x00` |

Hit time = 2 cache steps = \(2 \times 2^{23} = 16{,}777{,}216\) cycles of the 50 MHz clock (0.33554432 s on the board).

A miss of `0x00` from an empty cache:

| Step | Cache | Fetch | Miss | Memory read | Done | What this step is |
|---|---|---|---|---|---|---|
| 0 | COMPARE | idle | 0 | 0 | 0 | Compare. The miss is decided here; the flag is registered, so it is high on the next step. `fetch_req` is issued. |
| 1 | FETCH | idle | 1 | 0 | 0 | The fetch unit sees the registered request and moves to READ0. |
| 2 | FETCH | READ0 | 1 | 1 | 0 | Byte 0 of the line. |
| 3 | FETCH | READ1 | 1 | 1 | 0 | Byte 1. |
| 4 | FETCH | READ2 | 1 | 1 | 0 | Byte 2. |
| 5 | FETCH | READ3 | 1 | 1 | 0 | Byte 3. Memory read drops at the end of this step. |
| 6 | FETCH | DONE | 1 | 0 | 0 | `fetch_done` is scheduled. |
| 7 | FETCH | idle | 1 | 0 | 0 | `fetch_done` is observed. The line is written and touched. |
| 8 | RETURN | idle | 1 | 0 | 0 | The requested byte is selected. `done` is scheduled. |
| 9 | IDLE | idle | 1 | 0 | 1 | `done` is high. The byte is valid. |

Miss time = 9 cache steps = \(9 \times 2^{23} = 75{,}497{,}472\) cycles of the 50 MHz clock (1.50994944 s).

The memory-read burst is steps 2 through 5: 4 cache steps = \(4 \times 2^{23} = 33{,}554{,}432\) oscillator cycles. That is READ0, READ1, READ2, READ3. Memory is combinational (`ready` equals `read_en`), so each of those four states is exactly one cache step.

The path is not only the names COMPARE, READ0, READ1, READ2, READ3, DONE, and RETURN. Two registered handshakes are real steps as well: the cycle the fetch unit accepts `fetch_req` (step 1), and the cycle the cache sees `fetch_done` and writes the line (step 7). Leaving either out makes the sum 7, and the trace is 9.

Miss penalty, for the AMAT formula, is the extra cost of a miss over a hit:

\[
9 - 2 = 7 \text{ cache steps} = 7 \times 2^{23} = 58{,}720{,}256 \text{ cycles of the 50 MHz clock.}
\]

Those 7 steps are the fill (steps 1 through 7). A hit skips them and goes from COMPARE to RETURN. Using 9 as the penalty would add the hit's own steps a second time.

Every hit takes 2 steps and every miss takes 9. The address does not change the latency. Only the miss rate changes the average.

## AMAT

\[
\mathrm{AMAT} = \text{hit time} + \text{miss rate} \times \text{miss penalty}
= 2 + \frac{m}{n} \times 7
= \frac{2n + 7m}{n} \text{ cache steps.}
\]

Multiply by \(2^{23}\) for oscillator cycles. The value is a fraction of a cycle when \(n\) does not divide \(2n+7m\). That is the average, not a claim that a single access takes a fractional cycle.

| Test | Miss rate | AMAT (cache steps) | AMAT (50 MHz cycles) |
|---|---|---|---|
| Temporal | 1/5 | 17/5 = 3.40 | 28,521,267.2 |
| Spatial | 2/8 | 15/4 = 3.75 | 31,457,280 |
| Reverse | 1/4 | 15/4 = 3.75 | 31,457,280 |
| Victim, each of the four | 6/13 | 68/13 = 5.231 | 43,878,872.6 |
| Conflict | 2/4 | 11/2 = 5.50 | 46,137,344 |
| Capacity | 4/8 | 11/2 = 5.50 | 46,137,344 |
| Replacement | 2/4 | 11/2 = 5.50 | 46,137,344 |
| Independence | 2/4 | 11/2 = 5.50 | 46,137,344 |
| Top | 1/2 | 11/2 = 5.50 | 46,137,344 |
| Whole 1,498-access sweep | 422/1498 | 2975/749 = 3.972 | 33,319,237.4 |

Inside this LRU suite the worst AMAT is 11/2 cache steps, and five tests share it. Conflict is one of them. It is not worse than capacity. Hit time is constant, so the order is exactly the order of the miss rates.

The direct-mapped numbers, same hit time and the same 7-step penalty, are where conflict becomes the worst test:

| Test | Direct-mapped miss rate | Direct-mapped AMAT | LRU miss rate | LRU AMAT |
|---|---|---|---|---|
| Temporal | 1/5 | 17/5 = 3.40 | 1/5 | 17/5 = 3.40 |
| Spatial | 2/8 | 15/4 = 3.75 | 2/8 | 15/4 = 3.75 |
| Reverse | 1/4 | 15/4 = 3.75 | 1/4 | 15/4 = 3.75 |
| Capacity | 4/8 | 11/2 = 5.50 | 4/8 | 11/2 = 5.50 |
| Independence | 2/4 | 11/2 = 5.50 | 2/4 | 11/2 = 5.50 |
| Top | 1/2 | 11/2 = 5.50 | 1/2 | 11/2 = 5.50 |
| Replacement | 3/4 | 29/4 = 7.25 | 2/4 | 11/2 = 5.50 |
| Conflict | 4/4 | 9 = 9.00 | 2/4 | 11/2 = 5.50 |

Conflict under direct mapping is a miss every time, so its AMAT is the full miss latency, 9 cache steps. That is the worst cell in the table. The LRU organisation cuts that test from 4/4 to 2/4 and the AMAT from 9 to 5.50. Replacement moves from 7.25 to 5.50 for the same reason: `0x10` no longer destroys `0x00`.

Capacity is the test whose shape carries the interpretation. The trace is four misses and then four hits, and the AMAT stays 5.50 under both rules. Nothing is evicted, because the four addresses are four different lines and the cache has room for all four. Conflict is the test whose rate carries the interpretation. Same two addresses, and the AMAT depends on the placement rule.

## Analyzer confirmation

Recording: `lru/waves/lru_cycles.csv`. Zeroplus LAP-C 16032, 100 Hz, threshold 1.5 V, 32,767 samples (327.67 s, the whole sample memory). The request pulse is the ruler for one cache step: its median width is 17 samples. At 100 Hz that is 0.17 s, against \(2^{23}/50\,\mathrm{MHz} = 0.16777216\) s.

| Pulse | Median width | Width / 17 | Cache steps from the FSM |
|---|---|---|---|
| Request | 17 samples | 1.00 | 1, the request strobe |
| Hit | 33 samples | 1.94 | 2 |
| Memory read | 67 samples | 3.94 | 4 |
| Miss | 150 samples | 8.82 | 9 |

The fractions are one sample off the integers because a step is 16.78 samples and the analyzer stores whole samples. 9 steps would be 151.0 samples; the median miss is 150. 2 steps would be 33.6 samples; the median hit is 33. 4 steps would be 67.1 samples; the median read is 67.

The phase bits named every group. Thirty complete tests matched the predicted miss count, and every one of them obeyed the read rule (a miss had a memory read inside it, a hit did not). The record holds two full passes of all twelve tests, then a third pass through replacement, where the sample memory ends. It opens on the tail of a victim that had already started. Incomplete groups at the two ends are the ends of the buffer, not a wrong count.

| What the phase and the shape said | Times it appeared complete | Misses / accesses | Predicted |
|---|---|---|---|
| Temporal | 3 | 1/5 | 1/5 |
| Spatial | 3 | 2/8 | 2/8 |
| Conflict | 3 | 2/4 | 2/4 |
| Capacity | 3 | 4/8 | 4/8 |
| Replacement | 3 | 2/4 | 2/4 |
| Independence | 2 | 2/4 | 2/4 |
| Reverse | 2 | 1/4 | 1/4 |
| Top | 2 | 1/2 | 1/2 |
| Victim `0x00` | 2 | 6/13 | 6/13 |
| Victim `0x04` | 2 | 6/13 | 6/13 |
| Victim `0x08` | 2 | 6/13 | 6/13 |
| Victim `0x0C` | 3 | 6/13 | 6/13 |

Conflict on the wire is miss, miss, hit, hit, with phase 2. It is not four misses. Replacement is miss, hit, miss, hit, with phase 4. Capacity is four misses and four hits, with phase 3. The victim whose phase is 0 sits after phase 7 and is thirteen pulses, so it is not the temporal test that also uses phase 0.
