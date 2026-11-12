// 2-way set-associative split of an 8-bit address.
// 2 sets, 2 ways, 4-byte lines: 16 bytes, the same capacity as the direct-mapped cache.
module address_decoder (
    input wire [7:0] address,
    output wire [4:0] tag,
    output wire index,
    output wire [1:0] offset
);
    assign tag    = address[7:3];
    assign index  = address[2];
    assign offset = address[1:0];
endmodule
