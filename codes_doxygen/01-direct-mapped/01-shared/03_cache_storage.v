/**
 * @file 03_cache_storage.v
 * @brief Four direct-mapped lines, each a valid bit, a tag, and four bytes.
 * @note Identical bytes also at fpga/version two/ffpga/src/cache_storage.v, fpga/untitled/ffpga/src/cache_storage.v, fpga/cache_sim/ffpga/src/cache_storage.v, fpga/shrike_fixed/cache_storage.v.
 */

/**
 * @brief Four direct-mapped lines, each a valid bit, a tag, and four bytes.
 *
 * Reset clears every line. A write marks the indexed line valid and stores the tag and the block. The indexed line is visible combinationally.
 */

module cache_storage (
    input wire clk, ///< Clock.
    input wire ce, ///< Clock enable. The state machine advances only when this is high.
    input wire rst, ///< Synchronous reset.
    input wire write_en, ///< Store tag_in and block_in in the selected slot.
    input wire [1:0] index, ///< Line select. address[3:2]. Four lines.
    input wire [3:0] tag_in, ///< Tag written with the line.
    input wire [31:0] block_in, ///< Four-byte line to store. The lowest address is in bits [7:0].
    output wire [3:0] tag_out, ///< Tag of the indexed line.
    output wire [31:0] block_out, ///< Four-byte line stored at the indexed slot.
    output wire valid_out ///< High when the indexed line is valid.
);
    reg [36:0] lines [0:3]; // {valid, tag, 32-bit block}
    integer i;

    /**
     * @brief Clear every line on reset. A write stores the valid bit, the tag, and the four-byte block.
     */
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1)
                lines[i] <= 37'd0;
        end else if (ce && write_en) begin
            lines[index] <= {1'b1, tag_in, block_in};
        end
    end

    assign valid_out = lines[index][36];
    assign tag_out = lines[index][35:32];
    assign block_out = lines[index][31:0];
endmodule
