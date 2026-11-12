// Paste this entire file into the LEFT pane (testbench.sv) on EDA Playground.
`timescale 1ns / 1ps

// Simulation testbench for shrike_fixed cache modules.
// Uses ce=1 every cycle (skips the FPGA 2^23 clock divider in cache_sim_top).
module tb_cache_sim;
    reg clk;
    reg rst;
    reg [1:0] experiment_sel;

    wire [7:0] address;
    wire [7:0] data_out;
    wire [3:0] tag_out, tag_in;
    wire [1:0] index, offset;
    wire [31:0] block_in, block_out;
    wire req, valid_out, fetch_done, fetch_req, mem_ready;
    wire cache_we, done_all, done;
    wire [7:0] fetch_base, mem_addr, mem_data;
    wire [31:0] fetch_block;
    wire mem_read_internal;
    wire cache_hit, cache_miss;
    wire [1:0] cache_state;
    wire ce = 1'b1;

    wire [15:0] total_reqs, total_hits, total_misses, mem_tx, total_cycles;

    test_generator gen (
        .clk(clk), .ce(ce), .rst(rst),
        .next_req((cache_state == 2'b00) && ~req && ~done && ~done_all),
        .exp_sel(experiment_sel), .address(address),
        .req_out(req), .done_all(done_all)
    );

    address_decoder dec (
        .address(address), .tag(tag_in), .index(index), .offset(offset)
    );

    cache_storage cache (
        .clk(clk), .ce(ce), .rst(rst),
        .write_en(cache_we), .index(index),
        .tag_in(fetch_base[7:4]), .block_in(block_in),
        .tag_out(tag_out), .block_out(block_out), .valid_out(valid_out)
    );

    main_memory mem (
        .read_en(mem_read_internal), .address(mem_addr),
        .data_out(mem_data), .ready(mem_ready)
    );

    block_fetch_controller fetch (
        .clk(clk), .ce(ce), .rst(rst),
        .fetch_req(fetch_req), .base_address(fetch_base),
        .mem_ready(mem_ready), .mem_data(mem_data),
        .mem_read_en(mem_read_internal), .mem_addr(mem_addr),
        .block_out(fetch_block), .fetch_done(fetch_done)
    );

    cache_controller ctrl (
        .clk(clk), .ce(ce), .rst(rst), .req(req),
        .address(address), .addr_tag(tag_in), .addr_offset(offset),
        .cache_valid(valid_out), .cache_tag(tag_out),
        .cache_block(block_out), .fetch_done(fetch_done),
        .fetch_block(fetch_block), .cache_we(cache_we),
        .cache_write_data(block_in), .fetch_req(fetch_req),
        .fetch_base_addr(fetch_base), .data_out(data_out),
        .done(done), .hit(cache_hit), .miss(cache_miss),
        .debug_state(cache_state)
    );

    performance_counter perf (
        .clk(clk), .ce(ce), .rst(rst),
        .done(done), .hit(cache_hit), .miss(cache_miss),
        .mem_read_en(mem_read_internal),
        .total_reqs(total_reqs), .total_hits(total_hits),
        .total_misses(total_misses), .mem_tx(mem_tx),
        .total_cycles(total_cycles)
    );

    // 10 ns period clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    integer exp;
    integer timeout;
    integer fd;

    task run_experiment;
        input [1:0] sel;
        begin
            experiment_sel = sel;
            rst = 1'b1;
            repeat (4) @(posedge clk);
            rst = 1'b0;
            @(posedge clk);

            $display("\n===== Experiment %0d =====", sel);
            timeout = 0;
            // Wait until generator finishes AND controller returns to IDLE
            // (done_all rises on the same cycle as the last req_out).
            while (!(done_all && (cache_state == 2'b00) && !req && !done) &&
                   timeout < 5000) begin
                @(posedge clk);
                if (done)
                    $display("  t=%0t  addr=%02h  %s  data=%02h  state=%0d",
                             $time, address,
                             cache_hit ? "HIT " : "MISS",
                             data_out, cache_state);
                timeout = timeout + 1;
            end

            if (!(done_all && (cache_state == 2'b00)))
                $display("  ERROR: timeout waiting for experiment end");
            else
                $display("  DONE  reqs=%0d hits=%0d misses=%0d mem_tx=%0d cycles=%0d",
                         total_reqs, total_hits, total_misses, mem_tx, total_cycles);

            $fwrite(fd, "exp=%0d reqs=%0d hits=%0d misses=%0d mem_tx=%0d cycles=%0d\n",
                    sel, total_reqs, total_hits, total_misses, mem_tx, total_cycles);
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cache_sim);

        fd = $fopen("results.txt", "w");
        rst = 1'b1;
        experiment_sel = 2'b00;

        for (exp = 0; exp < 4; exp = exp + 1)
            run_experiment(exp[1:0]);

        $fclose(fd);
        $display("\nAll experiments finished. Waveform: dump.vcd");
        #20;
        $finish;
    end
endmodule
