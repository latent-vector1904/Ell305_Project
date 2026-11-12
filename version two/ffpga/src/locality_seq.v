// Two repeating demonstrations.
// Temporal: address 0x00 five times. First access misses, the next four hit.
// Spatial:  addresses 0x00..0x07. A miss loads a 4-byte line, so the next
//           three bytes hit. Then the next line misses and its three bytes hit.
module locality_seq (
    input wire clk,
    input wire ce,
    input wire rst,
    input wire cache_idle,
    input wire done,
    output reg [7:0] address,
    output reg req,
    output reg clear_cache,
    output reg temporal
);
    localparam ISSUE = 2'd0, DROP = 2'd1, WAIT = 2'd2, GAP = 2'd3;

    reg [1:0] st;
    reg [3:0] n;
    reg [2:0] gap;
    reg after_gap_temporal;

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
