module cache_controller (
    input wire clk,
    input wire ce,
    input wire rst,
    input wire req,
    input wire [7:0] address,
    input wire [3:0] addr_tag,
    input wire [1:0] addr_offset,
    input wire cache_valid,
    input wire [3:0] cache_tag,
    input wire [31:0] cache_block,
    input wire fetch_done,
    input wire [31:0] fetch_block,
    output reg cache_we,
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

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 1'b0;
            hit <= 1'b0;
            miss <= 1'b0;
            fetch_req <= 1'b0;
            cache_we <= 1'b0;
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
                    fetch_req <= 1'b0;
                    if (req)
                        state <= COMPARE;
                end
                COMPARE: begin
                    if (cache_valid && (cache_tag == addr_tag)) begin
                        hit <= 1'b1;
                        miss <= 1'b0;
                        state <= RETURN;
                    end else begin
                        hit <= 1'b0;
                        miss <= 1'b1;
                        fetch_base_addr <= {address[7:2], 2'b00};
                        fetch_req <= 1'b1;
                        state <= FETCH;
                    end
                end
                FETCH: begin
                    if (fetch_done) begin
                        fetch_req <= 1'b0;
                        cache_write_data <= fetch_block;
                        cache_we <= 1'b1;
                        state <= RETURN;
                    end
                end
                RETURN: begin
                    cache_we <= 1'b0;
                    done <= 1'b1;
                    case (addr_offset)
                        2'b00: data_out <= miss ? cache_write_data[7:0]   : cache_block[7:0];
                        2'b01: data_out <= miss ? cache_write_data[15:8]  : cache_block[15:8];
                        2'b10: data_out <= miss ? cache_write_data[23:16] : cache_block[23:16];
                        2'b11: data_out <= miss ? cache_write_data[31:24] : cache_block[31:24];
                    endcase
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                    fetch_req <= 1'b0;
                    cache_we <= 1'b0;
                end
            endcase
        end
    end
endmodule
