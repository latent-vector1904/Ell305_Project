/**
 * @file 01_block_fetch_controller.v
 * @brief Read four consecutive memory bytes into one cache line.
 * @note Identical bytes also at fpga/cache_sim/ffpga/src/block_fetch_controller.v, fpga/shrike_fixed/block_fetch_controller.v.
 */

/**
 * @brief Read four consecutive memory bytes into one cache line.
 *
 * Early fill controller. It accepts a new request whenever it is idle, including the cycle it reports done.
 */

module block_fetch_controller (
    input wire clk, ///< Clock.
    input wire ce, ///< Clock enable. The state machine advances only when this is high.
    input wire rst, ///< Synchronous reset.
    input wire fetch_req, ///< Start a four-byte fill while this controller is idle.
    input wire [7:0] base_address, ///< Address whose four-byte line should be read.
    input wire mem_ready, ///< Memory data is valid this cycle.
    input wire [7:0] mem_data, ///< Byte returned by memory.
    output reg mem_read_en, ///< Read strobe to memory.
    output reg [7:0] mem_addr, ///< Byte address presented to memory.
    output reg [31:0] block_out, ///< Four bytes read from memory. The lowest address is in bits [7:0].
    output reg fetch_done ///< High for the step on which the four-byte fill completes.
);
    reg [2:0] state;
    reg [7:0] saved_base;

    localparam IDLE  = 3'd0;
    localparam READ0 = 3'd1;
    localparam READ1 = 3'd2;
    localparam READ2 = 3'd3;
    localparam READ3 = 3'd4;
    localparam DONE  = 3'd5;

    /**
     * @brief Read four consecutive bytes into the line, then pulse fetch_done.
     */
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            mem_read_en <= 1'b0;
            mem_addr <= 8'd0;
            block_out <= 32'd0;
            fetch_done <= 1'b0;
            saved_base <= 8'd0;
        end else if (ce) begin
            fetch_done <= 1'b0;
            case (state)
                IDLE: begin
                    mem_read_en <= 1'b0;
                    if (fetch_req) begin
                        saved_base <= {base_address[7:2], 2'b00};
                        mem_addr <= {base_address[7:2], 2'b00};
                        mem_read_en <= 1'b1;
                        state <= READ0;
                    end
                end
                READ0: if (mem_ready) begin
                    block_out[7:0] <= mem_data;
                    mem_addr <= saved_base + 8'd1;
                    state <= READ1;
                end
                READ1: if (mem_ready) begin
                    block_out[15:8] <= mem_data;
                    mem_addr <= saved_base + 8'd2;
                    state <= READ2;
                end
                READ2: if (mem_ready) begin
                    block_out[23:16] <= mem_data;
                    mem_addr <= saved_base + 8'd3;
                    state <= READ3;
                end
                READ3: if (mem_ready) begin
                    block_out[31:24] <= mem_data;
                    mem_read_en <= 1'b0;
                    state <= DONE;
                end
                DONE: begin
                    fetch_done <= 1'b1;
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                    mem_read_en <= 1'b0;
                end
            endcase
        end
    end
endmodule
