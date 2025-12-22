module CacheController #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter INDEX_WIDTH = 6,
    parameter TAG_WIDTH = 8,
    parameter NUM_WAYS = 4
)(
    input clk,
    input rst,

    // CPU Interface
    input [ADDR_WIDTH-1:0] cpu_address,
    input [DATA_WIDTH-1:0] cpu_write_data,
    input cpu_read_en,
    input cpu_write_en,
    output reg [DATA_WIDTH-1:0] cpu_read_data,
    output reg cpu_ready,

    // Cache Memory Interface
    output wire [INDEX_WIDTH-1:0] cache_index,
    input [NUM_WAYS*TAG_WIDTH-1:0] cache_r_tags,
    input [NUM_WAYS*DATA_WIDTH-1:0] cache_r_data, 
    input [NUM_WAYS-1:0] cache_r_valid,
    input [NUM_WAYS-1:0] cache_r_dirty,
    input [NUM_WAYS-1:0] cache_r_ref,
    
    output reg cache_wr_en,
    output reg [NUM_WAYS-1:0] cache_way_sel,
    output reg [TAG_WIDTH-1:0] cache_w_tag,
    output reg [DATA_WIDTH-1:0] cache_w_data,
    output reg cache_w_valid,
    output reg cache_w_dirty,
    output reg cache_update_ref,
    output reg [NUM_WAYS-1:0] cache_w_ref,

    // RAM Interface
    output reg ram_read_en,
    output reg ram_write_en,
    output reg [ADDR_WIDTH-1:0] ram_address,
    output reg [DATA_WIDTH-1:0] ram_write_data,
    input [DATA_WIDTH-1:0] ram_read_data
);

    // States
    localparam IDLE = 0, CHECK = 1, WRITEBACK = 2, ALLOCATE = 3, WAIT_RAM = 4, UPDATE = 5;
    reg [2:0] state;

    // --- FIX: Use Internal Wire for Index ---
    wire [INDEX_WIDTH-1:0] index_internal;
    
    assign index_internal = cpu_address[INDEX_WIDTH+1 : 2];
    assign cache_index = index_internal; // Output drives from internal wire
    
    wire [TAG_WIDTH-1:0] cpu_tag = cpu_address[ADDR_WIDTH-1 : ADDR_WIDTH-TAG_WIDTH];

    // Internal Variables
    reg hit;
    reg [NUM_WAYS-1:0] hit_way;      
    reg [NUM_WAYS-1:0] victim_way;   
    reg [DATA_WIDTH-1:0] hit_data;   
    reg [DATA_WIDTH-1:0] victim_data;
    reg [TAG_WIDTH-1:0]  victim_tag;

    integer i;

    // --- Combinational HIT / VICTIM Logic ---
    always @(*) begin
        // 1. Detect Hit
        hit = 0;
        hit_way = 0;
        hit_data = 0;
        for(i=0; i<NUM_WAYS; i=i+1) begin
            if(cache_r_valid[i] && (cache_r_tags[(i+1)*TAG_WIDTH-1 -: TAG_WIDTH] == cpu_tag)) begin
                hit = 1;
                hit_way[i] = 1; 
                hit_data = cache_r_data[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            end
        end

        // 2. Select Victim (Simple First-Zero Ref Bit)
        victim_way = 4'b0001; // Default
        if(cache_r_ref[0] == 0) victim_way = 1;
        else if(cache_r_ref[1] == 0) victim_way = 2;
        else if(cache_r_ref[2] == 0) victim_way = 4;
        else if(cache_r_ref[3] == 0) victim_way = 8;
        
        // Extract Victim Info for Writeback
        victim_data = 0;
        victim_tag = 0;
        for(i=0; i<NUM_WAYS; i=i+1) begin
            if(victim_way[i]) begin
                victim_data = cache_r_data[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                victim_tag  = cache_r_tags[(i+1)*TAG_WIDTH-1 -: TAG_WIDTH];
            end
        end
    end

    // --- FSM ---
    always @(posedge clk or posedge rst) begin
        if(rst) state <= IDLE;
        else begin
            case(state)
                IDLE: if(cpu_read_en || cpu_write_en) state <= CHECK;
                
                CHECK: begin
                    if(hit) state <= IDLE; 
                    else begin
                        if(|(victim_way & cache_r_dirty)) state <= WRITEBACK;
                        else state <= ALLOCATE;
                    end
                end
                
                WRITEBACK: state <= ALLOCATE;
                ALLOCATE:  state <= WAIT_RAM;
                WAIT_RAM:  state <= UPDATE;
                UPDATE:    state <= CHECK; 
            endcase
        end
    end

    // --- Output Logic ---
    always @(*) begin
        // Defaults
        cpu_ready = 0; cpu_read_data = 0;
        cache_wr_en = 0; cache_way_sel = 0; cache_w_tag = 0; 
        cache_w_data = 0; cache_w_valid = 0; cache_w_dirty = 0;
        cache_update_ref = 0; cache_w_ref = cache_r_ref; 
        ram_read_en = 0; ram_write_en = 0; ram_address = 0; ram_write_data = 0;

        case(state)
            IDLE: cpu_ready = 1;

            CHECK: begin
                if(hit) begin
                    cpu_ready = 1;
                    
                    cache_update_ref = 1;
                    cache_w_ref = cache_r_ref | hit_way;

                    if(cpu_read_en) begin
                        cpu_read_data = hit_data; 
                    end
                    else if(cpu_write_en) begin
                        cache_wr_en = 1;
                        cache_way_sel = hit_way;
                        cache_w_data = cpu_write_data;
                        cache_w_tag = cpu_tag;
                        cache_w_valid = 1;
                        cache_w_dirty = 1; 
                    end
                end else begin
                    // Reset LRU bits if all are 1
                    if(cache_r_ref == 4'b1111) begin
                        cache_update_ref = 1;
                        cache_w_ref = 0; 
                    end
                end
            end

            WRITEBACK: begin
                ram_write_en = 1;
                // --- FIX: Use index_internal here ---
                ram_address = {victim_tag, index_internal, 2'b00}; 
                ram_write_data = victim_data;
            end

            ALLOCATE: begin
                ram_read_en = 1;
                ram_address = cpu_address; 
            end
            
            UPDATE: begin
                cache_wr_en = 1;
                cache_way_sel = victim_way;
                cache_w_tag = cpu_tag;
                cache_w_data = ram_read_data;
                cache_w_valid = 1;
                cache_w_dirty = 0; 
            end
        endcase
    end
endmodule
