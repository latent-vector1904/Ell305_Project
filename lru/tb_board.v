`timescale 1ns/1ps
`include "expect_rom.vh"

// Two checks of the board RTL:
// 1. The cache itself, one access at a time, including the returned byte.
// 2. The top level with the real sequencer, slowed only by a tiny divider,
//    so the hit/miss/read pattern of a full looping suite can be checked.
module tb_board;
    reg clk = 0;
    always #10 clk = ~clk;

    // ---- direct cache ----
    reg ce = 1'b1;
    reg rst = 1'b1;
    reg req = 1'b0;
    reg [7:0] address = 8'h00;
    wire [7:0] data_out;
    wire hit, miss, mem_read, done, idle;

    lru_cache direct (
        .clk(clk), .ce(ce), .rst(rst), .req(req), .address(address),
        .data_out(data_out), .hit(hit), .miss(miss), .mem_read(mem_read),
        .done(done), .idle(idle)
    );

    integer errors, n, guard, accesses;
    reg saw_read;
    reg [8:0] exp;
    reg expect_miss;

    task check_access;
        input [6:0] idx;
        begin
            exp = board_expect(idx);
            expect_miss = exp[8];
            address = exp[7:0];
            @(posedge clk);
            req <= 1'b1;
            @(posedge clk);
            req <= 1'b0;
            saw_read = 1'b0;
            guard = 0;
            begin : waitdone
                forever begin
                    @(posedge clk);
                    #1;
                    if (mem_read)
                        saw_read = 1'b1;
                    if (hit === miss && (hit === 1'b1)) begin
                        $display("FAIL both hit and miss idx %0d", idx);
                        errors = errors + 1;
                    end
                    guard = guard + 1;
                    if (done || guard > 40)
                        disable waitdone;
                end
            end
            accesses = accesses + 1;
            if (guard > 40) begin
                $display("FAIL timeout %0s addr %02h", board_name(idx), address);
                errors = errors + 1;
            end else begin
                if (data_out !== address) begin
                    $display("FAIL data %02h wanted %02h %0s", data_out, address, board_name(idx));
                    errors = errors + 1;
                end
                if (miss !== expect_miss) begin
                    $display("FAIL %0s addr %02h got %s wanted %s",
                        board_name(idx), address, miss ? "MISS" : "HIT",
                        expect_miss ? "MISS" : "HIT");
                    errors = errors + 1;
                end
                if (expect_miss && !saw_read) begin
                    $display("FAIL miss without memory read %0s", board_name(idx));
                    errors = errors + 1;
                end
                if (!expect_miss && saw_read) begin
                    $display("FAIL hit with memory read %0s", board_name(idx));
                    errors = errors + 1;
                end
            end
            @(posedge clk);
        end
    endtask

    task run_direct;
        integer k;
        begin
            rst = 1'b1;
            req = 1'b0;
            repeat (4) @(posedge clk);
            rst = 1'b0;
            @(posedge clk);
            for (k = 0; k < BOARD_N; k = k + 1) begin
                check_access(k[6:0]);
                // The sequencer clears the cache after the last access of a test.
                // Reproduce that here so the next test starts empty.
                if (board_is_end(k[6:0])) begin
                    rst = 1'b1;
                    repeat (2) @(posedge clk);
                    rst = 1'b0;
                    @(posedge clk);
                end
            end
        end
    endtask

    // ---- top level, DIV_MSB = 2 so a tick is 8 clocks ----
    wire clk_en, clk_out, cache_hit, cache_miss, top_read, top_req, top_done;
    wire [2:0] phase;
    wire clk_out_en, cache_hit_en, cache_miss_en, top_read_en, top_req_en, top_done_en;
    wire [2:0] phase_en;

    cache_sim_top #(.DIV_MSB(2)) top (
        .clk_in(clk),
        .clk_en(clk_en),
        .clk_out(clk_out),
        .cache_hit(cache_hit),
        .cache_miss(cache_miss),
        .mem_read(top_read),
        .request(top_req),
        .done(top_done),
        .phase(phase),
        .clk_out_en(clk_out_en),
        .cache_hit_en(cache_hit_en),
        .cache_miss_en(cache_miss_en),
        .mem_read_en(top_read_en),
        .request_en(top_req_en),
        .done_en(top_done_en),
        .phase_en(phase_en)
    );

    integer ev, clocks, loop_clocks;
    integer first_req_at;
    reg [8:0] top_exp;
    reg top_miss_exp;
    reg hit_d, miss_d, req_d;
    reg in_miss, miss_saw;
    reg loop_done;

    always @(posedge clk) begin
        #1;
        if (top.por) begin
            ev <= 0;
            hit_d <= 1'b0;
            miss_d <= 1'b0;
            req_d <= 1'b0;
            in_miss <= 1'b0;
            miss_saw <= 1'b0;
            first_req_at <= -1;
            loop_done <= 1'b0;
        end else begin
            clocks <= clocks + 1;
            if (cache_hit && cache_miss) begin
                $display("FAIL top hit and miss together at %0d", clocks);
                errors = errors + 1;
            end
            if (cache_hit && top_read) begin
                $display("FAIL top hit while memory is read at %0d", clocks);
                errors = errors + 1;
            end
            if (cache_miss)
                in_miss <= 1'b1;
            if (in_miss && top_read)
                miss_saw <= 1'b1;
            if (miss_d && !cache_miss) begin
                if (!miss_saw) begin
                    $display("FAIL top miss with no memory read, event before %0d", ev);
                    errors = errors + 1;
                end
                in_miss <= 1'b0;
                miss_saw <= 1'b0;
            end

            if (top_req && !req_d) begin
                if (first_req_at < 0)
                    first_req_at <= clocks;
                else if (ev == BOARD_N && !loop_done) begin
                    loop_clocks = clocks - first_req_at;
                    loop_done <= 1'b1;
                    $display("LOOP fast clocks %0d  ticks %0d", loop_clocks, loop_clocks / 8);
                end
            end

            if ((cache_hit && !hit_d) || (cache_miss && !miss_d)) begin
                if (ev < BOARD_N) begin
                    top_exp = board_expect(ev[6:0]);
                    top_miss_exp = top_exp[8];
                    if (cache_miss !== top_miss_exp) begin
                        $display("FAIL top %0s idx %0d got %s wanted %s",
                            board_name(ev[6:0]), ev,
                            cache_miss ? "MISS" : "HIT",
                            top_miss_exp ? "MISS" : "HIT");
                        errors = errors + 1;
                    end
                    ev <= ev + 1;
                end
            end
            hit_d <= cache_hit;
            miss_d <= cache_miss;
            req_d <= top_req;
        end
    end

    initial begin
        errors = 0;
        accesses = 0;
        clocks = 0;
        ev = 0;
        loop_done = 0;
        first_req_at = -1;
        run_direct();
        $display("DIRECT accesses %0d errors %0d", accesses, errors);
        // The top started at time 0. Wait until one full suite has looped.
        wait (loop_done === 1'b1);
        if (ev < BOARD_N) begin
            $display("FAIL top only saw %0d of %0d events", ev, BOARD_N);
            errors = errors + 1;
        end
        if (errors == 0)
            $display("ALL BOARD CHECKS PASSED");
        else
            $display("FAILED %0d checks", errors);
        $finish;
    end

    initial begin
        #50_000_000;
        $display("FAIL simulation timeout events %0d", ev);
        $finish;
    end
endmodule
