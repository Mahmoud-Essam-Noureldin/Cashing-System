module Cache_Memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,  
    parameter INDEX_WIDTH = 6,  
    parameter TAG_WIDTH = 8,
    parameter NUM_WAYS = 4
)(
    input clk,
    input rst,
    input [INDEX_WIDTH-1:0] index,

    // Read Ports
    output wire [NUM_WAYS*TAG_WIDTH-1:0]  r_tags,
    output wire [NUM_WAYS*DATA_WIDTH-1:0] r_data,
    output wire [NUM_WAYS-1:0]            r_valid,
    output wire [NUM_WAYS-1:0]            r_dirty,
    output wire [NUM_WAYS-1:0]            r_ref,

    // Write Ports
    input wire wr_en,
    input wire [NUM_WAYS-1:0] way_sel,
    input wire [TAG_WIDTH-1:0] w_tag,
    input wire [DATA_WIDTH-1:0] w_data,
    input wire w_valid,
    input wire w_dirty,
    
    // LRU Update Port
    input wire update_ref,
    input wire [NUM_WAYS-1:0] w_ref
);

    // Internal Memory Storage
    reg [TAG_WIDTH-1:0]  tags  [0:(1<<INDEX_WIDTH)-1][0:NUM_WAYS-1];
    reg [DATA_WIDTH-1:0] data  [0:(1<<INDEX_WIDTH)-1][0:NUM_WAYS-1];
    reg                  valid [0:(1<<INDEX_WIDTH)-1][0:NUM_WAYS-1];
    reg                  dirty [0:(1<<INDEX_WIDTH)-1][0:NUM_WAYS-1];
    reg                  ref_b [0:(1<<INDEX_WIDTH)-1][0:NUM_WAYS-1];

    genvar i;
    generate
        for(i=0; i<NUM_WAYS; i=i+1) begin : OUTPUT_LOOP
            assign r_tags[(i+1)*TAG_WIDTH-1 : i*TAG_WIDTH]   = tags[index][i];
            assign r_data[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] = data[index][i];
            assign r_valid[i]                                = valid[index][i];
            assign r_dirty[i]                                = dirty[index][i];
            assign r_ref[i]                                  = ref_b[index][i];
        end
    endgenerate

    integer k, m;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for(k=0; k<(1<<INDEX_WIDTH); k=k+1) 
                for(m=0; m<NUM_WAYS; m=m+1) begin
                    valid[k][m] <= 0;
                    dirty[k][m] <= 0;
                    ref_b[k][m] <= 0;
                end
        end else begin
            if(wr_en) begin
                for(m=0; m<NUM_WAYS; m=m+1) begin
                    if(way_sel[m]) begin
                        data[index][m]  <= w_data;
                        tags[index][m]  <= w_tag;
                        valid[index][m] <= w_valid;
                        dirty[index][m] <= w_dirty;
                    end
                end
            end
            if(update_ref) begin
                for(m=0; m<NUM_WAYS; m=m+1) begin
                    ref_b[index][m] <= w_ref[m];
                end
            end
        end
    end
endmodule
