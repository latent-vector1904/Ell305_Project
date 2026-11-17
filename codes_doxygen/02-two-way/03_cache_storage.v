/**
 * @file 03_cache_storage.v
 * @brief Two sets of two ways, with one LRU bit per set.
 */

/**
 * @brief Two sets of two ways, with one LRU bit per set.
 *
 * A line is a valid bit, a 5-bit tag, and four bytes. A write stores the line and marks the other way as the one to replace. A touch without a write does the same LRU update.
 *
 * Two sets, two ways. A line is a valid bit, a 5-bit tag and four bytes. lru[set] is the way replaced when both ways are valid. 0 is most recently used's partner.
 */

module cache_storage (
    input wire clk, ///< Clock.
    input wire ce, ///< Clock enable. The state machine advances only when this is high.
    input wire rst, ///< Synchronous reset.
    input wire write_en, ///< Store tag_in and block_in in the selected slot.
    input wire touch, ///< Update LRU for this way without writing the line.
    input wire way, ///< Way to write or to mark recently used. 0 or 1.
    input wire index, ///< Set select. address[2]. Two sets.
    input wire [4:0] tag_in, ///< 5-bit tag written with the line.
    input wire [31:0] block_in, ///< Four-byte line to store. The lowest address is in bits [7:0].
    output wire valid0, ///< Way 0 of the selected set holds a valid line.
    output wire valid1, ///< Way 1 of the selected set holds a valid line.
    output wire [4:0] tag0, ///< Tag stored in way 0.
    output wire [4:0] tag1, ///< Tag stored in way 1.
    output wire [31:0] block0, ///< Four-byte line stored in way 0.
    output wire [31:0] block1, ///< Four-byte line stored in way 1.
    output wire lru_way ///< Way replaced when both ways of the set are valid.
);
    reg [37:0] lines [0:1][0:1];
    reg lru [0:1];
    integer s, w;

    /**
     * @brief Reset both sets. A write stores the line and updates LRU. A touch updates LRU only.
     */
    always @(posedge clk) begin
        if (rst) begin
            for (s = 0; s < 2; s = s + 1) begin
                lru[s] <= 1'b0;
                for (w = 0; w < 2; w = w + 1)
                    lines[s][w] <= 38'd0;
            end
        end else if (ce && write_en) begin
            lines[index][way] <= {1'b1, tag_in, block_in};
            lru[index] <= ~way;
        end else if (ce && touch) begin
            lru[index] <= ~way;
        end
    end

    assign valid0  = lines[index][0][37];
    assign tag0    = lines[index][0][36:32];
    assign block0  = lines[index][0][31:0];
    assign valid1  = lines[index][1][37];
    assign tag1    = lines[index][1][36:32];
    assign block1  = lines[index][1][31:0];
    assign lru_way = lru[index];
endmodule
