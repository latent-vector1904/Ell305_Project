`timescale 1ns/1ps
// Cycle-accurate latency of one hit and one miss, with ce tied high.
// One clock here is one cache step, which the board stretches to 2^23
// cycles of the 50 MHz oscillator.
module tb_latency;
    reg clk = 0;
    always #5 clk = ~clk;

    reg ce = 1'b1;
    reg rst = 1'b1;
    reg req = 1'b0;
    reg [7:0] address = 8'h00;
    wire [7:0] data_out;
    wire hit, miss, mem_read, done, idle;

    lru_cache dut (
        .clk(clk), .ce(ce), .rst(rst), .req(req), .address(address),
        .data_out(data_out), .hit(hit), .miss(miss), .mem_read(mem_read),
        .done(done), .idle(idle)
    );

    integer cyc;
    reg logging;
    reg [1:0] prev_cst;
    reg [2:0] prev_fst;

    function [8*8-1:0] cname;
        input [1:0] s;
        begin
            case (s)
                2'd0: cname = "IDLE";
                2'd1: cname = "COMPARE";
                2'd2: cname = "FETCH";
                2'd3: cname = "RETURN";
                default: cname = "?";
            endcase
        end
    endfunction

    function [8*8-1:0] fname;
        input [2:0] s;
        begin
            case (s)
                3'd0: fname = "IDLE";
                3'd1: fname = "READ0";
                3'd2: fname = "READ1";
                3'd3: fname = "READ2";
                3'd4: fname = "READ3";
                3'd5: fname = "DONE";
                default: fname = "?";
            endcase
        end
    endfunction

    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (logging) begin
            #1;
            $display("CYC %0d  cache %-7s  fetch %-5s  req %b hit %b miss %b read %b done %b data %02h",
                cyc, cname(dut.state), fname(dut.fetch.state),
                req, hit, miss, mem_read, done, data_out);
        end
    end

    task pulse;
        input [7:0] addr;
        integer guard;
        integer accept_at;
        integer done_at;
        integer hit_w, miss_w, read_w;
        begin
            address = addr;
            @(posedge clk);
            req <= 1'b1;
            accept_at = -1;
            done_at = -1;
            hit_w = 0;
            miss_w = 0;
            read_w = 0;
            guard = 0;
            begin : waitd
                forever begin
                    @(posedge clk);
                    #1;
                    if (req) req <= 1'b0;
                    if (dut.state != 0 && accept_at < 0)
                        accept_at = cyc;
                    if (hit) hit_w = hit_w + 1;
                    if (miss) miss_w = miss_w + 1;
                    if (mem_read) read_w = read_w + 1;
                    if (done && done_at < 0)
                        done_at = cyc;
                    guard = guard + 1;
                    if ((done && guard > 1) || guard > 40)
                        disable waitd;
                end
            end
            // One more cycle so the return to IDLE is visible in the log.
            @(posedge clk);
            #1;
            $display("SUMMARY addr %02h data %02h accept %0d done %0d latency %0d hit_cycles %0d miss_cycles %0d read_cycles %0d",
                addr, data_out, accept_at, done_at, (done_at - accept_at), hit_w, miss_w, read_w);
            @(posedge clk);
        end
    endtask

    integer k;
    integer misses, hits, reads_on_miss, reads_on_hit;
    reg saw;
    reg [7:0] seq [0:90];
    reg [6:0] len;
    reg expect_end;

    task run_list;
        input [8*16-1:0] name;
        input integer n;
        integer i;
        integer mcount;
        begin
            rst = 1'b1;
            req = 1'b0;
            repeat (3) @(posedge clk);
            rst = 1'b0;
            @(posedge clk);
            mcount = 0;
            for (i = 0; i < n; i = i + 1) begin
                address = seq[i];
                @(posedge clk);
                req <= 1'b1;
                saw = 0;
                @(posedge clk);
                req <= 1'b0;
                begin : wd
                    forever begin
                        @(posedge clk);
                        #1;
                        if (mem_read) saw = 1;
                        if (done) disable wd;
                    end
                end
                if (miss) begin
                    mcount = mcount + 1;
                    misses = misses + 1;
                    if (!saw) reads_on_hit = reads_on_hit + 1;
                    else reads_on_miss = reads_on_miss + 1;
                end else hits = hits + 1;
                if (!miss && saw) reads_on_hit = reads_on_hit + 1;
                if (data_out !== seq[i])
                    $display("DATA FAIL %02h got %02h", seq[i], data_out);
                @(posedge clk);
            end
            $display("COUNT %0s accesses %0d misses %0d hits %0d", name, n, mcount, n - mcount);
        end
    endtask

    initial begin
        cyc = 0;
        logging = 0;
        misses = 0;
        hits = 0;
        reads_on_miss = 0;
        reads_on_hit = 0;
        rst = 1;
        repeat (4) @(posedge clk);
        rst = 0;
        @(posedge clk);

        $display("---- miss trace 0x00 ----");
        logging = 1;
        pulse(8'h00);
        $display("---- hit trace 0x00 ----");
        pulse(8'h00);
        logging = 0;

        // The twelve board tests. Counts are what the RTL does.
        // temporal
        seq[0]=8'h00; seq[1]=8'h00; seq[2]=8'h00; seq[3]=8'h00; seq[4]=8'h00;
        run_list("temporal", 5);
        // spatial
        seq[0]=8'h00; seq[1]=8'h01; seq[2]=8'h02; seq[3]=8'h03;
        seq[4]=8'h04; seq[5]=8'h05; seq[6]=8'h06; seq[7]=8'h07;
        run_list("spatial", 8);
        // conflict
        seq[0]=8'h00; seq[1]=8'h10; seq[2]=8'h00; seq[3]=8'h10;
        run_list("conflict", 4);
        // capacity
        seq[0]=8'h00; seq[1]=8'h04; seq[2]=8'h08; seq[3]=8'h0C;
        seq[4]=8'h00; seq[5]=8'h04; seq[6]=8'h08; seq[7]=8'h0C;
        run_list("capacity", 8);
        // replacement
        seq[0]=8'h00; seq[1]=8'h00; seq[2]=8'h10; seq[3]=8'h00;
        run_list("replacement", 4);
        // independence
        seq[0]=8'h00; seq[1]=8'h04; seq[2]=8'h00; seq[3]=8'h04;
        run_list("independence", 4);
        // reverse
        seq[0]=8'h03; seq[1]=8'h02; seq[2]=8'h01; seq[3]=8'h00;
        run_list("reverse", 4);
        // top
        seq[0]=8'hFC; seq[1]=8'hFF;
        run_list("top", 2);

        // four victims, same construction as the board ROM
        begin : victims
            integer v, t, p;
            reg [7:0] b [0:3];
            b[0]=8'h00; b[1]=8'h04; b[2]=8'h08; b[3]=8'h0C;
            for (v = 0; v < 4; v = v + 1) begin
                p = 0;
                for (t = 0; t < 4; t = t + 1) begin
                    seq[p] = b[t]; p = p + 1;
                end
                for (t = 0; t < 4; t = t + 1) if (t != v) begin
                    seq[p] = b[t]; p = p + 1;
                end
                seq[p] = 8'h10; p = p + 1;
                for (t = 0; t < 4; t = t + 1) if (t != v) begin
                    seq[p] = b[t]; p = p + 1;
                end
                seq[p] = 8'h10; p = p + 1;
                seq[p] = b[v]; p = p + 1;
                if (v == 0) run_list("victim_00", p);
                else if (v == 1) run_list("victim_04", p);
                else if (v == 2) run_list("victim_08", p);
                else run_list("victim_0c", p);
            end
        end
        $display("TOTAL hits %0d misses %0d read_on_miss %0d read_on_hit %0d",
            hits, misses, reads_on_miss, reads_on_hit);
        $finish;
    end
endmodule
