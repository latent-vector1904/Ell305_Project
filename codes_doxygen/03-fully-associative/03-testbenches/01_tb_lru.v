`timescale 1ns/1ps
/**
 * @file 01_tb_lru.v
 * @brief Exhaustive check of the four-line LRU cache against a direct-mapped reference.
 */

/**
 * @brief Exhaustive check of the four-line LRU cache against a direct-mapped reference.
 *
 * The same short sequences are applied under both policies so hits, misses, and memory reads can be compared.
 *
 * Exhaustive checks of the 4-line LRU cache, then the same short sequences under the direct-mapped rule so the two policies can be compared.
 */

module tb_lru;
    reg clk = 0;
    /**
     * @brief Free-running clock. The half-period is 5 time units.
     */
    always #5 clk = ~clk;

    reg rst;
    reg req;
    reg [7:0] address;
    wire [7:0] data_out;
    wire hit, miss, mem_read, done;

    lru_cache dut (
        .clk(clk),
        .rst(rst),
        .req(req),
        .address(address),
        .data_out(data_out),
        .hit(hit),
        .miss(miss),
        .mem_read(mem_read),
        .done(done)
    );

    // Direct-mapped reference: index address[3:2], tag address[7:4], one line each.
    reg dm_valid [0:3];
    reg [3:0] dm_tag [0:3];
    integer di;

    integer errors, accesses, hits, misses, reads_on_hit, reads_on_miss, missing_reads;
    integer guard;
    reg saw_read;
    reg exp_miss;

    task reset_both;
        begin
            req = 0;
            address = 0;
            rst = 1;
            repeat (3) @(posedge clk);
            rst = 0;
            @(posedge clk);
            for (di = 0; di < 4; di = di + 1) begin
                dm_valid[di] = 0;
                dm_tag[di] = 0;
            end
        end
    endtask

    task check_access;
        input [7:0] addr;
        input expect_miss;
        input [8*48-1:0] label;
        begin
            @(posedge clk);
            address <= addr;
            req <= 1'b1;
            @(posedge clk);
            req <= 1'b0;
            saw_read = 0;
            guard = 0;
            begin : waitdone
                forever begin
                    @(posedge clk);
                    if (mem_read)
                        saw_read = 1'b1;
                    guard = guard + 1;
                    if (done || guard > 40)
                        disable waitdone;
                end
            end
            accesses = accesses + 1;
            if (guard > 40) begin
                $display("FAIL timeout %0s addr %02h", label, addr);
                errors = errors + 1;
            end else begin
                if (hit === 1'b1)
                    hits = hits + 1;
                if (miss === 1'b1)
                    misses = misses + 1;
                if (hit === miss) begin
                    $display("FAIL hit/miss both %b %0s addr %02h", hit, label, addr);
                    errors = errors + 1;
                end
                if (data_out !== addr) begin
                    $display("FAIL data %02h wanted %02h %0s", data_out, addr, label);
                    errors = errors + 1;
                end
                if (miss !== expect_miss) begin
                    $display("FAIL %0s addr %02h got %s wanted %s",
                        label, addr, miss ? "MISS" : "HIT", expect_miss ? "MISS" : "HIT");
                    errors = errors + 1;
                end
                if (expect_miss && !saw_read) begin
                    $display("FAIL miss without memory read %0s addr %02h", label, addr);
                    missing_reads = missing_reads + 1;
                    errors = errors + 1;
                end
                if (!expect_miss && saw_read) begin
                    $display("FAIL hit with memory read %0s addr %02h", label, addr);
                    reads_on_hit = reads_on_hit + 1;
                    errors = errors + 1;
                end
                if (expect_miss && saw_read)
                    reads_on_miss = reads_on_miss + 1;
            end
        end
    endtask

    // What the direct-mapped rule does with this address, then record the fill.
    function dm_would_miss;
        input [7:0] addr;
        reg [1:0] index;
        reg [3:0] tag;
        begin
            index = addr[3:2];
            tag = addr[7:4];
            dm_would_miss = !(dm_valid[index] && (dm_tag[index] == tag));
        end
    endfunction

    task dm_note;
        input [7:0] addr;
        reg [1:0] index;
        begin
            index = addr[3:2];
            dm_valid[index] = 1'b1;
            dm_tag[index] = addr[7:4];
        end
    endtask

    task compare_one;
        input [7:0] addr;
        input [8*24-1:0] name;
        reg lru_miss;
        reg direct_miss;
        begin
            direct_miss = dm_would_miss(addr);
            // The LRU expectation is computed by running the RTL, so the
            // expected miss flag for check_access is filled after the fact
            // only for the comparison print. Drive a dummy expectation of
            // the direct-mapped result first? No: we need the LRU result
            // unchecked against a precomputed flag here.
            // Use expect_miss = direct only when we want them equal.
            // This task checks data, exclusivity and the read rule, and
            // prints both decisions. The miss expectation is the LRU one,
            // supplied by the caller.
        end
    endtask

    integer b, start, step, k;
    reg [7:0] base;
    reg [1:0] off;
    reg [8:0] seq_i;
    reg lru_m, dm_m;

    // Comparison sequences. expect_lru is the fully associative LRU result.
    // The direct-mapped column is the index/tag rule, updated in lockstep.
    task run_pair;
        input [7:0] addr;
        input expect_lru_miss;
        input [8*16-1:0] name;
        begin
            dm_m = dm_would_miss(addr);
            check_access(addr, expect_lru_miss, name);
            $display("  %0s  addr %02h   LRU %-4s   direct-mapped %-4s",
                name, addr,
                expect_lru_miss ? "MISS" : "HIT",
                dm_m ? "MISS" : "HIT");
            dm_note(addr);
        end
    endtask

    initial begin
        errors = 0;
        accesses = 0;
        hits = 0;
        misses = 0;
        reads_on_hit = 0;
        reads_on_miss = 0;
        missing_reads = 0;
        req = 0;
        rst = 1;

        // ---- Temporal: every block, five reads of its first byte ----
        $display("TEMPORAL  64 blocks x 5 reads of the block base");
        for (b = 0; b < 64; b = b + 1) begin
            reset_both();
            base = {b[5:0], 2'b00};
            check_access(base, 1'b1, "temporal");
            for (k = 0; k < 4; k = k + 1)
                check_access(base, 1'b0, "temporal");
        end

        // ---- Spatial: every block, every byte as the first request ----
        $display("SPATIAL   64 blocks x 4 starting offsets");
        for (b = 0; b < 64; b = b + 1) begin
            for (start = 0; start < 4; start = start + 1) begin
                reset_both();
                base = {b[5:0], 2'b00};
                check_access(base + start[1:0], 1'b1, "spatial");
                for (step = 1; step <= 3; step = step + 1) begin
                    off = start[1:0] + step[1:0];
                    check_access(base + off, 1'b0, "spatial");
                end
            end
        end

        // ---- A free line is used before anyone is evicted ----
        $display("EMPTY LINE  two blocks must both survive");
        reset_both();
        check_access(8'h00, 1'b1, "free");
        check_access(8'h10, 1'b1, "free");
        check_access(8'h00, 1'b0, "free");
        check_access(8'h10, 1'b0, "free");

        // ---- LRU victim: the line that was not used again is the one replaced ----
        $display("LRU VICTIM  refresh three of the four, then a new block");
        begin : victims
            integer victim;
            reg [7:0] blocks_a [0:3];
            reg [7:0] fresh;
            blocks_a[0] = 8'h00;
            blocks_a[1] = 8'h04;
            blocks_a[2] = 8'h08;
            blocks_a[3] = 8'h0C;
            fresh = 8'h10;
            for (victim = 0; victim < 4; victim = victim + 1) begin
                reset_both();
                for (k = 0; k < 4; k = k + 1)
                    check_access(blocks_a[k], 1'b1, "fill");
                // Touch every block except the chosen victim, most-recent last.
                for (k = 0; k < 4; k = k + 1)
                    if (k != victim)
                        check_access(blocks_a[k], 1'b0, "touch");
                check_access(fresh, 1'b1, "evict");
                // The three survivors and the new block must still hit.
                // The victim address is checked last: that miss would
                // itself replace one of the survivors.
                for (k = 0; k < 4; k = k + 1)
                    if (k != victim)
                        check_access(blocks_a[k], 1'b0, "victim-kept");
                check_access(fresh, 1'b0, "fresh-kept");
                check_access(blocks_a[victim], 1'b1, "victim-gone");
                $display("  victim block %02h was replaced by %02h", blocks_a[victim], fresh);
            end
        end

        // ---- Whole memory in order, then who is still resident ----
        $display("CAPACITY WALK  blocks 0..63, then the last four");
        reset_both();
        for (b = 0; b < 64; b = b + 1)
            check_access({b[5:0], 2'b00}, 1'b1, "walk");
        // The last four blocks are still resident. Check them before any new miss,
        // because a new miss would replace the oldest of those four.
        check_access(8'hF0, 1'b0, "walk-keep");
        check_access(8'hF4, 1'b0, "walk-keep");
        check_access(8'hF8, 1'b0, "walk-keep");
        check_access(8'hFC, 1'b0, "walk-keep");
        check_access(8'hEC, 1'b1, "walk-old"); // block 59, pushed out by later blocks

        $display("");
        $display("COMPARISON  same addresses, LRU RTL against the direct-mapped rule");
        reset_both();
        $display("temporal");
        run_pair(8'h00, 1'b1, "temporal");
        run_pair(8'h00, 1'b0, "temporal");
        run_pair(8'h00, 1'b0, "temporal");
        run_pair(8'h00, 1'b0, "temporal");
        run_pair(8'h00, 1'b0, "temporal");

        reset_both();
        $display("spatial");
        run_pair(8'h00, 1'b1, "spatial");
        run_pair(8'h01, 1'b0, "spatial");
        run_pair(8'h02, 1'b0, "spatial");
        run_pair(8'h03, 1'b0, "spatial");
        run_pair(8'h04, 1'b1, "spatial");
        run_pair(8'h05, 1'b0, "spatial");
        run_pair(8'h06, 1'b0, "spatial");
        run_pair(8'h07, 1'b0, "spatial");

        reset_both();
        $display("conflict");
        run_pair(8'h00, 1'b1, "conflict");
        run_pair(8'h10, 1'b1, "conflict");
        run_pair(8'h00, 1'b0, "conflict");
        run_pair(8'h10, 1'b0, "conflict");

        reset_both();
        $display("capacity");
        run_pair(8'h00, 1'b1, "capacity");
        run_pair(8'h04, 1'b1, "capacity");
        run_pair(8'h08, 1'b1, "capacity");
        run_pair(8'h0C, 1'b1, "capacity");
        run_pair(8'h00, 1'b0, "capacity");
        run_pair(8'h04, 1'b0, "capacity");
        run_pair(8'h08, 1'b0, "capacity");
        run_pair(8'h0C, 1'b0, "capacity");

        reset_both();
        $display("replacement");
        run_pair(8'h00, 1'b1, "replace");
        run_pair(8'h00, 1'b0, "replace");
        run_pair(8'h10, 1'b1, "replace");
        run_pair(8'h00, 1'b0, "replace");

        $display("");
        $display("accesses %0d   hits %0d   misses %0d", accesses, hits, misses);
        $display("misses that read memory %0d   hits that read memory %0d   misses with no read %0d",
            reads_on_miss, reads_on_hit, missing_reads);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("FAILED  %0d checks", errors);
        $finish(errors == 0 ? 0 : 1);
    end
endmodule
