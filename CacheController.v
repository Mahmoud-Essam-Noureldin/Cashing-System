module CacheController #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter NUM_SETS   = 4,
    parameter NUM_WAYS   = 4,
    parameter TAG_WIDTH  = 4,
    parameter WAY_BITS   = $clog2(NUM_WAYS)
)(
    input clk,
    input rst,

    // CPU Interface
    input read_en,
    input write_en,
    input [ADDR_WIDTH-1:0] address,
    input [DATA_WIDTH-1:0] write_data,
    output reg [DATA_WIDTH-1:0] read_data,
    output reg cache_hit,

    // Cache Interface
    input cache_hit_i,
    input [WAY_BITS-1:0] cache_hit_way,
    input [NUM_WAYS-1:0] dirty_way_bits, // Cache can provide all dirty bits for set
    input [NUM_WAYS-1:0] ref_way_bits,   // Cache reference bits for LRU
    output reg cache_write_en,
    output reg [WAY_BITS-1:0] cache_write_way,
    output reg [DATA_WIDTH-1:0] cache_write_data,
    output reg dirty_in,
    output reg ref_in,
    output reg [TAG_WIDTH-1:0] tag_in,

    // RAM Interface
    output reg ram_read_en,
    output reg ram_write_en,
    output reg [ADDR_WIDTH-1:0] ram_address,
    output reg [DATA_WIDTH-1:0] ram_write_data
);

    // -------- State machine --------
    localparam IDLE         = 3'd0;
    localparam CHECK_CACHE  = 3'd1;
    localparam MISS_WRITEBACK = 3'd2;
    localparam MISS_READ_RAM = 3'd3;
    localparam UPDATE_CACHE  = 3'd4;
    localparam RETURN_DATA   = 3'd5;

    reg [2:0] state;

    // -------- Extract Tag & Set Index --------
    wire [TAG_WIDTH-1:0] tag;
    wire [$clog2(NUM_SETS)-1:0] set_index;

    assign tag       = address[ADDR_WIDTH-1:ADDR_WIDTH-TAG_WIDTH];
    assign set_index = address[ADDR_WIDTH-TAG_WIDTH-1:0];

    // -------- Internal LRU selection --------
    reg [WAY_BITS-1:0] lru_way;  // Chooses which way to replace

    integer i;

    always @(*) begin
        // Find LRU way (lowest reference bit)
        lru_way = 0;
        for(i=0;i<NUM_WAYS;i=i+1) begin
            if(ref_way_bits[i] == 0)
                lru_way = i;
        end
    end

    // -------- Sequential FSM --------
    always @(posedge clk or posedge rst) begin
        if(rst)
            state <= IDLE;
        else begin
            case(state)
                IDLE: begin
                    if(read_en || write_en)
                        state <= CHECK_CACHE;
                end
                CHECK_CACHE: begin
                    if(cache_hit_i)
                        state <= RETURN_DATA;
                    else if(dirty_way_bits[lru_way])
                        state <= MISS_WRITEBACK;
                    else
                        state <= MISS_READ_RAM;
                end
                MISS_WRITEBACK: state <= MISS_READ_RAM;
                MISS_READ_RAM:    state <= UPDATE_CACHE;
                UPDATE_CACHE:     state <= RETURN_DATA;
                RETURN_DATA:      state <= IDLE;
            endcase
        end
    end

    // -------- Combinational Control Signals --------
    always @(*) begin
        // Default values
        cache_write_en   = 0;
        cache_write_way  = lru_way;
        cache_write_data = 0;
        dirty_in         = 0;
        ref_in           = 0;
        tag_in           = tag;
        ram_read_en      = 0;
        ram_write_en     = 0;
        ram_address      = address;
        ram_write_data   = 0;
        read_data        = 0;
        cache_hit        = 0;

        case(state)
            CHECK_CACHE: begin
                if(cache_hit_i) begin
                    cache_hit = 1;
                    read_data = cache_hit_way; // controller reads data from cache separately
                end
            end
            MISS_WRITEBACK: begin
                ram_write_en = 1;
                ram_address  = { /* rebuild full address from tag & set_index */ };
                ram_write_data = cache_write_data; // old cache line
            end
            MISS_READ_RAM: begin
                ram_read_en = 1;
                ram_address = address;
            end
            UPDATE_CACHE: begin
                cache_write_en  = 1;
                cache_write_way = lru_way;
                cache_write_data = (read_en) ? /* data from RAM */ 0 : write_data;
                dirty_in        = write_en ? 1 : 0;
                ref_in          = 1;
                tag_in          = tag;
            end
            RETURN_DATA: begin
                if(cache_hit_i)
                    read_data = cache_hit_way; // or data from cache read output
                else
                    read_data = /* data from RAM just loaded */ 0;
            end
        endcase
    end

endmodule
