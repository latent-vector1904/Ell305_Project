`timescale 1ns/1ps
/**
 * @file 03_tb_locality.v
 * @brief Count hits and misses of the temporal pass and the spatial pass.
 */

/**
 * @brief Count hits and misses of the temporal pass and the spatial pass.
 *
 * The run fails unless the temporal pass has at least one miss and four hits and the spatial pass has at least two misses and six hits.
 */

module tb_locality;
    reg clk = 0;
    /**
     * @brief Free-running clock. The half-period is 5 time units.
     */
    always #5 clk = ~clk;

    wire clk_en, clk_out, cache_hit, cache_miss, mem_read, request, done, temporal;
    wire clk_out_en, cache_hit_en, cache_miss_en, mem_read_en, request_en, done_en, temporal_en;

    cache_sim_top #(.DIV_MSB(2)) dut (
        .clk_in(clk), .clk_en(clk_en),
        .clk_out(clk_out), .cache_hit(cache_hit), .cache_miss(cache_miss),
        .mem_read(mem_read), .request(request), .done(done), .temporal(temporal),
        .clk_out_en(clk_out_en), .cache_hit_en(cache_hit_en),
        .cache_miss_en(cache_miss_en), .mem_read_en(mem_read_en),
        .request_en(request_en), .done_en(done_en), .temporal_en(temporal_en)
    );

    integer fh;
    integer t_hit, t_miss, s_hit, s_miss;
    initial begin
        fh = $fopen("waves/sim_results.txt", "w");
        t_hit = 0; t_miss = 0; s_hit = 0; s_miss = 0;
        $dumpfile("waves/locality.vcd");
        $dumpvars(0, tb_locality);
    end

    /**
     * @brief Count hits and misses separately for the temporal pass and the spatial pass.
     */
    always @(posedge clk) begin
        if (done) begin
            if (temporal) begin
                if (cache_hit) t_hit = t_hit + 1;
                if (cache_miss) t_miss = t_miss + 1;
            end else begin
                if (cache_hit) s_hit = s_hit + 1;
                if (cache_miss) s_miss = s_miss + 1;
            end
            $display("%0t temporal=%0b addr=%h hit=%b miss=%b mem=%b",
                     $time, temporal, dut.address, cache_hit, cache_miss, mem_read);
            $fwrite(fh, "temporal=%0b addr=%h hit=%b miss=%b\n",
                    temporal, dut.address, cache_hit, cache_miss);
        end
    end

    initial begin
        #200000;
        $display("TOTAL temporal hits=%0d misses=%0d  spatial hits=%0d misses=%0d",
                 t_hit, t_miss, s_hit, s_miss);
        $fwrite(fh, "TOTAL temporal hits=%0d misses=%0d spatial hits=%0d misses=%0d\n",
                t_hit, t_miss, s_hit, s_miss);
        $fclose(fh);
        if (t_miss < 1 || t_hit < 4 || s_miss < 2 || s_hit < 6) begin
            $display("FAIL");
            $finish(1);
        end
        $display("PASS");
        $finish(0);
    end
endmodule
