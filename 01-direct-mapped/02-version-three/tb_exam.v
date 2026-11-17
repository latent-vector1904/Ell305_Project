`timescale 1ns/1ps
module tb_exam;
    reg clk = 0;
    always #5 clk = ~clk;

    wire clk_en, clk_out, cache_hit, cache_miss, mem_read, request, done;
    wire [2:0] phase;
    wire clk_out_en, cache_hit_en, cache_miss_en, mem_read_en, request_en, done_en;
    wire [2:0] phase_en;

    cache_sim_top #(.DIV_MSB(2)) dut (
        .clk_in(clk), .clk_en(clk_en),
        .clk_out(clk_out), .cache_hit(cache_hit), .cache_miss(cache_miss),
        .mem_read(mem_read), .request(request), .done(done), .phase(phase),
        .clk_out_en(clk_out_en), .cache_hit_en(cache_hit_en),
        .cache_miss_en(cache_miss_en), .mem_read_en(mem_read_en),
        .request_en(request_en), .done_en(done_en), .phase_en(phase_en)
    );

    // BEGIN GENERATED EXPECT
    localparam NADDR = 39;

    function [8:0] expected;
        input integer i;
        begin
            case (i)
                0: expected = {1'b1, 8'h00};
                1: expected = {1'b0, 8'h00};
                2: expected = {1'b0, 8'h00};
                3: expected = {1'b0, 8'h00};
                4: expected = {1'b0, 8'h00};
                5: expected = {1'b1, 8'h00};
                6: expected = {1'b0, 8'h01};
                7: expected = {1'b0, 8'h02};
                8: expected = {1'b0, 8'h03};
                9: expected = {1'b1, 8'h04};
                10: expected = {1'b0, 8'h05};
                11: expected = {1'b0, 8'h06};
                12: expected = {1'b0, 8'h07};
                13: expected = {1'b1, 8'h00};
                14: expected = {1'b1, 8'h10};
                15: expected = {1'b1, 8'h00};
                16: expected = {1'b1, 8'h10};
                17: expected = {1'b1, 8'h00};
                18: expected = {1'b1, 8'h04};
                19: expected = {1'b1, 8'h08};
                20: expected = {1'b1, 8'h0C};
                21: expected = {1'b0, 8'h00};
                22: expected = {1'b0, 8'h04};
                23: expected = {1'b0, 8'h08};
                24: expected = {1'b0, 8'h0C};
                25: expected = {1'b1, 8'h00};
                26: expected = {1'b0, 8'h00};
                27: expected = {1'b1, 8'h10};
                28: expected = {1'b1, 8'h00};
                29: expected = {1'b1, 8'h00};
                30: expected = {1'b1, 8'h04};
                31: expected = {1'b0, 8'h00};
                32: expected = {1'b0, 8'h04};
                33: expected = {1'b1, 8'h03};
                34: expected = {1'b0, 8'h02};
                35: expected = {1'b0, 8'h01};
                36: expected = {1'b0, 8'h00};
                37: expected = {1'b1, 8'hFC};
                38: expected = {1'b0, 8'hFF};
                default: expected = 9'h1ff;
            endcase
        end
    endfunction
    // END GENERATED EXPECT

    reg seen;
    integer n_ok, n_bad, k;
    reg [8:0] exp;

    initial begin
        seen = 0;
        n_ok = 0;
        n_bad = 0;
        k = 0;
    end

    always @(posedge clk) begin
        if (done && !seen) begin
            seen <= 1'b1;
            exp = expected(k % NADDR);
            if (dut.address !== exp[7:0] || cache_miss !== exp[8]
                || cache_hit !== ~exp[8] || dut.data_out !== exp[7:0]) begin
                n_bad = n_bad + 1;
                $display("BAD k=%0d phase=%0d addr=%h exp=%h hit=%b miss=%b data=%h",
                         k, phase, dut.address, exp[7:0], cache_hit, cache_miss, dut.data_out);
            end else begin
                n_ok = n_ok + 1;
            end
            k = k + 1;
        end else if (!done) begin
            seen <= 1'b0;
        end
    end

    initial begin
        #800000;
        $display("ok=%0d bad=%0d accesses=%0d", n_ok, n_bad, k);
        if (n_bad != 0 || k < NADDR)
            $finish(1);
        $display("PASS");
        $finish(0);
    end
endmodule
