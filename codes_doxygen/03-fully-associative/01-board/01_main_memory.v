/**
 * @file 01_main_memory.v
 * @brief 256-byte memory model whose stored byte is the address itself.
 * @note Identical bytes also at fpga/lru/src/main_memory.v.
 */

/**
 * @brief 256-byte memory model whose stored byte is the address itself.
 *
 * A read of address N returns N. ready follows read_en. Used inside the LRU cache.
 */

module main_memory (
    input wire read_en, ///< Memory read enable.
    input wire [7:0] address, ///< Byte address in the 256-byte memory.
    output wire [7:0] data_out, ///< Byte at the read address. The byte equals the address.
    output wire ready ///< High in the same cycle as read_en. Data is combinational.
);
    // Each byte contains its own address, so a correct read is obvious.
    assign data_out = address;
    assign ready = read_en;
endmodule
