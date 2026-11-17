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
