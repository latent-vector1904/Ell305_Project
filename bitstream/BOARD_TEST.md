# Shrike-lite: flash + Zeroplus LAP-C 16032 probe guide

## Bitstream (use this one)

| File | Use |
|------|-----|
| **`FPGA_bitstream_MCU.bin`** | Flash via Thonny / `shrike.flash()` |
| `FPGA_bitstream_OTP.bin` | OTP programming (not needed for day-to-day) |
| `FPGA_bitstream_FLASH_MEM.bin` | External flash config mode |

Achieved Fmax ≈ **95.8 MHz** (design runs from 50 MHz OSC).

Project sources + pin map: `shrike-gen/cache_sim_board/`

---

## 1. Go Configure (optional reopen)

Open `shrike-gen/cache_sim_board/cache_sim_board.ffpga` in Go Configure Software Hub if you want GUI P&R. Bitstreams are already built under `bitstream/`.

Rebuild from CLI (path must have **no spaces**; copy project to `/tmp` if needed):

```bash
cd /tmp/shrike_ws/cache_sim_board   # or a no-space copy
make top cache_sim_top GCSW=/usr/local/go-configure-sw-hub/bin/external VERILATOR=
```

---

## 2. Thonny — program the FPGA

1. Connect Shrike-lite over USB; select the board in Thonny.
2. Upload to the board filesystem:
   - `FPGA_bitstream_MCU.bin`
   - `flash_cache_sim.py`
3. Run `flash_cache_sim.py`, or in the REPL:

```python
import shrike
shrike.flash("FPGA_bitstream_MCU.bin")
```

On-board **FPGA LED** lights on each **cache hit**.

---

## 3. Inputs (select experiment)

| Signal | FPGA package pin | How to drive |
|--------|------------------|--------------|
| `rst` | PIN 13 | HIGH = run; pulse LOW→HIGH to restart |
| `experiment_sel[0]` | PIN 14 | LSB |
| `experiment_sel[1]` | PIN 15 | MSB |

| sel[1:0] | Experiment |
|----------|------------|
| 00 | always address `0x00` (expect 1 miss, then hits) |
| 01 | sequential `0..7` (misses at block starts) |
| 10 | alternate `0x00` / `0x10` (conflict thrashing) |
| 11 | `0x00` / `0x40` / `0x80` / `0xC0` (cold misses) |

Tie unused select pins to GND or 3.3 V with jumpers (do not leave floating).

---

## 4. Zeroplus LAP-C 16032 — probe map

Connect LA probes to these **FPGA package pins** (header / test pads on Shrike-lite):

| LA channel suggestion | Signal | Pin | Notes |
|-----------------------|--------|-----|-------|
| CH0 | `clk_out` | **17** | ~6 Hz slow debug clock — good **trigger** |
| CH1 | `cache_hit` | **18** | pulse on hit |
| CH2 | `cache_miss` | **19** | pulse on miss |
| CH3 | `mem_read` | **20** | high while fetching bytes |
| CH4 | `request` | **23** | address request pulse |
| CH5 | `done` | **24** | transaction complete |
| CH6 | `cache_state[0]` | **1** | FSM bit 0 |
| CH7 | `cache_state[1]` | **2** | FSM bit 1 |

**FSM (`cache_state`):** `00` IDLE · `01` COMPARE · `10` FETCH · `11` RETURN

**Suggested Zeroplus setup**

- Sample rate: ≥ 1 MHz (signals are slowed by the on-chip divider; ~6 Hz enable)
- Trigger: rising edge on `clk_out` (CH0) or on `request` (CH4)
- Threshold: 1.8 V / 3.3 V logic as appropriate for Shrike I/O

You should see: `request` → (`miss` + `mem_read` bursts) or `hit` → `done`, then FSM back to IDLE.

---

## 5. What “working” looks like

**Exp 00 (sel=00):** first access miss + mem_read, then repeated hits; LED blinks on hits.

**Exp 01 (sel=01):** miss at `0x00` and `0x04`, hits on the other addresses in each 4-byte block.

**Exp 10 (sel=10):** every access miss (same index, alternating tags).

**Exp 11 (sel=11):** four cold misses, different lines.
