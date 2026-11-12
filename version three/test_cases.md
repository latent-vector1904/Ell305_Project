# Version three — every test this cache can answer

This cache is small on purpose, so each kind of result can be seen on its own.

Main memory holds 256 bytes. The byte at an address is the address itself: address `5` stores `5`. The cache holds 16 bytes, arranged as 4 lines of 4 bytes. A line is loaded all at once. Each address is allowed in only one line:

| Address bits | Name | Meaning |
|---|---|---|
| `[7:4]` | Tag | Which block this is. Stored next to the line. |
| `[3:2]` | Line | Slot 0, 1, 2, or 3. |
| `[1:0]` | Byte | Which of the 4 bytes inside the line was asked for. |

Addresses `0, 1, 2, 3` share line 0. Addresses `4, 5, 6, 7` share line 1. Address `0x10` (16) uses line 0 again, but its tag is different, so it kicks out whatever line 0 was holding.

A hit means the slot is valid and the tag matches. Memory is not read. A miss means the slot is empty or holds a different tag. The cache reads 4 bytes from memory, stores them, and the old line in that slot is gone.

The board repeats eight tests. The cache is cleared between tests. The clips are the same as before: **F15** hit, **F14** miss, **F17** memory read, **F18** request. A miss is the long pulse, about 1.5 s, with one memory-read burst inside it. A hit is the short pulse, about 0.33 s, with no memory read.

The test number is also driven to the header, if a later clip is added: F10 is bit 0, F11 is bit 1, F8 is bit 2.

## What a person can ask, and which test answers it

| Question | Test | What must be true |
|---|---|---|
| Does an empty cache miss? | All of them, first access | First pulse of every test is a miss, and memory is read. |
| If I ask for the same address again, do I hit? | 1, temporal | One miss, then four hits, no more memory reads. |
| If I ask for the next bytes, were they loaded too? | 2, spatial | Miss on `0`, then hits on `1`, `2`, `3` with no memory read. Same again for `4` then `5`, `6`, `7`. |
| Does the order inside the line matter? | 7, reverse | Miss on `3` loads `0, 1, 2, 3`. Then `2`, `1`, and `0` hit. |
| What if two addresses want the same slot? | 3, conflict | `0x00` and `0x10` both want line 0. Every access misses. |
| After a replacement, is the old block gone? | 5, replacement | `0x00` hits, then `0x10` replaces it, then `0x00` misses again. |
| Can all four lines be full at once? | 4, capacity | Four misses, one per line, then those same four addresses hit. |
| Does filling one line destroy another line? | 6, independence | After misses on `0x00` and `0x04`, both hit. Line 1 did not evict line 0. |
| Does the top of memory work the same way? | 8, top | `0xFC` misses and loads `0xFC` through `0xFF`. `0xFF` hits. |
| Does a hit ever read memory? | Every hit in every test | The memory-read row stays low for the whole hit pulse. |
| Does a miss always read memory? | Every miss | One memory-read burst sits inside the miss. |
| Can one lookup be both a hit and a miss? | Every access | The two rows are never high together. |
| Is the byte that comes back the right one? | Checked in simulation, not on the analyzer | The returned byte equals the address. The analyzer clips do not carry the data pins. |

These cannot be asked of this design, because the hardware does not have them:

- A write. The test only reads. There is no write-through or write-back policy to observe.
- A choice of which line to replace. It is direct-mapped, so the address picks the only slot.
- Two ways to store the same line. There is one slot per index, not a set of two or four.
- A second level of cache.
- The data byte on the logic analyzer. Hit, miss, request, and memory read are the signals that were brought out.

## Test 1 — temporal locality

Request `0x00` five times. The cache starts empty.

| Step | Address | Result | Why |
|---|---|---|---|
| 1 | `0x00` | Miss | Line 0 is empty. Bytes `0, 1, 2, 3` are loaded. |
| 2 | `0x00` | Hit | The same address is still in line 0. |
| 3 | `0x00` | Hit | Same address. |
| 4 | `0x00` | Hit | Same address. |
| 5 | `0x00` | Hit | Same address. |

Waveform shape: one long miss, then four short hits.

## Test 2 — spatial locality

Request `0x00` through `0x07`.

| Step | Address | Result | Why |
|---|---|---|---|
| 1 | `0x00` | Miss | Loads bytes `0, 1, 2, 3`. |
| 2 | `0x01` | Hit | Byte `1` came in with that load. |
| 3 | `0x02` | Hit | Byte `2` is in the same line. |
| 4 | `0x03` | Hit | Byte `3` is in the same line. |
| 5 | `0x04` | Miss | Line 1 is still empty. Loads bytes `4, 5, 6, 7`. |
| 6 | `0x05` | Hit | Byte `5` came in with that load. |
| 7 | `0x06` | Hit | Same line. |
| 8 | `0x07` | Hit | Same line. |

Waveform shape: miss, hit, hit, hit, miss, hit, hit, hit.

## Test 3 — conflict

`0x00` and `0x10` both select line 0. Their tags differ (`0` and `1`).

| Step | Address | Result | Why |
|---|---|---|---|
| 1 | `0x00` | Miss | Fills line 0 with tag 0. |
| 2 | `0x10` | Miss | Same slot, different tag. Replaces the line. |
| 3 | `0x00` | Miss | The line now holds tag 1, so address `0` is gone. |
| 4 | `0x10` | Miss | Replacing it again throws `0x10` out too. |

Waveform shape: four long misses, no hits. Each miss has its own memory read.

## Test 4 — capacity

One address in each slot: `0x00`, `0x04`, `0x08`, `0x0C`. Those are lines 0, 1, 2, and 3. Then the same four addresses again.

| Step | Address | Result | Why |
|---|---|---|---|
| 1–4 | `0x00`, `0x04`, `0x08`, `0x0C` | Miss, miss, miss, miss | Each one fills a different empty line. |
| 5–8 | the same four | Hit, hit, hit, hit | All four lines are still valid. Nothing was evicted, because no two addresses shared a slot. |

Waveform shape: four misses, then four hits.

## Test 5 — replacement

| Step | Address | Result | Why |
|---|---|---|---|
| 1 | `0x00` | Miss | Line 0 loaded. |
| 2 | `0x00` | Hit | It is still there. |
| 3 | `0x10` | Miss | Same slot, new tag. The bytes of address `0` are overwritten. |
| 4 | `0x00` | Miss | Proof that step 3 destroyed the earlier line. |

Waveform shape: miss, hit, miss, miss.

## Test 6 — lines do not disturb each other

| Step | Address | Result | Why |
|---|---|---|---|
| 1 | `0x00` | Miss | Fills line 0. |
| 2 | `0x04` | Miss | Fills line 1. Line 0 is a different slot, so it stays. |
| 3 | `0x00` | Hit | Line 0 was not replaced. |
| 4 | `0x04` | Hit | Line 1 is still there too. |

Waveform shape: miss, miss, hit, hit.

This is the opposite of test 5. `0x04` is a different line from `0x00`. `0x10` is the same line as `0x00`.

## Test 7 — the line works backward

| Step | Address | Result | Why |
|---|---|---|---|
| 1 | `0x03` | Miss | Byte 3 is the last byte of line 0, but the load still brings `0, 1, 2, 3`. |
| 2 | `0x02` | Hit | Already in the line. |
| 3 | `0x01` | Hit | Already in the line. |
| 4 | `0x00` | Hit | Already in the line. |

Waveform shape: one miss, then three hits. The first request was the end of the line, not the start. The neighbors still hit.

## Test 8 — the last bytes in memory

`0xFF` is address 255, the last byte. It belongs to the line that starts at `0xFC`.

| Step | Address | Result | Why |
|---|---|---|---|
| 1 | `0xFC` | Miss | Loads `0xFC`, `0xFD`, `0xFE`, `0xFF`. |
| 2 | `0xFF` | Hit | The last byte arrived with that load. The value returned is `0xFF`. |

Waveform shape: one miss, then one hit.

## How to read one pass on the analyzer

The suite order is fixed: temporal, spatial, conflict, capacity, replacement, independence, reverse, top of memory. Then the cache is cleared and the suite starts again.

| Shape you see | Test |
|---|---|
| Miss, then four hits | Temporal |
| Miss, three hits, miss, three hits | Spatial |
| Four misses and no hits | Conflict |
| Four misses, then four hits | Capacity |
| Miss, hit, miss, miss | Replacement |
| Miss, miss, hit, hit | Independence |
| Miss, then three hits | Reverse line |
| Miss, then one hit | Top of memory |

A quiet stretch with no hit and no miss is the cache being cleared before the next test.
