# What this cache test is doing

This note is for someone who has not studied caches. Every word that matters is defined before it is used. The two tests are at the end. Under each one there is a blank place to paste the waveform and a place to write your own explainer.

## The two places data can live

There is a main memory and a cache.

Main memory is the full list of bytes. In this design it has 256 bytes, because an address is 8 bits and 2^8 = 256. An address is just the number of a byte. Address `0` is the first byte, address `1` is the next byte, and so on up to address `255`.

The cache is a small copy of a few of those bytes, kept where the lookup is fast. This cache holds only 16 bytes. It cannot hold the whole memory. It holds the bytes that were needed recently, or the bytes that arrived next to them.

The test never writes new values into memory. It only reads. And the value stored in each byte is the address itself:

| Address | Value stored there |
|---|---|
| `0` | `0` |
| `1` | `1` |
| `2` | `2` |
| `4` | `4` |
| `7` | `7` |

So if a read of address `5` succeeds, the byte that comes back is `5`. That makes the result easy to check: the data and the address are the same number.

## Words used below

| Word | Meaning in this design |
|---|---|
| Address | The number of the byte being requested. |
| Read | Ask for the byte at an address. This test only reads. |
| Line | A group of 4 neighboring bytes that the cache loads and stores together. |
| Hit | The bytes needed are already in the cache. Main memory is not read. |
| Miss | Those bytes are not in the cache. The cache loads a whole line from main memory, then answers. |
| Tag | The part of the address that says which line of memory is stored in a cache slot. |
| Valid | A bit that says “this cache slot holds a real line.” After a clear, every slot is invalid, which means empty. |

## How this cache is built

It is a direct-mapped cache with 4 lines, and each line is 4 bytes.

Direct-mapped means each address is allowed to sit in only one slot. There is no choice. The address itself picks the slot. If a new line needs that same slot, the old line is replaced.

| Cache slot | Which addresses can land here | What one slot holds |
|---|---|---|
| Line 0 | `0, 1, 2, 3`, and also `16, 17, 18, 19`, and any other address whose bits `[3:2]` are `00` | 4 bytes, plus a tag, plus a valid bit |
| Line 1 | `4, 5, 6, 7`, and any address whose bits `[3:2]` are `01` | 4 bytes, plus a tag, plus a valid bit |
| Line 2 | `8, 9, 10, 11` | 4 bytes, plus a tag, plus a valid bit |
| Line 3 | `12, 13, 14, 15` | 4 bytes, plus a tag, plus a valid bit |

Four slots times 4 bytes is 16 bytes of cached data. Main memory is 256 bytes, so most addresses are not in the cache at any moment.

An 8-bit address is split into three fields:

| Bits | Name | Job |
|---|---|---|
| `[7:4]` | Tag | Which group of memory this is. Stored beside the line so a later read can check that the slot still holds the right group. |
| `[3:2]` | Line, also called the index | Picks slot 0, 1, 2, or 3. |
| `[1:0]` | Byte, also called the offset | Picks which of the 4 bytes inside the line is the one that was asked for. |

Examples:

| Address | In binary | Tag | Line | Byte | So it belongs with |
|---|---|---|---|---|---|
| `0` | `0000 0000` | `0` | 0 | 0 | bytes `0, 1, 2, 3` |
| `1` | `0000 0001` | `0` | 0 | 1 | the same four bytes |
| `3` | `0000 0011` | `0` | 0 | 3 | the same four bytes |
| `4` | `0000 0100` | `0` | 1 | 0 | bytes `4, 5, 6, 7` |
| `7` | `0000 0111` | `0` | 1 | 3 | the same four bytes |

Addresses `0`, `1`, `2`, and `3` are four different requests, but they are one line. Loading any one of them loads all four.

## What happens on one read

Before each test the cache is cleared. Every valid bit is off. Every slot is empty.

1. The test requests one address.
2. The address is split into tag, line, and byte.
3. The cache looks only at that one line.
4. If the valid bit is on and the stored tag matches, this is a hit. The cache returns the chosen byte and does not touch main memory.
5. If the slot is empty, or the tag is different, this is a miss. The cache reads four bytes from main memory, starting at the line’s first address. It stores those four bytes, stores the tag, and turns the valid bit on. Then it returns the one byte that was requested.
6. The old contents of that slot are gone. A direct-mapped slot has room for one line only.

A hit is the fast path. A miss is the slow path, because main memory has to be read. On the analyzer the miss is the long pulse, about 1.5 seconds, and the memory-read burst sits inside it. A hit is the short pulse, about 0.33 seconds, and the memory-read row stays low.

## Test 1 — temporal locality

Temporal locality means “this same address will be asked for again soon.” The cache helps because the first miss leaves the line in place, and the repeats are hits.

The test requests address `0x00` five times. The cache starts empty.

| Step | Request | Line checked | What is in that line before the request | Result | Byte returned | What changed |
|---|---|---|---|---|---|---|
| 1 | `0x00` | 0 | Empty | Miss | `0` | Bytes `0, 1, 2, 3` are loaded. Tag `0` is stored. Valid turns on. |
| 2 | `0x00` | 0 | Bytes `0, 1, 2, 3`, tag matches | Hit | `0` | Nothing is loaded. |
| 3 | `0x00` | 0 | Same line | Hit | `0` | Nothing is loaded. |
| 4 | `0x00` | 0 | Same line | Hit | `0` | Nothing is loaded. |
| 5 | `0x00` | 0 | Same line | Hit | `0` | Nothing is loaded. |

Step 1 has to miss. There is nothing in the cache yet, so the byte cannot already be there. Steps 2 through 5 hit because the test asks for the identical address and nobody has replaced line 0.

On the waveform, one temporal pass looks like this: one long miss, one memory-read burst inside that miss, then four short hits with the memory-read row staying low. A quiet gap after that is the cache being cleared so the next pass can start empty.

Waveform:

Explainer:

## Test 2 — spatial locality

Spatial locality means “bytes next to the one just requested will be requested soon.” The cache helps because a miss does not load one byte. It loads the whole line of four neighbors.

The test requests `0x00`, then `0x01`, `0x02`, `0x03`, `0x04`, `0x05`, `0x06`, `0x07`. The cache starts empty again.

| Step | Request | Line checked | What is already in the cache | Result | Byte returned | Why this result |
|---|---|---|---|---|---|---|
| 1 | `0x00` | 0 | Nothing | Miss | `0` | Line 0 is empty. The load brings `0, 1, 2, 3`, even though only `0` was asked for. |
| 2 | `0x01` | 0 | `0, 1, 2, 3` | Hit | `1` | `1` was loaded on the previous miss. It is the next byte in the same line. |
| 3 | `0x02` | 0 | `0, 1, 2, 3` | Hit | `2` | Same line. |
| 4 | `0x03` | 0 | `0, 1, 2, 3` | Hit | `3` | Last byte of that line. |
| 5 | `0x04` | 1 | Line 1 is still empty. Line 0 still holds `0, 1, 2, 3`. | Miss | `4` | `4` belongs to line 1, which has never been loaded. The load brings `4, 5, 6, 7`. Line 0 is left as it was. |
| 6 | `0x05` | 1 | `4, 5, 6, 7` | Hit | `5` | `5` arrived with the miss on `4`. |
| 7 | `0x06` | 1 | `4, 5, 6, 7` | Hit | `6` | Same line. |
| 8 | `0x07` | 1 | `4, 5, 6, 7` | Hit | `7` | Last byte of that line. |

The important point is steps 2, 3, and 4. The test never missed on `1`, `2`, or `3`. Those hits exist only because the miss on `0` fetched the neighbors at the same time. The same thing happens again for `5`, `6`, and `7` after the miss on `4`.

On the waveform, one spatial pass looks like this: a long miss, three short hits, a long miss, three short hits. Each long miss contains one memory-read burst. The short hits do not.

Waveform:

Explainer:

## How to match a spike to a row in the tables

The clips were:

| Analyzer row | Board pin | Signal |
|---|---|---|
| A3 | F18 | Request. A new address lookup has started. |
| A1 | F14 | Miss. The line was not in the cache. |
| A2 | F17 | Memory read. The four bytes of a line are being copied in. This pulse sits inside a miss. |
| A0 | F15 | Hit. The byte was already in the cache. |

A request spike comes first. Then either a long miss with a memory read, or a short hit with no memory read. Hit and miss are never high together, because one request has one result.

The design runs Test 1, clears the cache, runs Test 2, clears the cache, and repeats. A temporal picture is “one miss, four hits.” A spatial picture is “miss, hit, hit, hit, miss, hit, hit, hit.”
