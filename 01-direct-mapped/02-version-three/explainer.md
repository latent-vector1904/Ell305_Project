# Explainer: what the tests do, and what the waves show

Recording: `01-direct-mapped/02-version-three/waves/exam.sr`
Board: Shrike Lite. Analyzer: Zeroplus LAP-C 16032.
Sample rate: 500 Hz. Length: 65.5 seconds. The clear picture is the first 48 seconds.

## How to look at the screen

Four rows matter. High means that event is happening. Low means it is not.

| Row | Clip | What a high pulse is |
|---|---|---|
| A0 | F15 | A hit. The byte was already in the cache. About 0.33 seconds wide. |
| A1 | F14 | A miss. The line was not in the cache. About 1.5 seconds wide. |
| A2 | F17 | A memory read. The cache is copying 4 bytes in from main memory. This pulse sits inside a miss and nowhere else. |
| A3 | F18 | A request. The test has just asked for one address. About 0.17 seconds wide. A request comes before every hit and every miss. |

A hit and a miss are never high together. One request has one result.

The quiet gaps, where all four rows sit low, are the cache being wiped. The next test then starts from an empty cache.

Main memory has 256 bytes. The value stored at an address is the address itself, so a read of address `5` returns the byte `5`. The cache holds only 16 of those bytes: 4 lines, 4 bytes in each line. An address can live in only one line.

| Address bits | Name | What it decides |
|---|---|---|
| `[7:4]` | Tag | Which block this is. Saved next to the line. |
| `[3:2]` | Line | Slot 0, 1, 2, or 3. |
| `[1:0]` | Byte | Which of the 4 bytes inside the line was asked for. |

Addresses `0, 1, 2, 3` share line 0. Addresses `4, 5, 6, 7` share line 1. Address `0x10` uses line 0 again, but its tag is different, so it replaces whatever line 0 was holding.

On a miss the cache does not fetch one byte. It fetches the whole line of 4 bytes. That is why a neighbor can hit later without a new memory read.

The design runs the tests in a fixed order, wipes the cache, and runs the next one. This is that order on the recording.

## 1. Temporal locality — 0.3 s to 4.8 s

The test asks for address `0x00` five times.

The first time, line 0 is empty, so the read misses. The cache loads bytes `0, 1, 2, 3`. The byte returned is `0`. The next four reads ask for the same address. The line is still there, so each one hits, and memory is not read.

| Time | Wave | Why |
|---|---|---|
| 0.28 s | Miss, 1.50 s, with a memory read inside it | First read of `0x00`. The cache was empty. |
| 2.29 s | Hit, 0.33 s | Second read of `0x00`. |
| 3.12 s | Hit | Third read. |
| 3.96 s | Hit | Fourth read. |
| 4.79 s | Hit | Fifth read. |

The shape is one long miss, then four short hits. That is temporal locality: the same address was used again, and the cache still had it.

## 2. Spatial locality — 6.5 s to 14.7 s

The test asks for `0x00`, `0x01`, `0x02`, `0x03`, then `0x04`, `0x05`, `0x06`, `0x07`.

The miss on `0` loads bytes `0, 1, 2, 3` together. So `1`, `2`, and `3` hit even though each is a new address. Address `4` is the next line, which is still empty, so it misses and loads `4, 5, 6, 7`. Then `5`, `6`, and `7` hit.

| Time | Wave | Address | Why |
|---|---|---|---|
| 6.46 s | Miss | `0x00` | Line 0 was empty. Bytes `0` through `3` are loaded. |
| 8.47 s | Hit | `0x01` | Byte `1` arrived with that load. |
| 9.31 s | Hit | `0x02` | Byte `2` is in the same line. |
| 10.14 s | Hit | `0x03` | Byte `3` is in the same line. |
| 10.98 s | Miss | `0x04` | Line 1 is a different slot and is still empty. |
| 12.98 s | Hit | `0x05` | Byte `5` arrived with the miss on `4`. |
| 13.82 s | Hit | `0x06` | Same line. |
| 14.66 s | Hit | `0x07` | Same line. |

The shape is miss, hit, hit, hit, miss, hit, hit, hit. The hits are new addresses, not a repeat of the same one. They hit because a miss fetches the neighbors. That is spatial locality.

## 3. Conflict — 16.3 s to 22.4 s

The test asks for `0x00`, `0x10`, `0x00`, `0x10`.

Both addresses select line 0. `0x00` has tag 0. `0x10` has tag 1. The slot can hold only one of them. Each new request throws the previous line away, so the next request misses too.

| Time | Wave | Address | Why |
|---|---|---|---|
| 16.33 s | Miss | `0x00` | Fills line 0 with tag 0. |
| 18.33 s | Miss | `0x10` | Same slot, different tag. Replaces the line. |
| 20.34 s | Miss | `0x00` | Tag 0 was just overwritten, so address `0` is gone. |
| 22.35 s | Miss | `0x10` | Replacing it again throws `0x10` out too. |

The shape is four long misses and no hits. Every miss has its own memory read. A conflict is the rule that one slot holds one line.

## 4. Capacity — 25.2 s to 35.7 s

The test asks for `0x00`, `0x04`, `0x08`, `0x0C`, then those same four addresses again.

Those four addresses are lines 0, 1, 2, and 3. No two of them share a slot. The first pass fills every line. The second pass finds all four still valid.

| Time | Wave | Address | Why |
|---|---|---|---|
| 25.19 s | Miss | `0x00` | Line 0 is empty. |
| 27.20 s | Miss | `0x04` | Line 1 is empty. Line 0 is left alone. |
| 29.20 s | Miss | `0x08` | Line 2 is empty. |
| 31.21 s | Miss | `0x0C` | Line 3 is empty. The cache is now full: 16 bytes. |
| 33.21 s | Hit | `0x00` | Line 0 was not replaced. |
| 34.05 s | Hit | `0x04` | Line 1 still holds it. |
| 34.89 s | Hit | `0x08` | Line 2 still holds it. |
| 35.72 s | Hit | `0x0C` | Line 3 still holds it. |

The shape is four misses, then four hits. All four lines were full at once, and every one of them hit. In the conflict test, two addresses wanted the same line and nothing survived. Here, four addresses wanted four different lines and all four survived.

## 5. Replacement — 37.4 s to 43.7 s

The test asks for `0x00`, then `0x00` again, then `0x10`, then `0x00` again.

The second `0x00` hits, which shows the line was stored. `0x10` uses that same slot with a different tag, so it overwrites the bytes of address `0`. The last `0x00` therefore misses. The earlier hit did not protect it.

| Time | Wave | Address | Why |
|---|---|---|---|
| 37.39 s | Miss, with a memory read | `0x00` | Line 0 is loaded. |
| 39.40 s | Hit, no memory read | `0x00` | The line is still there. |
| 40.2 s | Miss, with a memory read | `0x10` | Same slot, new tag. The old line is overwritten. |
| 42.24 s | Miss, with a memory read | `0x00` | Address `0` has to be loaded again. |

The shape is miss, hit, miss, miss. The last miss is the proof of replacement. Around 40.6 s the miss row dips for a moment and comes back. The memory-read row stays high across that dip, so it is still the one fill of `0x10`.

## 6. What the rest of the recording is

At 45.1 s and 47.1 s there are two more clean misses, each with a memory read. That is the start of the independence test: `0x00` misses into line 0, then `0x04` misses into line 1. Those two lines are different slots, so filling one must not destroy the other, and the test then hits both addresses. On this capture the rows break up after 48 s, so those two hits are not a clean pair of pulses. Use the first 48 seconds, through the replacement test, as the picture to explain.

Two shorter tests are in the same loop, after independence. This 65-second file does not reach a clean copy of them:

- Reverse line. Request `0x03`, then `0x02`, `0x01`, `0x00`. The miss is on the last byte of the line, but the load still brings `0, 1, 2, 3`, so the walk backward hits. The shape is one miss and three hits.
- Top of memory. Request `0xFC`, then `0xFF`. `0xFF` is address 255, the last byte. It sits in the line that starts at `0xFC`. The miss loads `0xFC` through `0xFF`, and `0xFF` hits. The byte returned is `255`. The shape is one miss and one hit.

## One sentence for each shape

| If you see this | Say this |
|---|---|
| One long miss, four short hits | The same address was reused. Temporal locality. |
| Miss, three hits, miss, three hits | Neighbors were loaded with the missed byte. Spatial locality. |
| Four long misses and no hits | Two addresses fought over one slot. Conflict. |
| Four misses, then four hits | All four lines were filled, and all four were still there. Capacity. |
| Miss, hit, miss, miss | A new tag replaced the line, so the old address missed again. Replacement. |
| A memory-read pulse | It is inside a miss, because that is the only time the cache copies a line in. |
| A hit with the memory row low | The byte was already in the cache. |
