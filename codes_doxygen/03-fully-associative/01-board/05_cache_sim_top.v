/**
 * @file 05_cache_sim_top.v
 * @brief Fully associative LRU image for the board.
 */

/**
 * @brief Fully associative LRU image for the board.
 *
 * The sequencer and the LRU cache are the only cache blocks. Hit, miss, memory read, request, done, and phase go to analyzer pins. A slow enable stretches each step.
 */

(* top *)
module cache_sim_top #(
    parameter integer DIV_MSB = 22 ///< Top bit of the divider. The enable pulse is one cycle every 2^(DIV_MSB+1) clocks.
) (
    (* iopad_external_pin, clkbuf_inhibit *) input wire clk_in, ///< Board oscillator. Cache steps are gated by the slow enable.
    (* iopad_external_pin *) output wire clk_en, ///< Oscillator enable. Tied high.

    (* iopad_external_pin *) output wire clk_out, ///< Slow waveform for the analyzer, taken from the top divider bit.
    (* iopad_external_pin *) output wire cache_hit, ///< Hit pin for the analyzer.
    (* iopad_external_pin *) output wire cache_miss, ///< Miss pin for the analyzer.
    (* iopad_external_pin *) output wire mem_read, ///< Analyzer pin. Follows the memory-read strobe.
    (* iopad_external_pin *) output wire request, ///< Request pin. Follows the sequencer request.
    (* iopad_external_pin *) output wire done, ///< High when this access has produced data_out.
    (* iopad_external_pin *) output wire [2:0] phase, ///< Test number. The cache is cleared between tests.

    (* iopad_external_pin *) output wire clk_out_en, ///< Output enable for clk_out. Tied high so the pin drives.
    (* iopad_external_pin *) output wire cache_hit_en, ///< Output enable for cache_hit. Tied high so the pin drives.
    (* iopad_external_pin *) output wire cache_miss_en, ///< Output enable for cache_miss. Tied high so the pin drives.
    (* iopad_external_pin *) output wire mem_read_en, ///< Output enable for mem_read. Tied high so the pin drives.
    (* iopad_external_pin *) output wire request_en, ///< Output enable for request. Tied high so the pin drives.
    (* iopad_external_pin *) output wire done_en, ///< Output enable for done. Tied high so the pin drives.
    (* iopad_external_pin *) output wire [2:0] phase_en ///< Output enable for phase. Tied high so the pin drives.
);
    assign clk_en = 1'b1;
    assign clk_out_en = 1'b1;
    assign cache_hit_en = 1'b1;
    assign cache_miss_en = 1'b1;
    assign mem_read_en = 1'b1;
    assign request_en = 1'b1;
    assign done_en = 1'b1;
    assign phase_en = 3'b111;

    reg [DIV_MSB:0] clk_div;
    wire slow_enable = &clk_div;

    reg [7:0] por_cnt = 8'd0;
    wire por = (por_cnt != 8'hFF);
    wire clear_cache;
    wire rst_cache = por | clear_cache;

    /**
     * @brief Hold reset until the power-on count finishes, then pulse one enable each time the divider wraps.
     */
    always @(posedge clk_in) begin
        if (por_cnt != 8'hFF)
            por_cnt <= por_cnt + 1'b1;
        if (por)
            clk_div <= {(DIV_MSB + 1){1'b0}};
        else
            clk_div <= clk_div + 1'b1;
    end

    assign clk_out = clk_div[DIV_MSB];

    wire [7:0] address;
    wire [7:0] data_out;
    wire req;
    wire cache_idle;

    assign request = req;

    lru_seq seq (
        .clk(clk_in), .ce(slow_enable), .rst(por),
        .cache_idle(cache_idle), .done(done),
        .address(address), .req(req),
        .clear_cache(clear_cache), .phase(phase)
    );

    lru_cache cache (
        .clk(clk_in), .ce(slow_enable), .rst(rst_cache),
        .req(req), .address(address),
        .data_out(data_out),
        .hit(cache_hit), .miss(cache_miss),
        .mem_read(mem_read), .done(done),
        .idle(cache_idle)
    );
endmodule
