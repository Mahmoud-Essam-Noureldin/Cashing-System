module Cache #(
    parameter NUM_SETS = 4,
    parameter NUM_WAYS = 4,
    parameter DATA_WIDTH = 32,
    parameter TAG_WIDTH = 4
)(
    input clk,
    input read_en,
    input write_en,
    input [TAG_WIDTH+1:0] address, // tag + set index
    input [DATA_WIDTH-1:0] write_data,
    input [DATA_WIDTH-1:0] ram_data, // data from RAM on miss
    output reg hit,
    output reg [DATA_WIDTH-1:0] read_data
);

    // Cache storage
    reg valid [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg [TAG_WIDTH-1:0] tag_mem [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg [DATA_WIDTH-1:0] data_mem [0:NUM_SETS-1][0:NUM_WAYS-1];

    integer i;
    wire [1:0] set_index;
    wire [TAG_WIDTH-1:0] tag;

    assign set_index = address[1:0];
    assign tag = address[TAG_WIDTH+1:2];

    always @(posedge clk) begin
        hit = 0;
        read_data = 0;

        // Check for hit
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (valid[set_index][i] && tag_mem[set_index][i] == tag) begin
                hit = 1;
                read_data = data_mem[set_index][i];
                if (write_en)
                    data_mem[set_index][i] <= write_data; // write-through
            end
        end

        // On miss: copy data from RAM into first invalid way
        if (read_en && !hit) begin
            for (i = 0; i < NUM_WAYS; i = i + 1) begin
                if (!valid[set_index][i]) begin
                    valid[set_index][i] <= 1;
                    tag_mem[set_index][i] <= tag;
                    data_mem[set_index][i] <= ram_data;
                    read_data <= ram_data;
                    break;
                end
            end
        end
    end

endmodule
