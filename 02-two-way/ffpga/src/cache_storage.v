// Two sets, two ways. A line is a valid bit, a 5-bit tag and four bytes.
// lru[set] is the way replaced when both ways are valid. 0 is most recently used's partner.
module cache_storage (
    input wire clk,
    input wire ce,
    input wire rst,
    input wire write_en,
    input wire touch,
    input wire way,
    input wire index,
    input wire [4:0] tag_in,
    input wire [31:0] block_in,
    output wire valid0,
    output wire valid1,
    output wire [4:0] tag0,
    output wire [4:0] tag1,
    output wire [31:0] block0,
    output wire [31:0] block1,
    output wire lru_way
);
    reg [37:0] lines [0:1][0:1];
    reg lru [0:1];
    integer s, w;

    always @(posedge clk) begin
        if (rst) begin
            for (s = 0; s < 2; s = s + 1) begin
                lru[s] <= 1'b0;
                for (w = 0; w < 2; w = w + 1)
                    lines[s][w] <= 38'd0;
            end
        end else if (ce && write_en) begin
            lines[index][way] <= {1'b1, tag_in, block_in};
            lru[index] <= ~way;
        end else if (ce && touch) begin
            lru[index] <= ~way;
        end
    end

    assign valid0  = lines[index][0][37];
    assign tag0    = lines[index][0][36:32];
    assign block0  = lines[index][0][31:0];
    assign valid1  = lines[index][1][37];
    assign tag1    = lines[index][1][36:32];
    assign block1  = lines[index][1][31:0];
    assign lru_way = lru[index];
endmodule
