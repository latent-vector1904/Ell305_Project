// Fully associative cache: 4 lines of 4 bytes, LRU replacement.
// Board copy of lru/src/lru_cache.v. Steps only when ce is high, so the
// 50 MHz clock can be slowed down to pulses a logic analyzer can see.
// A block may occupy any line. The tag is address[7:2]. The offset is address[1:0].
// age 0 is most recently used. age 3 is least recently used.
module lru_cache (
    input wire clk,
    input wire ce,
    input wire rst,
    input wire req,
    input wire [7:0] address,
    output reg [7:0] data_out,
    output reg hit,
    output reg miss,
    output wire mem_read,
    output reg done,
    output wire idle
);
    reg valid [0:3];
    reg [5:0] tags [0:3];
    reg [31:0] blocks [0:3];
    reg [1:0] age [0:3];

    reg [1:0] state;
    localparam IDLE = 2'd0, COMPARE = 2'd1, FETCH = 2'd2, RETURN = 2'd3;

    assign idle = (state == IDLE);

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
        .ce(ce),
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

    // An empty line is used before any valid line is evicted.
    // On a tie for oldest, the highest index wins.
    function [1:0] pick_victim;
        input unused;
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

    // Pack the four ages after touching way w. age 0 is most recently used.
    function [7:0] aged;
        input [1:0] w;
        input [1:0] a0;
        input [1:0] a1;
        input [1:0] a2;
        input [1:0] a3;
        reg [1:0] old;
        reg [1:0] n0, n1, n2, n3;
        begin
            case (w)
                2'd0: old = a0;
                2'd1: old = a1;
                2'd2: old = a2;
                default: old = a3;
            endcase
            n0 = (w == 2'd0) ? 2'd0 : ((a0 < old) ? (a0 + 2'd1) : a0);
            n1 = (w == 2'd1) ? 2'd0 : ((a1 < old) ? (a1 + 2'd1) : a1);
            n2 = (w == 2'd2) ? 2'd0 : ((a2 < old) ? (a2 + 2'd1) : a2);
            n3 = (w == 2'd3) ? 2'd0 : ((a3 < old) ? (a3 + 2'd1) : a3);
            aged = {n3, n2, n1, n0};
        end
    endfunction

    // Procedural, not a continuous assign: Icarus drops array reads
    // when a zero-input function is called from a wire.
    reg [1:0] way_hit_r;
    reg [1:0] way_miss_r;
    reg [7:0] age_hit_r;
    reg [7:0] age_fill_r;
    always @* begin
        way_hit_r = hit_way(tag_l);
        way_miss_r = pick_victim(1'b0);
        age_hit_r = aged(way_hit_r, age[0], age[1], age[2], age[3]);
        age_fill_r = aged(way, age[0], age[1], age[2], age[3]);
    end

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
        end else if (ce) begin
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
                        way <= way_hit_r;
                        age[0] <= age_hit_r[1:0];
                        age[1] <= age_hit_r[3:2];
                        age[2] <= age_hit_r[5:4];
                        age[3] <= age_hit_r[7:6];
                        hit <= 1'b1;
                        miss <= 1'b0;
                        state <= RETURN;
                    end else begin
                        way <= way_miss_r;
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
                        age[0] <= age_fill_r[1:0];
                        age[1] <= age_fill_r[3:2];
                        age[2] <= age_fill_r[5:4];
                        age[3] <= age_fill_r[7:6];
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
