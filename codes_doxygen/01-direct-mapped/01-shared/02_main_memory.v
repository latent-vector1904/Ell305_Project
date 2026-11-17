/**
 * @file 02_main_memory.v
 * @brief 256-byte memory model whose stored byte is the address itself.
 * @note Identical bytes also at fpga/version two/ffpga/src/main_memory.v, fpga/untitled/ffpga/src/main_memory.v, fpga/cache_sim/ffpga/src/main_memory.v, fpga/shrike_fixed/main_memory.v.
 */

/**
 * @brief 256-byte memory model whose stored byte is the address itself.
 *
 * A read of address N returns N, so a fill that picks the wrong bytes is obvious. ready follows read_en in the same cycle.
 */

module main_memory (
    input wire read_en, ///< Memory read enable.
    input wire [7:0] address, ///< Byte address in the 256-byte memory.
    output wire [7:0] data_out, ///< Byte at the read address. The byte equals the address.
    output wire ready ///< High in the same cycle as read_en. Data is combinational.
);
    // Behavioral memory model: each byte contains its own address.
    assign data_out = address;
    assign ready = read_en;
endmodule
