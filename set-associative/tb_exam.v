`timescale 1ns/1ps
// Checks the returned byte and the hit/miss flag, and measures how many
// clock-enable cycles each flag stays high. DIV_MSB=2 only shortens the divider.
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
    localparam NADDR = 41;

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
                15: expected = {1'b0, 8'h00};
                16: expected = {1'b0, 8'h10};
                17: expected = {1'b1, 8'h00};
                18: expected = {1'b1, 8'h04};
                19: expected = {1'b1, 8'h08};
                20: expected = {1'b1, 8'h0C};
                21: expected = {1'b0, 8'h00};
                22: expected = {1'b0, 8'h04};
                23: expected = {1'b0, 8'h08};
                24: expected = {1'b0, 8'h0C};
                25: expected = {1'b1, 8'h00};
                26: expected = {1'b1, 8'h10};
                27: expected = {1'b0, 8'h00};
                28: expected = {1'b1, 8'h20};
                29: expected = {1'b0, 8'h00};
                30: expected = {1'b1, 8'h10};
                31: expected = {1'b1, 8'h00};
                32: expected = {1'b1, 8'h04};
                33: expected = {1'b0, 8'h00};
                34: expected = {1'b0, 8'h04};
                35: expected = {1'b1, 8'h03};
                36: expected = {1'b0, 8'h02};
                37: expected = {1'b0, 8'h01};
                38: expected = {1'b0, 8'h00};
                39: expected = {1'b1, 8'hFC};
                40: expected = {1'b0, 8'hFF};
                default: expected = 9'h1ff;
            endcase
        end
    endfunction
    // END GENERATED EXPECT

    reg seen;
    integer n_ok, n_bad, k;
    integer miss_count [0:7];
    integer hit_count [0:7];
    integer pi;
    reg [8:0] exp;

    integer hit_run, miss_run, mem_run;
    integer n_hit_w, n_miss_w, n_mem_w;
    integer hit_bad_w, miss_bad_w;
    reg hit_d, miss_d, mem_d;

    initial begin
        seen = 0;
        n_ok = 0;
        n_bad = 0;
        k = 0;
        hit_run = 0;
        miss_run = 0;
        mem_run = 0;
        n_hit_w = 0;
        n_miss_w = 0;
        n_mem_w = 0;
        hit_bad_w = 0;
        miss_bad_w = 0;
        hit_d = 0;
        miss_d = 0;
        mem_d = 0;
        for (pi = 0; pi < 8; pi = pi + 1) begin
            miss_count[pi] = 0;
            hit_count[pi] = 0;
        end
    end

    // One time unit after the enable edge, the registered flags have updated.
    always @(posedge clk) begin
        if (dut.slow_enable) begin
            #1;
            if (cache_hit) hit_run = hit_run + 1;
            else if (hit_d) begin
                n_hit_w = n_hit_w + 1;
                if (hit_run != 2) begin
                    hit_bad_w = hit_bad_w + 1;
                    $display("HIT_WIDTH %0d", hit_run);
                end
                hit_run = 0;
            end
            if (cache_miss) miss_run = miss_run + 1;
            else if (miss_d) begin
                n_miss_w = n_miss_w + 1;
                if (miss_run != 9) begin
                    miss_bad_w = miss_bad_w + 1;
                    $display("MISS_WIDTH %0d", miss_run);
                end
                miss_run = 0;
            end
            if (mem_read) mem_run = mem_run + 1;
            else if (mem_d) begin
                n_mem_w = n_mem_w + 1;
                mem_run = 0;
            end
            hit_d = cache_hit;
            miss_d = cache_miss;
            mem_d = mem_read;
        end
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
                if (k < NADDR) begin
                    if (cache_miss) miss_count[phase] = miss_count[phase] + 1;
                    else hit_count[phase] = hit_count[phase] + 1;
                    $display("OK k=%0d phase=%0d addr=%h data=%h %s",
                             k, phase, dut.address, dut.data_out,
                             cache_miss ? "MISS" : "HIT");
                end
            end
            k = k + 1;
        end else if (!done) begin
            seen <= 1'b0;
        end
    end

    initial begin
        #900000;
        $display("ok=%0d bad=%0d accesses=%0d", n_ok, n_bad, k);
        for (pi = 0; pi < 8; pi = pi + 1)
            if (hit_count[pi] + miss_count[pi] != 0)
                $display("PHASE %0d hits=%0d misses=%0d", pi, hit_count[pi], miss_count[pi]);
        $display("HIT_PULSES %0d bad_width %0d expect_width 2", n_hit_w, hit_bad_w);
        $display("MISS_PULSES %0d bad_width %0d expect_width 9", n_miss_w, miss_bad_w);
        $display("MEM_PULSES %0d", n_mem_w);
        if (n_bad != 0 || k < NADDR || hit_bad_w != 0 || miss_bad_w != 0 || n_mem_w != n_miss_w) begin
            $display("FAIL");
            $finish(1);
        end
        $display("PASS");
        $finish(0);
    end
endmodule
