/**
 * @file 03_test_generator.v
 * @brief Issue one of four short address patterns.
 * @note Identical bytes also at fpga/cache_sim/ffpga/src/test_generator.v, fpga/shrike_fixed/test_generator.v.
 */

/**
 * @brief Issue one of four short address patterns.
 *
 * exp_sel 0 repeats 0x00. exp_sel 1 walks 0 through 7. exp_sel 2 alternates 0x00 and 0x10. exp_sel 3 steps across the four line bases. done_all rises after the last address.
 */

module test_generator (
    input wire clk, ///< Clock.
    input wire ce, ///< Clock enable. The state machine advances only when this is high.
    input wire rst, ///< Synchronous reset.
    input wire next_req, ///< Issue the next stimulus address.
    input wire [1:0] exp_sel, ///< Pattern select. 0 repeats 0x00, 1 walks 0..7, 2 alternates 0x00 and 0x10, 3 steps across lines.
    output reg [7:0] address, ///< Byte address in the 256-byte memory.
    output reg req_out, ///< Stimulus request to the controller.
    output reg done_all ///< The selected pattern has issued its last address.
);
    reg [2:0] step;

    /**
     * @brief On next_req, present the next address of the pattern selected by exp_sel.
     */
    always @(posedge clk) begin
        if (rst) begin
            step <= 3'd0;
            address <= 8'd0;
            req_out <= 1'b0;
            done_all <= 1'b0;
        end else if (ce) begin
            req_out <= 1'b0;
            if (next_req && !done_all) begin
                req_out <= 1'b1;
                case (exp_sel)
                    2'b00: address <= 8'h00;
                    2'b01: address <= {5'b00000, step};
                    2'b10: address <= (step[0] == 1'b0) ? 8'h00 : 8'h10;
                    2'b11: address <= {step[1:0], 6'b000000};
                    default: address <= 8'h00;
                endcase

                if ((exp_sel == 2'b01 && step == 3'd7) ||
                    (exp_sel != 2'b01 && step == 3'd3)) begin
                    done_all <= 1'b1;
                end else begin
                    step <= step + 1'b1;
                end
            end
        end
    end
endmodule
