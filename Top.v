module Cache_System #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter INDEX_WIDTH = 6,
    parameter TAG_WIDTH = 8,
    parameter NUM_WAYS = 4
)(
    input wire clk,
    input wire rst,
    
    // CPU Interface (The only thing the Testbench sees)
    input wire [ADDR_WIDTH-1:0] cpu_address,
    input wire [DATA_WIDTH-1:0] cpu_write_data,
    input wire cpu_read_en,
    input wire cpu_write_en,
    output wire [DATA_WIDTH-1:0] cpu_read_data,
    output wire cpu_ready // 1 = Data Ready, 0 = Stall
);

    // =====================================================
    // Internal Wires
    // =====================================================
    
    // Wires between Controller and Cache Memory
    wire [INDEX_WIDTH-1:0] cache_index;
    wire [NUM_WAYS*TAG_WIDTH-1:0]  c_r_tags;
    wire [NUM_WAYS*DATA_WIDTH-1:0] c_r_data;
    wire [NUM_WAYS-1:0]            c_r_valid;
    wire [NUM_WAYS-1:0]            c_r_dirty;
    wire [NUM_WAYS-1:0]            c_r_ref;
    
    wire c_wr_en;
    wire [NUM_WAYS-1:0] c_way_sel;
    wire [TAG_WIDTH-1:0] c_w_tag;
    wire [DATA_WIDTH-1:0] c_w_data;
    wire c_w_valid;
    wire c_w_dirty;
    wire c_update_ref;
    wire [NUM_WAYS-1:0] c_w_ref;

    // Wires between Controller and Main Memory (RAM)
    wire mem_rd_en, mem_wr_en;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [DATA_WIDTH-1:0] mem_w_data;
    wire [DATA_WIDTH-1:0] mem_r_data;

    // =====================================================
    // Module Instantiations
    // =====================================================

    // 1. The Controller (The Brain)
    CacheController #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), 
        .INDEX_WIDTH(INDEX_WIDTH), .TAG_WIDTH(TAG_WIDTH), .NUM_WAYS(NUM_WAYS)
    ) U_Controller (
        .clk(clk), .rst(rst),
        
        // CPU Side
        .cpu_address(cpu_address), .cpu_write_data(cpu_write_data),
        .cpu_read_en(cpu_read_en), .cpu_write_en(cpu_write_en),
        .cpu_read_data(cpu_read_data), .cpu_ready(cpu_ready),
        
        // Cache Side
        .cache_index(cache_index),
        .cache_r_tags(c_r_tags), .cache_r_data(c_r_data),
        .cache_r_valid(c_r_valid), .cache_r_dirty(c_r_dirty), .cache_r_ref(c_r_ref),
        .cache_wr_en(c_wr_en), .cache_way_sel(c_way_sel),
        .cache_w_tag(c_w_tag), .cache_w_data(c_w_data),
        .cache_w_valid(c_w_valid), .cache_w_dirty(c_w_dirty),
        .cache_update_ref(c_update_ref), .cache_w_ref(c_w_ref),

        // RAM Side
        .ram_read_en(mem_rd_en), .ram_write_en(mem_wr_en),
        .ram_address(mem_addr), .ram_write_data(mem_w_data),
        .ram_read_data(mem_r_data)
    );

    // 2. The Cache Memory (Fast Storage)
    Cache_Memory #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), 
        .INDEX_WIDTH(INDEX_WIDTH), .TAG_WIDTH(TAG_WIDTH), .NUM_WAYS(NUM_WAYS)
    ) U_CacheMem (
        .clk(clk), .rst(rst), .index(cache_index),
        
        // Read Ports
        .r_tags(c_r_tags), .r_data(c_r_data),
        .r_valid(c_r_valid), .r_dirty(c_r_dirty), .r_ref(c_r_ref),
        
        // Write Ports
        .wr_en(c_wr_en), .way_sel(c_way_sel),
        .w_tag(c_w_tag), .w_data(c_w_data),
        .w_valid(c_w_valid), .w_dirty(c_w_dirty),
        .update_ref(c_update_ref), .w_ref(c_w_ref)
    );

    // 3. Main Memory / RAM (Slow Storage)
    RAM #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) U_RAM (
        .clk(clk),
        .wr_en(mem_wr_en), .rd_en(mem_rd_en),
        .addr(mem_addr), .w_data(mem_w_data), .r_data(mem_r_data)
    );

endmodule