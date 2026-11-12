# Two-way set-associative cache

Same 16 bytes as the direct-mapped cache on the Shrike Lite: 2 sets, 2 ways, 4 bytes in a line. The fill machine and the header pins are the same. Only the placement rule changes.

Address split:

| Bits | Field | Meaning |
|---|---|---|
| `[7:3]` | tag | which block |
| `[2]` | index | which set, 0 or 1 |
| `[1:0]` | offset | which byte in the line |

An empty way is filled first. When both ways of a set are full, the least recently used way is replaced.

## Check before the board

```bash
./run_sim.sh
```

The run passes only when every returned byte equals the address, every hit flag lasts 2 enable cycles, every miss flag lasts 9, and each miss produces one memory-read pulse. `test_preview.txt` is the predicted miss count and AMAT for each test. AMAT = 2 + miss rate × 7 enable cycles. One enable cycle on the board is 2^23 clocks of the 50 MHz oscillator.

## Clips

Leave the four clips where they were for the direct-mapped capture.

| Board label | Signal |
|---|---|
| FPGA_IO15 (F15) | hit |
| FPGA_IO14 (F14) | miss |
| FPGA_IO17 (F17) | memory read |
| FPGA_IO18 (F18) | request |

Optional, so the trace names the test: FPGA_IO10 (F10), FPGA_IO11 (F11), FPGA_IO8 (F8). Those are the three phase bits.

## Bitstream

`ffpga/build/bitstream/FPGA_bitstream_MCU.bin` is already built. Flash that file. `./build_test.sh` rebuilds it if the address list changes; the tools refuse a project path that contains a space, so the script builds in `~/set_assoc_build` and copies the image back.

Place and route (`ffpga/build/PNR_TIMING.log`) gives an achievable clock of 86.595 MHz, period 11548 ps. The board oscillator is 50 MHz, so the design meets that clock. The resource report uses 131 logic LUTs and 83 logic flip-flops, plus 9 output flip-flops. Do not flash this image over the direct-mapped one until that capture is finished.

## What the analyser should show

The conflict test `00 10 00 10` is miss, miss, hit, hit. On the direct-mapped cache the same four addresses are four misses. The LRU test `00 10 00 20 00 10` is miss, miss, hit, miss, hit, miss: `20` replaces `10`, and `00` is still there.
