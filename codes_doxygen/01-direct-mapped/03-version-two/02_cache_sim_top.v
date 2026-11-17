/**
 * @file 02_cache_sim_top.v
 * @brief Direct-mapped board image for the temporal and spatial tests.
 */

/**
 * @brief Direct-mapped board image for the temporal and spatial tests.
 *
 * Same cache as version three, with locality_seq in place of the exam ROM. The temporal pin tells the analyzer which pass is running.
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
    (* iopad_external_pin *) output wire temporal, ///< High during the five reads of address 0, low during the walk from 0 to 7.

    (* iopad_external_pin *) output wire clk_out_en, ///< Output enable for clk_out. Tied high so the pin drives.
    (* iopad_external_pin *) output wire cache_hit_en, ///< Output enable for cache_hit. Tied high so the pin drives.
    (* iopad_external_pin *) output wire cache_miss_en, ///< Output enable for cache_miss. Tied high so the pin drives.
    (* iopad_external_pin *) output wire mem_read_en, ///< Output enable for mem_read. Tied high so the pin drives.
    (* iopad_external_pin *) output wire request_en, ///< Output enable for request. Tied high so the pin drives.
    (* iopad_external_pin *) output wire done_en, ///< Output enable for done. Tied high so the pin drives.
    (* iopad_external_pin *) output wire temporal_en ///< Output enable for temporal. Tied high so the pin drives.
);
    assign clk_en = 1'b1;
    assign clk_out_en = 1'b1;
    assign cache_hit_en = 1'b1;
    assign cache_miss_en = 1'b1;
    assign mem_read_en = 1'b1;
    assign request_en = 1'b1;
    assign done_en = 1'b1;
    assign temporal_en = 1'b1;

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
    wire [3:0] tag_out, tag_in;
    wire [1:0] index, offset;
    wire [31:0] block_in, block_out;
    wire req, valid_out, fetch_done, fetch_req, mem_ready;
    wire cache_we;
    wire [7:0] fetch_base, mem_addr, mem_data;
    wire [31:0] fetch_block;
    wire mem_read_internal;
    wire [1:0] cache_state;

    assign request = req;
    assign mem_read = mem_read_internal;

    locality_seq seq (
        .clk(clk_in), .ce(slow_enable), .rst(por),
        .cache_idle(cache_state == 2'b00), .done(done),
        .address(address), .req(req),
        .clear_cache(clear_cache), .temporal(temporal)
    );

    address_decoder dec (
        .address(address), .tag(tag_in), .index(index), .offset(offset)
    );

    cache_storage cache (
        .clk(clk_in), .ce(slow_enable), .rst(rst_cache),
        .write_en(cache_we), .index(index),
        .tag_in(fetch_base[7:4]), .block_in(block_in),
        .tag_out(tag_out), .block_out(block_out), .valid_out(valid_out)
    );

    main_memory mem (
        .read_en(mem_read_internal), .address(mem_addr),
        .data_out(mem_data), .ready(mem_ready)
    );

    block_fetch_controller fetch (
        .clk(clk_in), .ce(slow_enable), .rst(rst_cache),
        .fetch_req(fetch_req), .base_address(fetch_base),
        .mem_ready(mem_ready), .mem_data(mem_data),
        .mem_read_en(mem_read_internal), .mem_addr(mem_addr),
        .block_out(fetch_block), .fetch_done(fetch_done)
    );

    cache_controller ctrl (
        .clk(clk_in), .ce(slow_enable), .rst(rst_cache), .req(req),
        .address(address), .addr_tag(tag_in), .addr_offset(offset),
        .cache_valid(valid_out), .cache_tag(tag_out),
        .cache_block(block_out), .fetch_done(fetch_done),
        .fetch_block(fetch_block), .cache_we(cache_we),
        .cache_write_data(block_in), .fetch_req(fetch_req),
        .fetch_base_addr(fetch_base), .data_out(data_out),
        .done(done), .hit(cache_hit), .miss(cache_miss),
        .debug_state(cache_state)
    );
endmodule
