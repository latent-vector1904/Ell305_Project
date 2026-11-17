module main_memory (
    input wire read_en,
    input wire [7:0] address,
    output wire [7:0] data_out,
    output wire ready
);
    // The byte at an address is the address, so a wrong fill is obvious.
    assign data_out = address;
    assign ready = read_en;
endmodule
