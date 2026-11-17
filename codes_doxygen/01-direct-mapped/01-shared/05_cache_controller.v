/**
 * @file 05_cache_controller.v
 * @brief Direct-mapped hit and miss controller.
 * @note Identical bytes also at fpga/version two/ffpga/src/cache_controller.v, fpga/untitled/ffpga/src/cache_controller.v, fpga/cache_sim/ffpga/src/cache_controller.v, fpga/shrike_fixed/cache_controller.v.
 */

/**
 * @brief Direct-mapped hit and miss controller.
 *
 * The states are idle, compare, fetch, and return. A valid line whose tag matches skips the fill. A miss asks for the aligned four-byte line, writes it, and returns the byte at addr_offset. A hit takes the compare and return steps. A miss also waits for the fill.
 */

module cache_controller (
    input wire clk, ///< Clock.
    input wire ce, ///< Clock enable. The state machine advances only when this is high.
    input wire rst, ///< Synchronous reset.
    input wire req, ///< Access request. Accepted while the controller is idle.
    input wire [7:0] address, ///< Byte address in the 256-byte memory.
    input wire [3:0] addr_tag, ///< Tag of the request. address[7:4].
    input wire [1:0] addr_offset, ///< Offset of the request. address[1:0].
    input wire cache_valid, ///< Indexed line is valid.
    input wire [3:0] cache_tag, ///< Tag stored in the indexed line.
    input wire [31:0] cache_block, ///< Four bytes stored in the indexed line.
    input wire fetch_done, ///< High for the step on which the four-byte fill completes.
    input wire [31:0] fetch_block, ///< Four bytes returned by the fill. The lowest address is in bits [7:0].
    output reg cache_we, ///< Write the filled line into the cache.
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

    /**
     * @brief Idle, compare, fill, return. A matching tag skips the fill. A miss writes the fetched line and returns the requested byte.
     */
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
