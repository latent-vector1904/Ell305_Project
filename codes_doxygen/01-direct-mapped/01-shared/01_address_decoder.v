/**
 * @file 01_address_decoder.v
 * @brief Split an 8-bit address into tag, index, and byte offset.
 * @note Identical bytes also at fpga/version two/ffpga/src/address_decoder.v, fpga/untitled/ffpga/src/address_decoder.v, fpga/cache_sim/ffpga/src/address_decoder.v, fpga/shrike_fixed/address_decoder.v.
 */

/**
 * @brief Split an 8-bit address into tag, index, and byte offset.
 *
 * Direct-mapped geometry shared by the early images and version two and version three. The tag is address[7:4], the index is address[3:2], and the offset is address[1:0]. That is four lines of four bytes.
 */

module address_decoder (
    input wire [7:0] address, ///< Byte address in the 256-byte memory.
    output wire [3:0] tag, ///< Tag. address[7:4].
    output wire [1:0] index, ///< Line select. address[3:2]. Four lines.
    output wire [1:0] offset ///< Byte inside the four-byte line. address[1:0].
);
    assign tag = address[7:4];
    assign index = address[3:2];
    assign offset = address[1:0];
endmodule
