(* top *)
module cache_sim_top (
    (* iopad_external_pin, clkbuf_inhibit *) input wire clk_in,
    (* iopad_external_pin *) output wire clk_en,

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
    // Internal oscillator. clk_in must be the CLK pin and clk_en OSC Enable.
    assign clk_en = 1'b1;

    assign clk_out_en      = 1'b1;
    assign cache_hit_en    = 1'b1;
    assign cache_miss_en   = 1'b1;
    assign mem_read_en     = 1'b1;
    assign request_en      = 1'b1;
    assign done_en         = 1'b1;
    assign cache_state_en  = 2'b11;

    // One-cycle enable about 6 times per second at 50 MHz.
    reg [22:0] clk_div;
    wire slow_enable = &clk_div;

    // Hold reset for the first 256 clocks, then run. No header pin required.
    reg [7:0] por_cnt;
    wire por = (por_cnt != 8'hFF);

    // After each 4-access pass, reset the cache so the next pass misses again.
    reg in_gap;
    reg [2:0] gap;
    wire rst_run = por | in_gap;

    always @(posedge clk_in) begin
        if (por_cnt != 8'hFF)
            por_cnt <= por_cnt + 1'b1;
        if (por)
            clk_div <= 23'd0;
        else
            clk_div <= clk_div + 1'b1;
    end

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

    always @(posedge clk_in) begin
        if (por) begin
            in_gap <= 1'b0;
            gap <= 3'd0;
        end else if (slow_enable) begin
            if (!in_gap && done_all) begin
                in_gap <= 1'b1;
                gap <= 3'd0;
            end else if (in_gap) begin
                if (gap == 3'd4)
                    in_gap <= 1'b0;
                else
                    gap <= gap + 1'b1;
            end
        end
    end

    test_generator gen (
        .clk(clk_in), .ce(slow_enable), .rst(rst_run),
        .next_req((cache_state == 2'b00) && ~req && ~done && ~done_all),
        .exp_sel(2'b00), .address(address),
        .req_out(req), .done_all(done_all)
    );

    address_decoder dec (
        .address(address), .tag(tag_in), .index(index), .offset(offset)
    );

    cache_storage cache (
        .clk(clk_in), .ce(slow_enable), .rst(rst_run),
        .write_en(cache_we), .index(index),
        .tag_in(fetch_base[7:4]), .block_in(block_in),
        .tag_out(tag_out), .block_out(block_out), .valid_out(valid_out)
    );

    main_memory mem (
        .read_en(mem_read_internal), .address(mem_addr),
        .data_out(mem_data), .ready(mem_ready)
    );

    block_fetch_controller fetch (
        .clk(clk_in), .ce(slow_enable), .rst(rst_run),
        .fetch_req(fetch_req), .base_address(fetch_base),
        .mem_ready(mem_ready), .mem_data(mem_data),
        .mem_read_en(mem_read_internal), .mem_addr(mem_addr),
        .block_out(fetch_block), .fetch_done(fetch_done)
    );

    cache_controller ctrl (
        .clk(clk_in), .ce(slow_enable), .rst(rst_run), .req(req),
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
