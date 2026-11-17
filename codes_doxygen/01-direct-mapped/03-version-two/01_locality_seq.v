/**
 * @file 01_locality_seq.v
 * @brief Alternate a temporal pass and a spatial pass.
 */

/**
 * @brief Alternate a temporal pass and a spatial pass.
 *
 * Temporal reads address 0x00 five times: one miss, then four hits. Spatial reads 0x00 through 0x07: a miss loads four bytes, so the next three hit, then the next line misses. The cache is cleared between the two passes.
 *
 * Two repeating demonstrations. Temporal: address 0x00 five times. First access misses, the next four hit. Spatial: addresses 0x00..0x07. A miss loads a 4-byte line, so the next three bytes hit. Then the next line misses and its three bytes hit.
 */

module locality_seq (
    input wire clk, ///< Clock.
    input wire ce, ///< Clock enable. The state machine advances only when this is high.
    input wire rst, ///< Synchronous reset.
    input wire cache_idle, ///< High when the cache is idle and can take a new address.
    input wire done, ///< High when this access has produced data_out.
    output reg [7:0] address, ///< Byte address in the 256-byte memory.
    output reg req, ///< Access request. Accepted while the controller is idle.
    output reg clear_cache, ///< Holds the cache in reset between tests.
    output reg temporal ///< High during the five reads of address 0, low during the walk from 0 to 7.
);
    localparam ISSUE = 2'd0, DROP = 2'd1, WAIT = 2'd2, GAP = 2'd3;

    reg [1:0] st;
    reg [3:0] n;
    reg [2:0] gap;
    reg after_gap_temporal;

    /**
     * @brief Issue the next address while the cache is idle, then clear the cache after the last address of a test.
     */
    always @(posedge clk) begin
        if (rst) begin
            st <= ISSUE;
            n <= 4'd0;
            gap <= 3'd0;
            address <= 8'h00;
            req <= 1'b0;
            clear_cache <= 1'b0;
            temporal <= 1'b1;
            after_gap_temporal <= 1'b0;
        end else if (ce) begin
            req <= 1'b0;
            case (st)
                ISSUE: begin
                    clear_cache <= 1'b0;
                    if (cache_idle && !done) begin
                        address <= temporal ? 8'h00 : {5'b00000, n[2:0]};
                        req <= 1'b1;
                        st <= DROP;
                    end
                end
                DROP: st <= WAIT;
                WAIT: begin
                    if (done) begin
                        if (temporal && n == 4'd4) begin
                            n <= 4'd0;
                            after_gap_temporal <= 1'b0;
                            clear_cache <= 1'b1;
                            gap <= 3'd0;
                            st <= GAP;
                        end else if (!temporal && n == 4'd7) begin
                            n <= 4'd0;
                            after_gap_temporal <= 1'b1;
                            clear_cache <= 1'b1;
                            gap <= 3'd0;
                            st <= GAP;
                        end else begin
                            n <= n + 4'd1;
                            st <= ISSUE;
                        end
                    end
                end
                GAP: begin
                    clear_cache <= 1'b1;
                    if (gap == 3'd5) begin
                        temporal <= after_gap_temporal;
                        clear_cache <= 1'b0;
                        st <= ISSUE;
                    end else begin
                        gap <= gap + 3'd1;
                    end
                end
                default: st <= ISSUE;
            endcase
        end
    end
endmodule
