# Two-way set-associative cache: prediction, simulation, and the board

This file records the two-way cache that was built, simulated, flashed to the Shrike Lite, and recorded on the Zeroplus LAP-C(16032). The miss counts were written down from the address map before either the simulator or the analyser was asked to confirm them. Both later agreed with that list.

The cache holds the same 16 bytes as the direct-mapped design: 2 sets, 2 ways, 4 bytes in a line. Main memory is 256 bytes, and the byte stored at an address is the address itself. The design is read-only. One miss reads the aligned 4-byte line once.

| Address bits | Field | Meaning |
|---|---|---|
| `[7:3]` | tag | which block |
| `[2]` | index | which set, 0 or 1 |
| `[1:0]` | offset | which byte inside the line |

An empty way is filled first. The empty way with the lower index wins. When both ways of a set hold a block, the way named by that set's LRU bit is replaced. After way W is used, the LRU bit becomes the other way, so the way just used is the one kept.

The fill machine is the same four-byte fetch used by the direct-mapped cache, including the guard that ignores `fetch_req` on the cycle `fetch_done` is still high. One miss therefore cannot start a second fill. The header pins are the same, so the analyser clips did not move.

The controller still has the four states IDLE, COMPARE, FETCH, and RETURN. Both ways of the selected set are compared in the one COMPARE cycle. A hit is still COMPARE then RETURN. A miss still waits for one four-byte fill. What changes from the direct-mapped cache is which accesses miss, not how many cycles a miss takes.

On the board the controller and the fetch unit advance only when the clock enable is high. `DIV_MSB = 22`, so the enable is high for one oscillator cycle every \(2^{23}\) cycles of the 50 MHz clock. One cache step is exactly 8,388,608 cycles of that clock, which is 0.16777216 s. The stretch exists so the analyser can see the pulses. It does not change the number of steps.

## What was done

The design lives in `02-two-way/`. The sources are the address decoder, the two-way store with one LRU bit per set, the controller, the block fetch unit, the memory model, the sequencer, and the top level that divides the oscillator.

`test_template.txt` holds the eight tests, 41 addresses. The cache is cleared between tests. `gen_test.py` reads that list and applies the replacement rule above. It does not read a waveform. It writes two things: the address ROM inside `exam_seq.v`, and the expected hit or miss for every address inside `tb_exam.v`. The human-readable copy of the prediction is `test_preview.txt`. That file is the "before" column of the tables below.

`run_sim.sh` then ran the RTL under Icarus Verilog with `DIV_MSB = 2`, so the enable arrives every 8 simulator clocks and the suite finishes quickly. The testbench checks, on every completion, that the returned byte equals the address, that hit and miss are complements, and that the miss bit matches the prediction. It also counts how many enable cycles each flag stays high, and it requires one memory-read pulse per miss. The log is `sim_results.txt`.

`build_test.sh` place-and-routed the same sources. The tools refuse a path that contains a space, so the build ran in `~/set_assoc_build` and the image was copied back to `ffpga/build/bitstream/FPGA_bitstream_MCU.bin`. The timing report gives an achievable clock of 86.595 MHz (period 11,548 ps). The board oscillator is 50 MHz. The design uses 131 logic LUTs and 83 logic flip-flops, plus 9 output flip-flops.

That MCU image was copied to the Shrike Lite with `mpremote` and programmed with `shrike.flash()`. The board replied `FLASH_OK`.

The Zeroplus LAP-C(16032) then recorded the running suite: 100 Hz, threshold 1.5 V, 32,767 samples, 327.67 s. This analyser offers 100 Hz and then 500 Hz. At 500 Hz the memory would last 65.5 s, which is one pass with almost no margin, so the capture used 100 Hz and held several passes. PulseView screenshots of the traces are in `waves/`.

| Signal | Header | Analyser channel |
|---|---|---|
| Hit | F15 | A0 |
| Miss | F14 | A1 |
| Memory read | F17 | A2 |
| Request | F18 | A3 |
| Test number bit 0 | F10 | A4 |
| Test number bit 1 | F11 | A5 |
| Test number bit 2 | F8 | A6 |

## Predicted miss counts, written from the address map

The cache is empty at the start of each test. M is a miss, H is a hit. These rows are `test_preview.txt`. They were the expected column loaded into the testbench. The simulation had to match them, and it did.

| Phase | Test | Addresses | Predicted shape | Predicted misses |
|---|---|---|---|---|
| 0 | Temporal | `00` five times | M H H H H | 1 / 5 |
| 1 | Spatial | `00` through `07` | M H H H M H H H | 2 / 8 |
| 2 | Conflict | `00`, `10`, `00`, `10` | M M H H | 2 / 4 |
| 3 | Capacity | `00`, `04`, `08`, `0C`, then the same four | M M M M H H H H | 4 / 8 |
| 4 | LRU | `00`, `10`, `00`, `20`, `00`, `10` | M M H M H M | 4 / 6 |
| 5 | Independence | `00`, `04`, `00`, `04` | M M H H | 2 / 4 |
| 6 | Reverse | `03`, `02`, `01`, `00` | M H H H | 1 / 4 |
| 7 | Top of memory | `FC`, `FF` | M H | 1 / 2 |

One pass is 8 tests, 41 addresses, 17 misses.

Why each row has that shape:

- Temporal. `00` is one block. The first access fills a way. The next four find it.
- Spatial. `00`–`03` are one block in set 0. `04`–`07` are the next block, in set 1. Two fills, then hits inside each line.
- Conflict. `00` and `10` are different blocks and both land in set 0, with tags 0 and 2. The set has two ways, so both stay resident. The third and fourth accesses hit. On the direct-mapped cache these two addresses share one line, so that test is four misses.
- Capacity. `00` is set 0 tag 0, `04` is set 1 tag 0, `08` is set 0 tag 1, `0C` is set 1 tag 1. Four blocks, four places, nothing is evicted. The second pass hits.
- LRU. `00`, `10`, and `20` are three blocks in set 0, and the set has two ways. `00` fills way 0 and the LRU bit becomes way 1. `10` fills way 1 and the LRU bit becomes way 0. `00` hits and the LRU bit becomes way 1, naming `10` as the victim. `20` replaces `10`. `00` is still present and hits. `10` was the victim and misses. The shape is miss, miss, hit, miss, hit, miss.
- Independence. `00` and `04` are different sets. Each misses once and then hits.
- Reverse. `03`, `02`, `01`, and `00` are four bytes of one block. One fill, then three hits.
- Top. `FC` and `FF` share tag 31 and set 1. One fill, then a hit.

## Simulation confirmed the prediction

Icarus Verilog 12.0, `tb_exam.v`, `DIV_MSB = 2`. The run is `sim_results.txt`.

The first pass, which is the 41 addresses above, matched the predicted miss bit on every address. The returned byte equalled the address on every access. Hit was the complement of miss. Across the whole run, including the later repeats of the suite, that was 1,263 accesses and 0 mismatches.

| Phase | Test | Simulated hits | Simulated misses | Predicted misses |
|---|---|---|---|---|
| 0 | Temporal | 4 | 1 | 1 / 5 |
| 1 | Spatial | 6 | 2 | 2 / 8 |
| 2 | Conflict | 2 | 2 | 2 / 4 |
| 3 | Capacity | 4 | 4 | 4 / 8 |
| 4 | LRU | 2 | 4 | 4 / 6 |
| 5 | Independence | 2 | 2 | 2 / 4 |
| 6 | Reverse | 3 | 1 | 1 / 4 |
| 7 | Top of memory | 1 | 1 | 1 / 2 |

Every hit flag in the run lasted 2 enable cycles (738 pulses, 0 of any other width). Every miss flag lasted 9 enable cycles (525 pulses, 0 of any other width). The memory-read pulse count equalled the miss-pulse count, 525. The testbench prints `PASS` only when all of those checks hold.

## Miss rate of each test

The rate is the predicted count, which is also the simulated count.

| Test | Misses / accesses | Miss rate |
|---|---|---|
| Temporal | 1 / 5 | 1/5 = 20% |
| Spatial | 2 / 8 | 1/4 = 25% |
| Conflict | 2 / 4 | 1/2 = 50% |
| Capacity | 4 / 8 | 1/2 = 50% |
| LRU | 4 / 6 | 2/3 = 66.7% |
| Independence | 2 / 4 | 1/2 = 50% |
| Reverse | 1 / 4 | 1/4 = 25% |
| Top of memory | 1 / 2 | 1/2 = 50% |
| One full pass | 17 / 41 | 17/41 = 41.5% |

Conflict on this cache is 2 misses / 4 accesses = 50%. The same four addresses on the direct-mapped cache are 4 / 4 = 100%.

## Hit time, miss time, and the miss penalty in 50 MHz cycles

Both machines are clocked by the enable. The tables below are enable cycles, counted from the code in `cache_controller.v` and `block_fetch_controller.v`. Memory is combinational: `ready` equals `read_en`, and the data out is the address, so each READ state completes on the next enable edge. Multiplying an enable cycle by \(2^{23}\) converts it to cycles of the 50 MHz oscillator.

A hit, once COMPARE is entered:

| Enable cycle | Cache state | Fetch state | Hit flag | Done | What this cycle is |
|---|---|---|---|---|---|
| 0 | COMPARE | idle | becomes 1 | 0 | Tag matches. Touch the way. Go to RETURN. |
| 1 | RETURN | idle | 1 | 1 | Select the byte. `done` is high. Go to IDLE. |
| 2 | IDLE | idle | cleared | cleared | The flag drops. |

Hit time = 2 enable cycles.

\[
2 \times 2^{23} = 16{,}777{,}216 \text{ cycles of the 50 MHz clock.}
\]

That is 0.33554432 s on the board, which is the stretched view of those same two steps.

A miss, once COMPARE is entered. The miss flag is set on cycle 0 and stays set until the IDLE cycle that follows RETURN.

| Enable cycle | Cache state | Fetch state | Miss flag | Memory read | Done | What this cycle is |
|---|---|---|---|---|---|---|
| 0 | COMPARE | idle | becomes 1 | 0 | 0 | No way matches. `fetch_req` is scheduled. The fetch unit has not seen it yet, because both machines sample on this same edge. |
| 1 | FETCH | idle to READ0 | 1 | becomes 1 | 0 | The fetch unit accepts the request. This handshake is its own cycle. |
| 2 | FETCH | READ0 | 1 | 1 | 0 | Byte 0 of the line. |
| 3 | FETCH | READ1 | 1 | 1 | 0 | Byte 1. |
| 4 | FETCH | READ2 | 1 | 1 | 0 | Byte 2. |
| 5 | FETCH | READ3 | 1 | falls | 0 | Byte 3. The read enable drops at the end of this cycle. |
| 6 | FETCH | DONE | 1 | 0 | 0 | `fetch_done` is scheduled. |
| 7 | FETCH | idle | 1 | 0 | 0 | The controller sees `fetch_done`, writes the line, and moves to RETURN. This second handshake is its own cycle. The fetch unit ignores `fetch_req` here, because `fetch_done` is still high, so the fill does not start again. |
| 8 | RETURN | idle | 1 | 0 | 1 | The requested byte is selected. `done` is high. |
| 9 | IDLE | idle | cleared | 0 | cleared | The flag drops. |

The miss flag is high for cycles 0 through 8. That is 9 enable cycles. `done` is high on cycle 8, which is the ninth step.

Miss time = 9 enable cycles.

\[
9 \times 2^{23} = 75{,}497{,}472 \text{ cycles of the 50 MHz clock.}
\]

That is 1.50994944 s on the board.

The seven names COMPARE, READ0, READ1, READ2, READ3, DONE, and RETURN are cycles 0, 2, 3, 4, 5, 6, and 8. Counting only those names gives 7 and leaves out the two cycles that are real registered handshakes: cycle 1, where the fetch unit accepts `fetch_req`, and cycle 7, where the controller accepts `fetch_done`. The simulation measured the flag at 9 enable cycles on all 525 miss pulses. The analyser, below, measured the same 9.

The memory-read burst is cycles 2 through 5, which is READ0, READ1, READ2, and READ3: 4 enable cycles = \(4 \times 2^{23} = 33{,}554{,}432\) cycles of the 50 MHz clock.

The miss penalty used in the AMAT formula is the extra cost of a miss over a hit. A hit takes the COMPARE and RETURN steps and skips the fill.

\[
9 - 2 = 7 \text{ enable cycles} = 7 \times 2^{23} = 58{,}720{,}256 \text{ cycles of the 50 MHz clock.}
\]

Using 9 as the penalty would count the hit's own two steps a second time. The address does not change either latency. Only the miss rate changes the average.

## AMAT

\[
\mathrm{AMAT} = \text{hit time} + \text{miss rate} \times \text{miss penalty}
= 2 + \frac{m}{n} \times 7
= \frac{2n + 7m}{n} \text{ enable cycles.}
\]

Multiply by \(2^{23}\) for cycles of the 50 MHz clock. Where \(n\) does not divide \(2n + 7m\), the average is a fraction of a cycle. That is the average over the accesses in the test. A single access is still either 2 steps or 9 steps.

| Test | Miss rate | AMAT (enable cycles) | AMAT (50 MHz cycles) |
|---|---|---|---|
| Temporal | 1/5 | 17/5 = 3.40 | 28,521,267.2 |
| Spatial | 2/8 = 1/4 | 15/4 = 3.75 | 31,457,280 |
| Reverse | 1/4 | 15/4 = 3.75 | 31,457,280 |
| Conflict | 2/4 = 1/2 | 11/2 = 5.50 | 46,137,344 |
| Capacity | 4/8 = 1/2 | 11/2 = 5.50 | 46,137,344 |
| Independence | 2/4 = 1/2 | 11/2 = 5.50 | 46,137,344 |
| Top of memory | 1/2 | 11/2 = 5.50 | 46,137,344 |
| LRU | 4/6 = 2/3 | 20/3 = 6.67 | 55,924,053.3 |
| One full pass | 17/41 | 201/41 = 4.90 | 41,124,639.2 |

Sorted by AMAT, the LRU test is the slowest in this suite, at \(20/3\) enable cycles. Four other tests share \(11/2\): conflict, capacity, independence, and top of memory. Spatial and reverse are \(15/4\). Temporal is the fastest, at \(17/5\).

Capacity is the row whose shape carries the interpretation. The trace is four misses and then four hits, and the AMAT stays 5.50. Nothing is thrown out. The four addresses are four different blocks and the cache has a place for each of them, two in each set. The second pass is entirely hits, which is why a 50% miss rate here means a cold working set that then fits, rather than a set that is thrashing.

Conflict is the row that changed with the organisation. `00` and `10` still share set 0. The direct-mapped cache has one line for that index, so each access throws the other out: 4/4 misses, miss rate 100%, AMAT = 2 + 1 × 7 = 9 enable cycles = \(9 \times 2^{23} = 75{,}497{,}472\) cycles of the 50 MHz clock, the full miss latency on every access. This cache has a second way, so the pair stays resident: 2/4 misses, miss rate 50%, AMAT 5.50. Conflict is no longer the worst test. The LRU test is, because it is the one that places three blocks into a set of two and therefore does replace a line.

| Test | Direct-mapped misses | Direct-mapped AMAT | Two-way misses | Two-way AMAT |
|---|---|---|---|---|
| Temporal | 1/5 | 3.40 | 1/5 | 3.40 |
| Spatial | 2/8 | 3.75 | 2/8 | 3.75 |
| Reverse | 1/4 | 3.75 | 1/4 | 3.75 |
| Capacity | 4/8 | 5.50 | 4/8 | 5.50 |
| Independence | 2/4 | 5.50 | 2/4 | 5.50 |
| Top of memory | 1/2 | 5.50 | 1/2 | 5.50 |
| Conflict | 4/4 | 9.00 | 2/4 | 5.50 |
| LRU sequence | 6/6 | 9.00 | 4/6 | 6.67 |

Under direct mapping, `00`, `10`, and `20` all have index 0, so the LRU sequence is six misses and its AMAT is 9 as well. The two-way cache cuts that sequence from 6/6 to 4/6 and the AMAT from 9 to 6.67, and it cuts the conflict pair from 9 to 5.50.

## What the analyser showed

Recording: `waves/set_assoc.sr`, also exported as `waves/set_assoc.csv`. Zeroplus LAP-C(16032), 100 Hz, threshold 1.5 V, 32,767 samples. The request pulse is the ruler for one cache step. Its median width is 17 samples. At 100 Hz that is 0.17 s, against \(2^{23}/50\,\mathrm{MHz} = 0.16777216\) s.

| Pulse | Median width | Width / 16.78 samples | Cache steps from the FSM |
|---|---|---|---|
| Request | 17 samples | 1.01 | 1, the request strobe |
| Hit | 33 samples | 1.97 | 2 |
| Memory read | 67 samples | 3.99 | 4 |
| Miss | 150 samples | 8.94 | 9 |

One enable cycle is 16.78 samples at 100 Hz, and the analyser stores whole samples, so the integer widths sit one sample off the exact multiples. Two steps would be 33.6 samples; the median hit is 33. Nine steps would be 151.0 samples; the median miss is 150. Four steps would be 67.1 samples; the median memory read is 67. In 50 MHz cycles the flag widths are the same 16,777,216 and 75,497,472 derived above. The analyser is reading those steps through the stretched enable.

The three phase bits named every group. After the first minute, 38 complete groups had pulses of the full width, every one of them matched the predicted shape, and none of them broke the read rule: a miss contained a memory read, a hit did not. That is four full loops of all eight tests. `waves/score.txt` is the listing. The verdict line is `PASS (4 full loops)`.

| Test | Shape on the wire | Misses / accesses | Predicted |
|---|---|---|---|
| Temporal | M H H H H | 1/5 | 1/5 |
| Spatial | M H H H M H H H | 2/8 | 2/8 |
| Conflict | M M H H | 2/4 | 2/4 |
| Capacity | M M M M H H H H | 4/8 | 4/8 |
| LRU | M M H M H M | 4/6 | 4/6 |
| Independence | M M H H | 2/4 | 2/4 |
| Reverse | M H H H | 1/4 | 1/4 |
| Top of memory | M H | 1/2 | 1/2 |

The opening of the file, up to about 55 s, is the tail of a pass that had already started, and during that stretch the miss clip chatters: the miss pin toggles every sample while request and the memory-read pin stay clean. Those groups were not scored. From the temporal test at 59.3 s onward the miss pin is a single pulse of about 150 samples, and it stays that way until the memory ends at 327.7 s. The chatter is a contact on F14 at the start of the record. The four later loops are the measurement.

PulseView screenshots, zoomed to the capture:

- `waves/pass.png` is one full pass, 59.0 s to 120.2 s, with all eight tests and the phase bits that name them.
- `waves/conflict.png` is `00 10 00 10`: two long miss pulses, each with a memory read, then two short hits, with no memory read. Phase 2.
- `waves/lru.png` is `00 10 00 20 00 10`: miss, miss, hit, miss, hit, miss. Phase 2 is high, which is phase 4. Each miss has a memory read. Each hit does not.

## Where the three checks meet

The address-map model, the register-transfer simulation, and the logic analyser were three separate readings of the same rule.

| Test | Predicted | Simulated | Analyser, on a clean loop |
|---|---|---|---|
| Temporal | 1/5 | 1/5 | 1/5 |
| Spatial | 2/8 | 2/8 | 2/8 |
| Conflict | 2/4 | 2/4 | 2/4 |
| Capacity | 4/8 | 4/8 | 4/8 |
| LRU | 4/6 | 4/6 | 4/6 |
| Independence | 2/4 | 2/4 | 2/4 |
| Reverse | 1/4 | 1/4 | 1/4 |
| Top of memory | 1/2 | 1/2 | 1/2 |

The cycle count travelled the same way. The state table says a hit flag lasts 2 enable cycles and a miss flag lasts 9. The simulator found that width on every one of 738 hits and 525 misses. The analyser found medians of 33 and 150 samples, which are those same 2 and 9 steps at 100 Hz. The miss penalty in the AMAT table is the difference, 7 enable cycles, equal to 58,720,256 cycles of the 50 MHz clock.
