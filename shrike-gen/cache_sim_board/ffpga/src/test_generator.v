module test_generator (
    input wire clk,
    input wire ce,
    input wire rst,
    input wire next_req,
    input wire [1:0] exp_sel,
    output reg [7:0] address,
    output reg req_out,
    output reg done_all
);
    reg [2:0] step;

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
