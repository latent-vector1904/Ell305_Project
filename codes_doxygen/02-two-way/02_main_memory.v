/**
 * @file 02_main_memory.v
 * @brief 256-byte memory model whose stored byte is the address itself.
 */

/**
 * @brief 256-byte memory model whose stored byte is the address itself.
 *
 * A read of address N returns N, so a wrong fill is obvious. ready follows read_en.
 */

module main_memory (
    input wire read_en, ///< Memory read enable.
    input wire [7:0] address, ///< Byte address in the 256-byte memory.
    output wire [7:0] data_out, ///< Byte at the read address. The byte equals the address.
    output wire ready ///< High in the same cycle as read_en. Data is combinational.
);
    // The byte at an address is the address, so a wrong fill is obvious.
    assign data_out = address;
    assign ready = read_en;
endmodule
