(* top *)
module cache_sim_top (
    (* iopad_external_pin, clkbuf_inhibit *) input wire clk_in,
    (* iopad_external_pin *) output wire clk_en,
    (* iopad_external_pin *) input wire rst,
    (* iopad_external_pin *) input wire [1:0] experiment_sel,

    (* iopad_external_pin *) output wire clk_out,
    (* iopad_external_pin *) output wire cache_hit,
    (* iopad_external_pin *) output wire cache_miss,
    (* iopad_external_pin *) output wire mem_read,
    (* iopad_external_pin *) output wire request,
    (* iopad_external_pin *) output wire done,
    (* iopad_external_pin *) output wire [1:0] cache_state,

    (* iopad_external_pin *) output wire clk_out_en,
    (* iopad_external_pin *) output wire cache_hit_en,
    (* iopad_external_pin *) output wire cache_miss_en,
    (* iopad_external_pin *) output wire mem_read_en,
    (* iopad_external_pin *) output wire request_en,
    (* iopad_external_pin *) output wire done_en,
    (* iopad_external_pin *) output wire [1:0] cache_state_en
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
