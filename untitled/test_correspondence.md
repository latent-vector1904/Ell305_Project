# Cache simulator: tests and observations

Board: Shrike Lite. Analyzer: Zeroplus LAP-C 16032, recorded in PulseView.
Capture: `fpga/untitled/ffpga/build/bitstream/cache_la.sr`
Sample rate: 1 kHz. Threshold: 1.5 V. Length: 32.8 s. Taken 6 Nov 2026, 12:30.

The bitstream that produced the waves runs one test only: always read address `0x00`. After four lookups it clears the cache and starts again, so the same pass repeats about every 5 s. The other address patterns (sequential, conflict, four cold misses) were not run on the board.

Clips were left on the pins from the earlier hookup. This bitstream drives these signals on those pins:

| Analyzer | Board label | Signal |
|---|---|---|
| A0 | F15 | cache hit |
| A1 | F14 | cache miss |
| A2 | F17 | mem_read |
| A3 | F18 | request |
| GND | GND just before F17 | ground |

High means the event is true. Hit and miss are never high at the same time. `mem_read` rises only while miss is high.

## Prior run: bitstream with no clock

| Item | Test | Observation |
|---|---|---|
| Bitstream | First file generated in `untitled`, IO Planner had no CLK and no OSC Enable | Flashed. Board reported “FPGA programming done.” |
| A0–A3, same four pins | Expect toggling if the cache ran | All four channels stayed low for the whole 32.8 s. No edges. |
| Conclusion | Oscillator was not connected, so the design never stepped | Probes were making contact. The pins were driven low, not floating. |

## This run: clock connected, address `0x00` repeating

Each slow step is about 0.17 s (the on-chip enable is once every 2^23 cycles of the 50 MHz oscillator). The first ~8 s of the file are low because the capture was started while the FPGA was still being programmed. The table below is one pass after that, from about 8.0 s to 13.0 s. The same shape repeats at about 13.0 s, 18 s, and so on.

| Time on the capture | Test step | Expected | Observed |
|---|---|---|---|
| 8.00 s | Lookup starts | One short request pulse | A3 high for about 0.17 s |
| 8.2 s to 9.7 s | First lookup of `0x00`, cache empty | Miss, and a memory fill of the 4-byte line. Hit stays low | A1 high for about 1.5 s. A0 stays low. A2 pulses twice inside that miss (about 8.4–9.1 s and 9.4–10.1 s) |
| 10.2 s to 10.5 s | Same address, line now cached | Hit. No memory read | A0 high for about 0.33 s. A1 and A2 stay low |
| 10.7 s | Next lookup starts | Request pulse | A3 high for about 0.17 s |
| 11.1 s to 11.4 s | Same address again | Another hit | A0 high for about 0.33 s. A2 stays low |
| 11.6 s and 12.7 s | Further requests in the same pass | Request pulses, then the pass ends and the cache is cleared | A3 pulses. No hit or miss on those last pulses |
| 13.05 s | Next pass, cache was cleared | Miss on `0x00` again | A1 rises and the same miss-then-hits shape repeats |

## What matches

| Check | Result |
|---|---|
| A miss is followed by memory reads | Yes. Both `mem_read` bursts sit inside the miss pulse. |
| A hit does not touch memory | Yes. A2 is low for both hit pulses. |
| Hit and miss are exclusive | Yes. They are never high together. |
| A request leads each lookup | Yes. A3 pulses before the miss and before each hit. |
| The pass repeats after the cache is cleared | Yes. The next miss starts about 5 s after the previous one. |
| Pulse widths match the slow step | Request ≈ 0.17 s (one step). Hit ≈ 0.33 s (two steps). Miss ≈ 1.5 s (the compare plus the line fill). |

## What does not match the written test

The address-`0x00` test is four lookups: one cold miss, then three hits. The recording shows one miss and two hit pulses per pass, plus two extra request pulses near the end that have no hit and no miss. The hit/miss decision on the pulses that do appear is consistent. The missing third hit is not explained by this capture.
