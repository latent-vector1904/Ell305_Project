// Paste this entire file into the RIGHT pane (design.sv).
// Replace whatever is already in that pane. Do not keep the template module.
`timescale 1ns / 1ps

module address_decoder (
    input wire [7:0] address,
    output wire [3:0] tag,
    output wire [1:0] index,
    output wire [1:0] offset
);
    assign tag = address[7:4];
    assign index = address[3:2];
    assign offset = address[1:0];
endmodule

module test_generator (
    input wire clk,
    input wire ce,
    input wire rst,
    input wire next_req,
    input wire [1:0] exp_sel,
    output reg [7:0] address,
    output reg req_out,
    output reg done_all
);
    reg [2:0] step;

    always @(posedge clk) begin
        if (rst) begin
            step <= 3'd0;
            address <= 8'd0;
            req_out <= 1'b0;
            done_all <= 1'b0;
        end else if (ce) begin
            req_out <= 1'b0;
            if (next_req && !done_all) begin
                req_out <= 1'b1;
                case (exp_sel)
                    2'b00: address <= 8'h00;
                    2'b01: address <= {5'b00000, step};
                    2'b10: address <= (step[0] == 1'b0) ? 8'h00 : 8'h10;
                    2'b11: address <= {step[1:0], 6'b000000};
                    default: address <= 8'h00;
                endcase

                if ((exp_sel == 2'b01 && step == 3'd7) ||
                    (exp_sel != 2'b01 && step == 3'd3)) begin
                    done_all <= 1'b1;
                end else begin
                    step <= step + 1'b1;
                end
            end
        end
    end
endmodule


module cache_storage (
    input wire clk,
    input wire ce,
    input wire rst,
    input wire write_en,
    input wire [1:0] index,
    input wire [3:0] tag_in,
    input wire [31:0] block_in,
    output wire [3:0] tag_out,
    output wire [31:0] block_out,
    output wire valid_out
);
    reg [36:0] lines [0:3]; // {valid, tag, 32-bit block}
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1)
                lines[i] <= 37'd0;
        end else if (ce && write_en) begin
            lines[index] <= {1'b1, tag_in, block_in};
        end
    end

    assign valid_out = lines[index][36];
    assign tag_out = lines[index][35:32];
    assign block_out = lines[index][31:0];
endmodule


module main_memory (
    input wire read_en,
    input wire [7:0] address,
    output wire [7:0] data_out,
    output wire ready
);
    // Behavioral memory model: each byte contains its own address.
    assign data_out = address;
    assign ready = read_en;
endmodule


module block_fetch_controller (
    input wire clk,
    input wire ce,
    input wire rst,
    input wire fetch_req,
    input wire [7:0] base_address,
    input wire mem_ready,
    input wire [7:0] mem_data,
    output reg mem_read_en,
    output reg [7:0] mem_addr,
    output reg [31:0] block_out,
    output reg fetch_done
);
    reg [2:0] state;
    reg [7:0] saved_base;

    localparam IDLE  = 3'd0;
    localparam READ0 = 3'd1;
    localparam READ1 = 3'd2;
    localparam READ2 = 3'd3;
    localparam READ3 = 3'd4;
    localparam DONE  = 3'd5;

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


module performance_counter (
    input wire clk,
    input wire ce,
    input wire rst,
    input wire done,
    input wire hit,
    input wire miss,
    input wire mem_read_en,
    output reg [15:0] total_reqs,
    output reg [15:0] total_hits,
    output reg [15:0] total_misses,
    output reg [15:0] mem_tx,
    output reg [15:0] total_cycles
);
    reg prev_mem_read;
    always @(posedge clk) begin
        if (rst) begin
            total_reqs <= 16'd0;
            total_hits <= 16'd0;
            total_misses <= 16'd0;
            mem_tx <= 16'd0;
            total_cycles <= 16'd0;
            prev_mem_read <= 1'b0;
        end else if (ce) begin
            total_cycles <= total_cycles + 1'b1;
            prev_mem_read <= mem_read_en;
            if (done) begin
                total_reqs <= total_reqs + 1'b1;
                if (hit) total_hits <= total_hits + 1'b1;
                if (miss) total_misses <= total_misses + 1'b1;
            end
            if (mem_read_en && !prev_mem_read)
                mem_tx <= mem_tx + 1'b1;
        end
    end
endmodule


