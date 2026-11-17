(* top *)
module cache_sim_top #(
    parameter integer DIV_MSB = 22
) (
    (* iopad_external_pin, clkbuf_inhibit *) input wire clk_in,
    (* iopad_external_pin *) output wire clk_en,

    (* iopad_external_pin *) output wire clk_out,
    (* iopad_external_pin *) output wire cache_hit,
    (* iopad_external_pin *) output wire cache_miss,
    (* iopad_external_pin *) output wire mem_read,
    (* iopad_external_pin *) output wire request,
    (* iopad_external_pin *) output wire done,
    (* iopad_external_pin *) output wire [2:0] phase,

    (* iopad_external_pin *) output wire clk_out_en,
    (* iopad_external_pin *) output wire cache_hit_en,
    (* iopad_external_pin *) output wire cache_miss_en,
    (* iopad_external_pin *) output wire mem_read_en,
    (* iopad_external_pin *) output wire request_en,
    (* iopad_external_pin *) output wire done_en,
    (* iopad_external_pin *) output wire [2:0] phase_en
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
