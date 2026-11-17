
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