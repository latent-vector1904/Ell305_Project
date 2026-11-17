/**
 * @file 02_performance_counter.v
 * @brief Count accesses, hits, misses, memory bursts, and enable cycles.
 * @note Identical bytes also at fpga/cache_sim/ffpga/src/performance_counter.v, fpga/shrike_fixed/performance_counter.v.
 */

/**
 * @brief Count accesses, hits, misses, memory bursts, and enable cycles.
 *
 * An access is counted when done is high. A memory burst is counted on the rising edge of the read strobe.
 */

module performance_counter (
    input wire clk, ///< Clock.
    input wire ce, ///< Clock enable. The state machine advances only when this is high.
    input wire rst, ///< Synchronous reset.
    input wire done, ///< High when this access has produced data_out.
    input wire hit, ///< High when this access hit.
    input wire miss, ///< High when this access missed.
    input wire mem_read_en, ///< Read strobe to memory.
    output reg [15:0] total_reqs, ///< Accesses that reached done.
    output reg [15:0] total_hits, ///< Accesses that hit.
    output reg [15:0] total_misses, ///< Accesses that missed.
    output reg [15:0] mem_tx, ///< Memory bursts, counted on the rising edge of the read strobe.
    output reg [15:0] total_cycles ///< Enable cycles since reset.
);
    reg prev_mem_read;
    /**
     * @brief Count finished accesses, hits, misses, memory bursts, and enable cycles.
     */
    always @(posedge clk) begin
        if (rst) begin
            total_reqs <= 16'd0;
            total_hits <= 16'd0;
            total_misses <= 16'd0;
            mem_tx <= 16'd0;
            total_cycles <= 16'd0;
            prev_mem_read <= 1'b0;
        end else if (ce) begin
            total_cycles <= total_cycles + 1'b1;
            prev_mem_read <= mem_read_en;
            if (done) begin
                total_reqs <= total_reqs + 1'b1;
                if (hit) total_hits <= total_hits + 1'b1;
                if (miss) total_misses <= total_misses + 1'b1;
            end
            if (mem_read_en && !prev_mem_read)
                mem_tx <= mem_tx + 1'b1;
        end
    end
endmodule
