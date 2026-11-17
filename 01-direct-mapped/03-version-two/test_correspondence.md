# Version two: locality tests and what the analyzer showed

Bitstream: `01-direct-mapped/03-version-two/ffpga/build/bitstream/FPGA_bitstream_MCU.bin`
Capture: `01-direct-mapped/03-version-two/waves/locality.sr` (1 kHz, 1.5 V, 32.8 s, 6 Nov 2026 12:45)

Clips were left where they were. This bitstream uses the same pins:

| Analyzer | Board label | Signal |
|---|---|---|
| A0 | F15 | cache hit |
| A1 | F14 | cache miss |
| A2 | F17 | mem_read |
| A3 | F18 | request |

`temporal` (high during the temporal test, low during the spatial test) is on **F10**. It was not clipped.

The cache line is 4 bytes. A miss loads the whole line. The design runs the temporal test, clears the cache, runs the spatial test, clears the cache, and repeats. Each slow step is about 0.17 s. A hit pulse is about 0.33 s. A miss pulse is about 1.5 s, with one `mem_read` burst inside it.

## Temporal locality

Test: read address `0x00` five times. The first read must miss and fill the line. The next four read the same address, so they must hit, and memory must stay idle.

| Time | Expected | Observed |
|---|---|---|
| 8.24 s | One miss, with a memory read | A1 high for 1.50 s. A2 high once inside that pulse (0.67 s). A0 low |
| 10.25 s | Hit on `0x00` | A0 high 0.33 s. A1 and A2 low |
| 11.09 s | Hit on `0x00` | A0 high 0.33 s. A1 and A2 low |
| 11.92 s | Hit on `0x00` | A0 high 0.33 s. A1 and A2 low |
| 12.76 s | Hit on `0x00` | A0 high 0.33 s. A1 and A2 low |

That is one miss and four hits, and memory is touched only on the miss. The same shape starts again at 24.63 s (miss) and 26.63, 27.47, 28.30, 29.14 s (four hits).

## Spatial locality

Test: read `0x00`, `0x01`, `0x02`, `0x03`, then `0x04`, `0x05`, `0x06`, `0x07`. `0x00` misses and loads bytes 0–3, so `0x01`–`0x03` hit with no memory read. `0x04` is the next line, so it misses and loads bytes 4–7, and `0x05`–`0x07` hit.

| Time | Expected | Observed |
|---|---|---|
| 14.60 s | Miss on `0x00`, memory read | A1 high 1.50 s, one A2 burst, A0 low |
| 16.60 s | Hit on `0x01` | A0 high 0.33 s, no memory read |
| 17.44 s | Hit on `0x02` | A0 high 0.33 s, no memory read |
| 18.27 s | Hit on `0x03` | A0 high 0.33 s, no memory read |
| 19.11 s | Miss on `0x04`, memory read | A1 high 1.50 s, one A2 burst |
| 21.12 s | Hit on `0x05` | A0 high 0.33 s, no memory read |
| 21.95 s | Hit on `0x06` | A0 high 0.33 s, no memory read |
| 22.79 s | Hit on `0x07` | A0 high 0.33 s, no memory read |

Neighboring bytes hit after one fill. A new line misses again. That is spatial locality.

## How to tell the two tests apart on the screen

A temporal pass is one long miss, then four hit pulses, then a quiet gap.

A spatial pass is one long miss, three hit pulses, another long miss, three hit pulses, then a quiet gap.

The first few seconds are the end of a pass that was already running while the FPGA was being programmed. The clean passes are the ones listed above.
