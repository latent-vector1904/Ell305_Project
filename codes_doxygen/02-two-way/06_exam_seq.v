/**
 * @file 06_exam_seq.v
 * @brief Address ROM for the two-way exam.
 */

/**
 * @brief Address ROM for the two-way exam.
 *
 * The direct-mapped suite with the replacement test replaced by a three-block test in one set. phase is the test number. The cache is cleared between tests.
 *
 * Address list generated from test_template.txt. The suite repeats. phase tells which test is running. The cache is cleared between tests.
 */

module exam_seq (
    input wire clk, ///< Clock.
    input wire ce, ///< Clock enable. The state machine advances only when this is high.
    input wire rst, ///< Synchronous reset.
    input wire cache_idle, ///< High when the cache is idle and can take a new address.
    input wire done, ///< High when this access has produced data_out.
    output reg [7:0] address, ///< Byte address in the 256-byte memory.
    output reg req, ///< Access request. Accepted while the controller is idle.
    output reg clear_cache, ///< Holds the cache in reset between tests.
    output reg [2:0] phase ///< Test number. The cache is cleared between tests.
);
    localparam ISSUE = 2'd0, DROP = 2'd1, WAIT = 2'd2, GAP = 2'd3;

    reg [1:0] st;
    reg [5:0] n;
    reg [2:0] gap;

    // BEGIN GENERATED ROM
    localparam LAST = 6'd40;

    function [7:0] rom;
        input [5:0] i;
        begin
            case (i)
                6'd0: rom = 8'h00;
                6'd1: rom = 8'h00;
                6'd2: rom = 8'h00;
                6'd3: rom = 8'h00;
                6'd4: rom = 8'h00;
                6'd5: rom = 8'h00;
                6'd6: rom = 8'h01;
                6'd7: rom = 8'h02;
                6'd8: rom = 8'h03;
                6'd9: rom = 8'h04;
                6'd10: rom = 8'h05;
                6'd11: rom = 8'h06;
                6'd12: rom = 8'h07;
                6'd13: rom = 8'h00;
                6'd14: rom = 8'h10;
                6'd15: rom = 8'h00;
                6'd16: rom = 8'h10;
                6'd17: rom = 8'h00;
                6'd18: rom = 8'h04;
                6'd19: rom = 8'h08;
                6'd20: rom = 8'h0C;
                6'd21: rom = 8'h00;
                6'd22: rom = 8'h04;
                6'd23: rom = 8'h08;
                6'd24: rom = 8'h0C;
                6'd25: rom = 8'h00;
                6'd26: rom = 8'h10;
                6'd27: rom = 8'h00;
                6'd28: rom = 8'h20;
                6'd29: rom = 8'h00;
                6'd30: rom = 8'h10;
                6'd31: rom = 8'h00;
                6'd32: rom = 8'h04;
                6'd33: rom = 8'h00;
                6'd34: rom = 8'h04;
                6'd35: rom = 8'h03;
                6'd36: rom = 8'h02;
                6'd37: rom = 8'h01;
                6'd38: rom = 8'h00;
                6'd39: rom = 8'hFC;
                6'd40: rom = 8'hFF;
                default: rom = 8'h00;
            endcase
        end
    endfunction

    function is_end;
        input [5:0] i;
        begin
            is_end = (i == 6'd4) || (i == 6'd12) || (i == 6'd16) || (i == 6'd24) || (i == 6'd30) || (i == 6'd34) || (i == 6'd38) || (i == 6'd40);
        end
    endfunction

    function [2:0] phase_of;
        input [5:0] i;
        begin
            if (i <= 6'd4) phase_of = 3'd0;
            else if (i <= 6'd12) phase_of = 3'd1;
            else if (i <= 6'd16) phase_of = 3'd2;
            else if (i <= 6'd24) phase_of = 3'd3;
            else if (i <= 6'd30) phase_of = 3'd4;
            else if (i <= 6'd34) phase_of = 3'd5;
            else if (i <= 6'd38) phase_of = 3'd6;
            else phase_of = 3'd7;
        end
    endfunction
    // END GENERATED ROM

    /**
     * @brief Issue the next address while the cache is idle, then clear the cache after the last address of a test.
     */
    always @(posedge clk) begin
        if (rst) begin
            st <= ISSUE;
            n <= 6'd0;
            gap <= 3'd0;
            address <= 8'h00;
            req <= 1'b0;
            clear_cache <= 1'b0;
            phase <= 3'd0;
        end else if (ce) begin
            req <= 1'b0;
            case (st)
                ISSUE: begin
                    clear_cache <= 1'b0;
                    phase <= phase_of(n);
                    if (cache_idle && !done) begin
                        address <= rom(n);
                        req <= 1'b1;
                        st <= DROP;
                    end
                end
                DROP: st <= WAIT;
                WAIT: begin
                    if (done) begin
                        if (is_end(n)) begin
                            n <= (n == LAST) ? 6'd0 : n + 6'd1;
                            clear_cache <= 1'b1;
                            gap <= 3'd0;
                            st <= GAP;
                        end else begin
                            n <= n + 6'd1;
                            st <= ISSUE;
                        end
                    end
                end
                GAP: begin
                    clear_cache <= 1'b1;
                    phase <= phase_of(n);
                    if (gap == 3'd4) begin
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
