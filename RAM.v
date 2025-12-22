module RAM #(
    parameter DATA_WIDTH = 32,      // Data width as per table
    parameter ADDR_WIDTH = 16       // Address width as per table
)(
    input wire clk,
    input wire wr_en,               // Write Enable
    input wire rd_en,               // Read Enable
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] w_data,
    output reg [DATA_WIDTH-1:0] r_data
);

    // Memory depth: 2^16 = 65,536 entries
    localparam DEPTH = 1 << ADDR_WIDTH;

    // Memory Array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        // Write Operation
        if (wr_en) begin
            mem[addr] <= w_data;
        end
        
        // Read Operation
        if (rd_en) begin
            r_data <= mem[addr];
        end
    end
    
    // --- INITIALIZATION FOR TESTING ---
    integer i;
    initial begin
        // Fill RAM with a pattern: Data = Address
        // Example: Address 0x0004 contains Data 0x00000004
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = i; 
        end
    end

endmodule