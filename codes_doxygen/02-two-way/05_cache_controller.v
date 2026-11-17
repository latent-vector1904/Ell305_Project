/**
 * @file 05_cache_controller.v
 * @brief Two-way controller with the same four states as the direct-mapped one.
 */

/**
 * @brief Two-way controller with the same four states as the direct-mapped one.
 *
 * Both ways of the selected set are compared in the one compare cycle. An empty way is used before the least-recently-used way. A hit is still compare then return, and a miss still waits for one four-byte fill.
 *
 * Same four states as the direct-mapped controller, so a hit is still COMPARE then RETURN, and a miss still waits out one four-byte fill. Both ways of the selected set are compared in the one COMPARE cycle.
 */

module cache_controller (
    input wire clk, ///< Clock.
    input wire ce, ///< Clock enable. The state machine advances only when this is high.
    input wire rst, ///< Synchronous reset.
    input wire req, ///< Access request. Accepted while the controller is idle.
    input wire [7:0] address, ///< Byte address in the 256-byte memory.
    input wire [4:0] addr_tag, ///< Tag of the request. address[7:3].
    input wire [1:0] addr_offset, ///< Offset of the request. address[1:0].
    input wire valid0, ///< Way 0 of the selected set holds a valid line.
    input wire valid1, ///< Way 1 of the selected set holds a valid line.
    input wire [4:0] tag0, ///< Tag stored in way 0.
    input wire [4:0] tag1, ///< Tag stored in way 1.
    input wire [31:0] block0, ///< Four-byte line stored in way 0.
    input wire [31:0] block1, ///< Four-byte line stored in way 1.
    input wire lru_way, ///< Way replaced when both ways of the set are valid.
    input wire fetch_done, ///< High for the step on which the four-byte fill completes.
    input wire [31:0] fetch_block, ///< Four bytes returned by the fill. The lowest address is in bits [7:0].
    output reg cache_we, ///< Write the filled line into the cache.
    output reg cache_touch, ///< Mark use_way as most recently used.
    output reg use_way, ///< Way that hit, or the victim way on a miss.
    output reg [31:0] cache_write_data, ///< Line written on a miss.
    output reg fetch_req, ///< Ask the fetch controller to read one aligned line.
    output reg [7:0] fetch_base_addr, ///< Aligned line address. The low two bits are zero.
    output reg [7:0] data_out, ///< Byte selected by the offset. On a correct fill it equals the address.
    output reg done, ///< High when this access has produced data_out.
    output reg hit, ///< High when this access hit.
    output reg miss, ///< High when this access missed.
    output wire [1:0] debug_state ///< Controller state. 0 idle, 1 compare, 2 fetch, 3 return.
);
    reg [1:0] state;
    localparam IDLE = 2'd0, COMPARE = 2'd1, FETCH = 2'd2, RETURN = 2'd3;
    assign debug_state = state;

    wire hit0 = valid0 && (tag0 == addr_tag);
    wire hit1 = valid1 && (tag1 == addr_tag);
    // An empty way is used before the least-recently-used way.
    wire victim = !valid0 ? 1'b0 : (!valid1 ? 1'b1 : lru_way);

    /**
     * @brief Compare both ways in one cycle. A hit marks that way recently used. A miss fills an empty way, or the least-recently-used way.
     */
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
