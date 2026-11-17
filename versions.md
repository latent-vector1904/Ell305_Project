# How the three versions differ

The cache itself does not change. All three versions use the same small cache on the Shrike Lite:

- Main memory is 256 bytes. The byte stored at an address is the address itself, so a read of `5` returns `5`.
- The cache holds 16 bytes: 4 lines, 4 bytes in each line.
- An address fits in only one line. Bits `[3:2]` pick the line, bits `[1:0]` pick the byte inside it, and bits `[7:4]` are the tag that says which block is stored there.
- A miss loads the whole line of 4 bytes. A hit does not touch memory.
- The analyzer clips stay on the same pins: **F15** hit, **F14** miss, **F17** memory read, **F18** request.

What changes is the list of addresses the design asks for. Each later version keeps the earlier tests and adds harder ones. The cache is wiped between passes so every test starts empty.

| | First version (`untitled`) | Version two | Version three |
|---|---|---|---|
| Folder | `01-direct-mapped/04-first-image` | `01-direct-mapped/03-version-two` | `01-direct-mapped/02-version-three` |
| How many tests | 1 | 2 | 8 |
| What it asks | Address `0x00`, over and over | Same address, then addresses `0` through `7` | Those two, plus conflict, a full cache, replacement, separate lines, a backward line, and the last byte in memory |
| What a pass looks like | One miss, then hits | Miss and four hits, then miss, three hits, miss, three hits | Five different shapes in the first 48 seconds of the recording |
| Question it can answer | Was this address used again? | Were the neighboring bytes loaded too? | Also: did two addresses fight, did all four lines fit, did a new tag destroy the old line? |

## First version — only the same address

Folder: `01-direct-mapped/04-first-image`.
Recording from that board run: `01-direct-mapped/04-first-image/ffpga/build/bitstream/cache_la.sr`.

The only request is address `0x00`. The cache is empty, so the first read misses and loads bytes `0, 1, 2, 3`. The next reads of `0x00` hit, because it is the same address and the line is still there. Then the cache is wiped and the same thing happens again, about every 5 seconds.

On the wave that is one long miss, with memory reads inside it, then short hits, then a quiet gap.

This shows temporal locality and nothing else. It never asks for address `1` or `4` or `0x10`, so it cannot show neighbors, a full cache, or a line being replaced. On that recording the pass showed one miss and two hit pulses. The later versions make the repeat count obvious: one miss and four hits.

## Version two — same address, then the neighbors

Folder: `01-direct-mapped/03-version-two`.
Recording: `01-direct-mapped/03-version-two/waves/locality.sr`.
Write-up: `01-direct-mapped/03-version-two/test_cases.md`.

Two tests take turns. The cache is cleared between them.

1. Temporal. Address `0x00` five times. One miss, then four hits. Same idea as the first version, with the four repeats easy to count.
2. Spatial. Addresses `0x00`, `0x01`, `0x02`, `0x03`, `0x04`, `0x05`, `0x06`, `0x07`. The miss on `0` loads bytes `0` through `3`, so `1`, `2`, and `3` hit. Address `4` is the next line, so it misses, and `5`, `6`, and `7` hit.

On the wave, a temporal pass is one long miss and four short hits. A spatial pass is miss, three hits, miss, three hits. They are easy to tell apart because the spatial pass has a second miss in the middle.

Version two still cannot show a fight over one slot. Every address it uses is either a repeat of `0` or the next byte in order. Nothing in that list has a different tag for the same line.

## Version three — the full set of questions

Folder: `01-direct-mapped/02-version-three`.
Recording: `01-direct-mapped/02-version-three/waves/exam.sr`.
Write-up of each pulse: `01-direct-mapped/02-version-three/explainer.md`.

The cache is still the same 16 bytes. The exam adds every result this cache can actually produce. A simulation checked the address, the hit or miss, and the returned byte on 1,078 accesses. The recording’s clear picture is the first 48 seconds.

| Order | Test | Addresses | Shape on the analyzer | What it adds |
|---|---|---|---|---|
| 1 | Temporal | `0x00` five times | One miss, four hits. Starts at 0.3 s. | Same as version two’s first test. |
| 2 | Spatial | `0x00` through `0x07` | Miss, three hits, miss, three hits. Starts at 6.5 s. | Same as version two’s second test. |
| 3 | Conflict | `0x00`, `0x10`, `0x00`, `0x10` | Four misses, no hits. Starts at 16.3 s. | Both addresses want line 0 and have different tags, so each one throws the other out. |
| 4 | Capacity | `0x00`, `0x04`, `0x08`, `0x0C`, then those four again | Four misses, then four hits. Starts at 25.2 s. | One address in each line. All four lines stay full. |
| 5 | Replacement | `0x00`, `0x00`, `0x10`, `0x00` | Miss, hit, miss, miss. Starts at 37.4 s. | `0x10` overwrites `0x00`, so `0x00` misses again. |
| 6 | Independence | `0x00`, `0x04`, `0x00`, `0x04` | Two misses, then two hits | Filling line 1 does not destroy line 0. The recording shows the two misses at 45 s and 47 s. The two hits after them are not a clean pair on this file. |
| 7 | Reverse line | `0x03`, `0x02`, `0x01`, `0x00` | One miss, three hits | The miss is on the last byte of the line. The load still brings `0, 1, 2, 3`, so the walk backward hits. |
| 8 | Top of memory | `0xFC`, then `0xFF` | One miss, one hit | `0xFF` is address 255. It sits in the line that starts at `0xFC`. |

Tests 7 and 8 are in the loop, but this 65-second file does not reach a clean copy of them. The explainer in the version three folder describes the shape they make.

## What you can say about the three

The first version asks one question: if I read the same address again, does the cache hit? The wave is one miss and then hits.

Version two asks a second question: if I then read the next bytes, were they loaded with the first one? A second miss appears in the middle of that pass, because address `4` is a new line.

Version three asks the questions that need addresses which are not neighbors. `0x00` and `0x10` share a slot and the wave is four misses. `0x00`, `0x04`, `0x08`, and `0x0C` fill all four slots and the wave is four misses followed by four hits. After `0x00` has hit, `0x10` replaces it and `0x00` misses again.

The blue power LED is on in all three versions for the same reason. It is wired to 3.3 V. None of these bitstreams use it as a hit light.
