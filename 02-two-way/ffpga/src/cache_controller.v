// Same four states as the direct-mapped controller, so a hit is still
// COMPARE then RETURN, and a miss still waits out one four-byte fill.
// Both ways of the selected set are compared in the one COMPARE cycle.
module cache_controller (
    input wire clk,
    input wire ce,
    input wire rst,
    input wire req,
    input wire [7:0] address,
    input wire [4:0] addr_tag,
    input wire [1:0] addr_offset,
    input wire valid0,
    input wire valid1,
    input wire [4:0] tag0,
    input wire [4:0] tag1,
    input wire [31:0] block0,
    input wire [31:0] block1,
    input wire lru_way,
    input wire fetch_done,
    input wire [31:0] fetch_block,
    output reg cache_we,
    output reg cache_touch,
    output reg use_way,
    output reg [31:0] cache_write_data,
    output reg fetch_req,
    output reg [7:0] fetch_base_addr,
    output reg [7:0] data_out,
    output reg done,
    output reg hit,
    output reg miss,
    output wire [1:0] debug_state
);
    reg [1:0] state;
    localparam IDLE = 2'd0, COMPARE = 2'd1, FETCH = 2'd2, RETURN = 2'd3;
    assign debug_state = state;

    wire hit0 = valid0 && (tag0 == addr_tag);
    wire hit1 = valid1 && (tag1 == addr_tag);
    // An empty way is used before the least-recently-used way.
    wire victim = !valid0 ? 1'b0 : (!valid1 ? 1'b1 : lru_way);

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 1'b0;
            hit <= 1'b0;
            miss <= 1'b0;
            fetch_req <= 1'b0;
            cache_we <= 1'b0;
            cache_touch <= 1'b0;
            use_way <= 1'b0;
            cache_write_data <= 32'd0;
            fetch_base_addr <= 8'd0;
            data_out <= 8'd0;
        end else if (ce) begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    hit <= 1'b0;
                    miss <= 1'b0;
                    cache_we <= 1'b0;
                    cache_touch <= 1'b0;
                    fetch_req <= 1'b0;
                    if (req)
                        state <= COMPARE;
                end
                COMPARE: begin
                    if (hit0 || hit1) begin
                        hit <= 1'b1;
                        miss <= 1'b0;
                        use_way <= hit0 ? 1'b0 : 1'b1;
                        cache_touch <= 1'b1;
                        state <= RETURN;
                    end else begin
                        hit <= 1'b0;
                        miss <= 1'b1;
                        use_way <= victim;
                        cache_touch <= 1'b0;
                        fetch_base_addr <= {address[7:2], 2'b00};
                        fetch_req <= 1'b1;
                        state <= FETCH;
                    end
                end
                FETCH: begin
                    cache_touch <= 1'b0;
                    if (fetch_done) begin
                        fetch_req <= 1'b0;
                        cache_write_data <= fetch_block;
                        cache_we <= 1'b1;
                        state <= RETURN;
                    end
                end
                RETURN: begin
                    cache_we <= 1'b0;
                    cache_touch <= 1'b0;
                    done <= 1'b1;
                    case (addr_offset)
                        2'b00: data_out <= miss ? cache_write_data[7:0]
                                                : (use_way ? block1[7:0] : block0[7:0]);
                        2'b01: data_out <= miss ? cache_write_data[15:8]
                                                : (use_way ? block1[15:8] : block0[15:8]);
                        2'b10: data_out <= miss ? cache_write_data[23:16]
                                                : (use_way ? block1[23:16] : block0[23:16]);
                        2'b11: data_out <= miss ? cache_write_data[31:24]
                                                : (use_way ? block1[31:24] : block0[31:24]);
                    endcase
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                    fetch_req <= 1'b0;
                    cache_we <= 1'b0;
                    cache_touch <= 1'b0;
                end
            endcase
        end
    end
endmodule
