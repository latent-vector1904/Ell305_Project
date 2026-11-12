# Flash cache simulator bitstream onto Shrike-lite FPGA.
# In Thonny: upload FPGA_bitstream_MCU.bin + this file to the board, then Run.
import shrike

shrike.flash("FPGA_bitstream_MCU.bin")
print("FPGA programmed: cache_sim")
