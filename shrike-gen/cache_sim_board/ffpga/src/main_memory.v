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
