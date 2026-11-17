/**
 * @file 01_address_decoder.v
 * @brief Split an 8-bit address for a two-way set-associative cache.
 */

/**
 * @brief Split an 8-bit address for a two-way set-associative cache.
 *
 * Two sets, two ways, four-byte lines: 16 bytes, the same capacity as the direct-mapped cache. The tag is address[7:3], the set index is address[2], and the offset is address[1:0].
 *
 * 2-way set-associative split of an 8-bit address. 2 sets, 2 ways, 4-byte lines: 16 bytes, the same capacity as the direct-mapped cache.
 */

module address_decoder (
    input wire [7:0] address, ///< Byte address in the 256-byte memory.
    output wire [4:0] tag, ///< Tag. address[7:3].
    output wire index, ///< Set select. address[2]. Two sets.
    output wire [1:0] offset ///< Byte inside the four-byte line. address[1:0].
);
    assign tag    = address[7:3];
    assign index  = address[2];
    assign offset = address[1:0];
endmodule
