# LRU cache data

Board: Shrike Lite, 50 MHz oscillator. Analyzer: Zeroplus LAP-C 16032. Recording: `lru/waves/lru_cycles.csv`, 100 Hz, 1.5 V threshold, 32,767 samples, 327.67 s.

One cache step = \(2^{23} = 8{,}388{,}608\) cycles of the 50 MHz clock = 0.16777216 s. The analyzer stores that step as 17 samples.

## Latency

Measured from the cycle that enters COMPARE until the cycle `done` is high.

| Quantity | Cache steps | 50 MHz cycles | Time on the board |
|---|---|---|---|
| Hit time | 2 | 16,777,216 | 0.33554432 s |
| Miss time | 9 | 75,497,472 | 1.50994944 s |
| Miss penalty (miss time − hit time) | 7 | 58,720,256 | 1.17440512 s |
| Memory-read burst (READ0–READ3) | 4 | 33,554,432 | 0.67108864 s |

Miss path, one row per cache step:

| Step | Cache state | Fetch state | Memory read | Done |
|---|---|---|---|---|
| 0 | COMPARE | idle | 0 | 0 |
| 1 | FETCH | idle | 0 | 0 |
| 2 | FETCH | READ0 | 1 | 0 |
| 3 | FETCH | READ1 | 1 | 0 |
| 4 | FETCH | READ2 | 1 | 0 |
| 5 | FETCH | READ3 | 1 | 0 |
| 6 | FETCH | DONE | 0 | 0 |
| 7 | FETCH | idle | 0 | 0 |
| 8 | RETURN | idle | 0 | 0 |
| 9 | IDLE | idle | 0 | 1 |

Hit path: step 0 COMPARE, step 1 RETURN, step 2 IDLE with `done` high.

AMAT = hit time + miss rate × miss penalty = \(2 + (m/n) \times 7\) cache steps.

## Predicted against measured miss counts

The prediction is the replacement rule, scored before the Verilog count. The RTL column is `lru/tb_latency.v`. The analyzer column is every complete group in the recording. All three agree.

| Test | Accesses | Predicted misses | RTL misses | Analyzer misses | Miss rate |
|---|---|---|---|---|---|
| Temporal | 5 | 1 | 1 | 1 | 1/5 = 20% |
| Spatial | 8 | 2 | 2 | 2 | 2/8 = 25% |
| Conflict | 4 | 2 | 2 | 2 | 2/4 = 50% |
| Capacity | 8 | 4 | 4 | 4 | 4/8 = 50% |
| Replacement | 4 | 2 | 2 | 2 | 2/4 = 50% |
| Independence | 4 | 2 | 2 | 2 | 2/4 = 50% |
| Reverse | 4 | 1 | 1 | 1 | 1/4 = 25% |
| Top | 2 | 1 | 1 | 1 | 1/2 = 50% |
| Victim `0x00` | 13 | 6 | 6 | 6 | 6/13 = 46.2% |
| Victim `0x04` | 13 | 6 | 6 | 6 | 6/13 = 46.2% |
| Victim `0x08` | 13 | 6 | 6 | 6 | 6/13 = 46.2% |
| Victim `0x0C` | 13 | 6 | 6 | 6 | 6/13 = 46.2% |
| Suite total | 91 | 39 | 39 | 39 | 39/91 = 42.9% |

Direct-mapped prediction for the same eight address lists. Victim tests are not the same experiment under direct mapping.

| Test | Direct-mapped misses | LRU misses |
|---|---|---|
| Temporal | 1/5 | 1/5 |
| Spatial | 2/8 | 2/8 |
| Conflict | 4/4 | 2/4 |
| Capacity | 4/8 | 4/8 |
| Replacement | 3/4 | 2/4 |
| Independence | 2/4 | 2/4 |
| Reverse | 1/4 | 1/4 |
| Top | 1/2 | 1/2 |

Shapes on the analyzer. M is a miss, H is a hit.

| Test | Phase | Shape |
|---|---|---|
| Temporal | 0 | MHHHH |
| Spatial | 1 | MHHHMHHH |
| Conflict | 2 | MMHH |
| Capacity | 3 | MMMMHHHH |
| Replacement | 4 | MHMH |
| Independence | 5 | MMHH |
| Reverse | 6 | MHHH |
| Top | 7 | MH |
| Victim `0x00` | 0, after phase 7 | MMMMHHHMHHHHM |
| Victim `0x04` | 1, after phase 7 | MMMMHHHMHHHHM |
| Victim `0x08` | 2, after phase 7 | MMMMHHHMHHHHM |
| Victim `0x0C` | 3, after phase 7 | MMMMHHHMHHHHM |

## AMAT

| Test | Miss rate | AMAT (cache steps) | AMAT (50 MHz cycles) |
|---|---|---|---|
| Temporal | 1/5 | 17/5 = 3.40 | 28,521,267.2 |
| Spatial | 2/8 | 15/4 = 3.75 | 31,457,280 |
| Reverse | 1/4 | 15/4 = 3.75 | 31,457,280 |
| Each victim | 6/13 | 68/13 = 5.231 | 43,878,872.6 |
| Conflict | 2/4 | 11/2 = 5.50 | 46,137,344 |
| Capacity | 4/8 | 11/2 = 5.50 | 46,137,344 |
| Replacement | 2/4 | 11/2 = 5.50 | 46,137,344 |
| Independence | 2/4 | 11/2 = 5.50 | 46,137,344 |
| Top | 1/2 | 11/2 = 5.50 | 46,137,344 |
| 1,498-access sweep | 422/1498 | 2975/749 = 3.972 | 33,319,237.4 |

| Test | Direct-mapped miss rate | Direct-mapped AMAT | LRU miss rate | LRU AMAT |
|---|---|---|---|---|
| Temporal | 1/5 | 3.40 | 1/5 | 3.40 |
| Spatial | 2/8 | 3.75 | 2/8 | 3.75 |
| Reverse | 1/4 | 3.75 | 1/4 | 3.75 |
| Capacity | 4/8 | 5.50 | 4/8 | 5.50 |
| Independence | 2/4 | 5.50 | 2/4 | 5.50 |
| Top | 1/2 | 5.50 | 1/2 | 5.50 |
| Replacement | 3/4 | 7.25 | 2/4 | 5.50 |
| Conflict | 4/4 | 9.00 | 2/4 | 5.50 |

The sweep is 1,498 accesses, 1,076 hits, 422 misses. Every miss read memory. No hit did.

## Analyzer pulse widths

| Pulse | Median width | Width / 17 samples | FSM steps |
|---|---|---|---|
| Request | 17 | 1.00 | 1 |
| Hit | 33 | 1.94 | 2 |
| Memory read | 67 | 3.94 | 4 |
| Miss | 150 | 8.82 | 9 |

Complete labeled tests in that one record:

| Test | Complete copies | Misses / accesses |
|---|---|---|
| Temporal | 3 | 1/5 |
| Spatial | 3 | 2/8 |
| Conflict | 3 | 2/4 |
| Capacity | 3 | 4/8 |
| Replacement | 3 | 2/4 |
| Independence | 2 | 2/4 |
| Reverse | 2 | 1/4 |
| Top | 2 | 1/2 |
| Victim `0x00` | 2 | 6/13 |
| Victim `0x04` | 2 | 6/13 |
| Victim `0x08` | 2 | 6/13 |
| Victim `0x0C` | 3 | 6/13 |

## Clips

| Signal | Header | Pin | Channel |
|---|---|---|---|
| Hit | F15 | PIN_6 | A0 |
| Miss | F14 | PIN_5 | A1 |
| Memory read | F17 | PIN_8 | A2 |
| Request | F18 | PIN_9 | A3 |
| Phase bit 0 | F10 | PIN_1 | A4 |
| Phase bit 1 | F11 | PIN_2 | A5 |
| Phase bit 2 | F8 | PIN_23 | A6 |
