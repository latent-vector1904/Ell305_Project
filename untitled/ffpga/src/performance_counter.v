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
