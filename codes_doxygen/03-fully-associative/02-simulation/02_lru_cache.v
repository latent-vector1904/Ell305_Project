/**
 * @file 02_lru_cache.v
 * @brief Fully associative cache of four lines with LRU replacement.
 */

/**
 * @brief Fully associative cache of four lines with LRU replacement.
 *
 * Simulation copy. It steps on every clock, with no clock enable. The tag is address[7:2]. Age 0 is most recently used. An empty line is preferred to an eviction.
 *
 * Fully associative cache: 4 lines of 4 bytes, LRU replacement. A block may occupy any line. The tag is address[7:2]. The offset is address[1:0]. age 0 is most recently used. age 3 is least recently used.
 */

module lru_cache (
    input wire clk, ///< Clock.
    input wire rst, ///< Synchronous reset.
    input wire req, ///< Access request. Accepted while the controller is idle.
    input wire [7:0] address, ///< Byte address in the 256-byte memory.
    output reg [7:0] data_out, ///< Byte selected by the offset. On a correct fill it equals the address.
    output reg hit, ///< High when this access hit.
    output reg miss, ///< High when this access missed.
    output reg mem_read, ///< High while the fill is reading memory.
    output reg done ///< High when this access has produced data_out.
);
    reg valid [0:3];
    reg [5:0] tags [0:3];
    reg [31:0] blocks [0:3];
    reg [1:0] age [0:3];

    reg [1:0] state;
    localparam IDLE = 2'd0, COMPARE = 2'd1, FETCH = 2'd2, RETURN = 2'd3;

    reg [1:0] way;
    reg [1:0] off_l;
    reg [5:0] tag_l;

    wire fetch_req_w;
    reg fetch_req;
    wire fetch_done;
    wire [31:0] fetch_block;
    wire [7:0] fetch_base;
    wire mem_read_en;
    wire [7:0] mem_addr;
    wire [7:0] mem_data;
    wire mem_ready;

    assign fetch_req_w = fetch_req;
    assign fetch_base = {tag_l, 2'b00};
    assign mem_read = mem_read_en;

    main_memory mem (
        .read_en(mem_read_en),
        .address(mem_addr),
        .data_out(mem_data),
        .ready(mem_ready)
    );

    block_fetch_controller fetch (
        .clk(clk),
        .rst(rst),
        .fetch_req(fetch_req_w),
        .base_address(fetch_base),
        .mem_ready(mem_ready),
        .mem_data(mem_data),
        .mem_read_en(mem_read_en),
        .mem_addr(mem_addr),
        .block_out(fetch_block),
        .fetch_done(fetch_done)
    );

    function [1:0] hit_way;
        input [5:0] tag;
        integer j;
        begin
            hit_way = 2'd0;
            for (j = 0; j < 4; j = j + 1)
                if (valid[j] && (tags[j] == tag))
                    hit_way = j[1:0];
        end
    endfunction

    function is_hit;
        input [5:0] tag;
        integer j;
        begin
            is_hit = 1'b0;
            for (j = 0; j < 4; j = j + 1)
                if (valid[j] && (tags[j] == tag))
                    is_hit = 1'b1;
        end
    endfunction

    // An empty line is used before any valid line is evicted.
    function [1:0] pick_victim;
        integer j;
        reg found;
        reg [1:0] best;
        reg [1:0] oldest;
        begin
            found = 1'b0;
            best = 2'd0;
            oldest = 2'd0;
            for (j = 0; j < 4; j = j + 1) begin
                if (!valid[j] && !found) begin
                    best = j[1:0];
                    found = 1'b1;
                end
            end
            if (!found) begin
                for (j = 0; j < 4; j = j + 1) begin
                    if (age[j] >= oldest) begin
                        oldest = age[j];
                        best = j[1:0];
                    end
                end
            end
            pick_victim = best;
        end
    endfunction

    task touch;
        input [1:0] w;
        integer j;
        reg [1:0] old;
        begin
            old = age[w];
            for (j = 0; j < 4; j = j + 1) begin
                if (j[1:0] == w)
                    age[j] <= 2'd0;
                else if (age[j] < old)
                    age[j] <= age[j] + 2'd1;
            end
        end
    endtask

    function [7:0] byte_at;
        input [31:0] word;
        input [1:0] off;
        begin
            case (off)
                2'b00: byte_at = word[7:0];
                2'b01: byte_at = word[15:8];
                2'b10: byte_at = word[23:16];
                default: byte_at = word[31:24];
            endcase
        end
    endfunction

    integer i;
    /**
     * @brief Idle, compare, fill, return. A hit refreshes that line. A miss fills an empty line, or the oldest line.
     */
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 1'b0;
            hit <= 1'b0;
            miss <= 1'b0;
            fetch_req <= 1'b0;
            data_out <= 8'd0;
            way <= 2'd0;
            off_l <= 2'd0;
            tag_l <= 6'd0;
            for (i = 0; i < 4; i = i + 1) begin
                valid[i] <= 1'b0;
                tags[i] <= 6'd0;
                blocks[i] <= 32'd0;
                age[i] <= i[1:0];
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    hit <= 1'b0;
                    miss <= 1'b0;
                    fetch_req <= 1'b0;
                    if (req) begin
                        tag_l <= address[7:2];
                        off_l <= address[1:0];
                        state <= COMPARE;
                    end
                end
                COMPARE: begin
                    if (is_hit(tag_l)) begin
                        way <= hit_way(tag_l);
                        touch(hit_way(tag_l));
                        hit <= 1'b1;
                        miss <= 1'b0;
                        state <= RETURN;
                    end else begin
                        way <= pick_victim();
                        hit <= 1'b0;
                        miss <= 1'b1;
                        fetch_req <= 1'b1;
                        state <= FETCH;
                    end
                end
                FETCH: begin
                    if (fetch_done) begin
                        fetch_req <= 1'b0;
                        valid[way] <= 1'b1;
                        tags[way] <= tag_l;
                        blocks[way] <= fetch_block;
                        touch(way);
                        state <= RETURN;
                    end
                end
                RETURN: begin
                    data_out <= byte_at(miss ? fetch_block : blocks[way], off_l);
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
