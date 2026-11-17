/**
 * @file 01_cache_sim_top.v
 * @brief Early direct-mapped board image with a selectable experiment.
 * @note Identical bytes also at fpga/shrike_fixed/cache_sim_top.v.
 */

/**
 * @brief Early direct-mapped board image with a selectable experiment.
 *
 * experiment_sel chooses the address pattern. Reset comes from a pin. The divider produces one enable about six times a second at 50 MHz, and clk_out is only a debug waveform.
 */

(* top *)
module cache_sim_top (
    (* iopad_external_pin, clkbuf_inhibit *) input wire clk_in, ///< Board oscillator. Cache steps are gated by the slow enable.
    (* iopad_external_pin *) output wire clk_en, ///< Oscillator enable. Tied high.
    (* iopad_external_pin *) input wire rst, ///< Synchronous reset.
    (* iopad_external_pin *) input wire [1:0] experiment_sel, ///< Pin that selects the stimulus pattern. Same encoding as exp_sel.

    (* iopad_external_pin *) output wire clk_out, ///< Slow waveform for the analyzer, taken from the top divider bit.
    (* iopad_external_pin *) output wire cache_hit, ///< Hit pin for the analyzer.
    (* iopad_external_pin *) output wire cache_miss, ///< Miss pin for the analyzer.
    (* iopad_external_pin *) output wire mem_read, ///< Analyzer pin. Follows the memory-read strobe.
    (* iopad_external_pin *) output wire request, ///< Request pin. Follows the sequencer request.
    (* iopad_external_pin *) output wire done, ///< High when this access has produced data_out.
    (* iopad_external_pin *) output wire [1:0] cache_state, ///< Controller state on a pin. 0 is idle.

    (* iopad_external_pin *) output wire clk_out_en, ///< Output enable for clk_out. Tied high so the pin drives.
    (* iopad_external_pin *) output wire cache_hit_en, ///< Output enable for cache_hit. Tied high so the pin drives.
    (* iopad_external_pin *) output wire cache_miss_en, ///< Output enable for cache_miss. Tied high so the pin drives.
    (* iopad_external_pin *) output wire mem_read_en, ///< Output enable for mem_read. Tied high so the pin drives.
    (* iopad_external_pin *) output wire request_en, ///< Output enable for request. Tied high so the pin drives.
    (* iopad_external_pin *) output wire done_en, ///< Output enable for done. Tied high so the pin drives.
    (* iopad_external_pin *) output wire [1:0] cache_state_en ///< Output enable for cache_state. Tied high so the pin drives.
);
    // Enable the SLG47910 internal oscillator. Map clk_in/clk_en to
    // the OSC clock/enable functions in ForgeFPGA as required by the board flow.
    assign clk_en = 1'b1;

    // GPIO output enables: keep each associated output actively driven.
    assign clk_out_en      = 1'b1;
    assign cache_hit_en    = 1'b1;
    assign cache_miss_en   = 1'b1;
    assign mem_read_en     = 1'b1;
    assign request_en      = 1'b1;
    assign done_en         = 1'b1;
    assign cache_state_en  = 2'b11;

    // Generate a one-cycle clock-enable pulse, NOT a derived clock.
    // With 23 bits this pulse occurs once every 2^23 oscillator cycles
    // (about 5.96 pulses/second at 50 MHz).
    reg [22:0] clk_div;
    wire slow_enable = &clk_div;

    /**
     * @brief Clear the divider on reset, then count. One enable pulse occurs when every divider bit is high.
     */
    always @(posedge clk_in) begin
        if (rst)
            clk_div <= 23'd0;
        else
            clk_div <= clk_div + 1'b1;
    end

    // Debug waveform only. This signal does not clock any internal logic.
    assign clk_out = clk_div[22];

    wire [7:0] address;
    wire [7:0] data_out;
    wire [3:0] tag_out, tag_in;
    wire [1:0] index, offset;
    wire [31:0] block_in, block_out;
    wire req, valid_out, fetch_done, fetch_req, mem_ready;
    wire cache_we, done_all;
    wire [7:0] fetch_base, mem_addr, mem_data;
    wire [31:0] fetch_block;
    wire mem_read_internal;

    assign request = req;
    assign mem_read = mem_read_internal;

    test_generator gen (
        .clk(clk_in), .ce(slow_enable), .rst(rst),
        .next_req((cache_state == 2'b00) && ~req && ~done && ~done_all),
        .exp_sel(experiment_sel), .address(address),
        .req_out(req), .done_all(done_all)
    );

    address_decoder dec (
        .address(address), .tag(tag_in), .index(index), .offset(offset)
    );

    cache_storage cache (
        .clk(clk_in), .ce(slow_enable), .rst(rst),
        .write_en(cache_we), .index(index),
        .tag_in(fetch_base[7:4]), .block_in(block_in),
        .tag_out(tag_out), .block_out(block_out), .valid_out(valid_out)
    );

    main_memory mem (
        .read_en(mem_read_internal), .address(mem_addr),
        .data_out(mem_data), .ready(mem_ready)
    );

    block_fetch_controller fetch (
        .clk(clk_in), .ce(slow_enable), .rst(rst),
        .fetch_req(fetch_req), .base_address(fetch_base),
        .mem_ready(mem_ready), .mem_data(mem_data),
        .mem_read_en(mem_read_internal), .mem_addr(mem_addr),
        .block_out(fetch_block), .fetch_done(fetch_done)
    );

    cache_controller ctrl (
        .clk(clk_in), .ce(slow_enable), .rst(rst), .req(req),
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
