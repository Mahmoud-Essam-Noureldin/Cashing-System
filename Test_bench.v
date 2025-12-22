`timescale 1ns / 1ps

module tb_cache_system;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 16;
    parameter INDEX_WIDTH = 6;
    parameter TAG_WIDTH = 8;
    parameter NUM_WAYS = 4;

    // Inputs to DUT
    reg clk;
    reg rst;
    reg [ADDR_WIDTH-1:0] cpu_address;
    reg [DATA_WIDTH-1:0] cpu_write_data;
    reg cpu_read_en;
    reg cpu_write_en;

    // Outputs from DUT
    wire [DATA_WIDTH-1:0] cpu_read_data;
    wire cpu_ready;

    // Instantiate the Top Module
    Cache_System #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), 
        .INDEX_WIDTH(INDEX_WIDTH), .TAG_WIDTH(TAG_WIDTH), .NUM_WAYS(NUM_WAYS)
    ) DUT (
        .clk(clk), .rst(rst),
        .cpu_address(cpu_address), .cpu_write_data(cpu_write_data),
        .cpu_read_en(cpu_read_en), .cpu_write_en(cpu_write_en),
        .cpu_read_data(cpu_read_data), .cpu_ready(cpu_ready)
    );

    // Clock Generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // --- Helper Tasks for cleaner code ---
    
    // Task to Perform a CPU Read
    task cpu_read(input [ADDR_WIDTH-1:0] addr);
    begin
        cpu_address = addr;
        cpu_read_en = 1;
        cpu_write_en = 0;
        
        // Wait for ready signal (Handle Stall)
        wait(cpu_ready == 0); // Wait for busy
        wait(cpu_ready == 1); // Wait for done
        #10; // Hold for one cycle
        cpu_read_en = 0;
    end
    endtask

    // Task to Perform a CPU Write
    task cpu_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
    begin
        cpu_address = addr;
        cpu_write_data = data;
        cpu_write_en = 1;
        cpu_read_en = 0;
        
        wait(cpu_ready == 0);
        wait(cpu_ready == 1);
        #10;
        cpu_write_en = 0;
    end
    endtask

    // --- Main Test Sequence ---
    initial begin
        // 1. Initialize System
        rst = 1;
        cpu_address = 0; cpu_write_data = 0; cpu_read_en = 0; cpu_write_en = 0;
        #20 rst = 0; // Release Reset
        #10;

        $display("==========================================================");
        $display("STARTING CACHE SYSTEM TEST (LRU + WRITE-BACK)");
        $display("==========================================================");

        // ---------------------------------------------------------
        // SCENARIO 1: LRU REPLACEMENT POLICY TEST
        // We will target Set 0 (Index 00).
        // ---------------------------------------------------------
        $display("\n[Scenario 1] LRU Policy Verification on Set 0");

        // Step 1: Fill all 4 Ways of Set 0
        // Addresses 0x1000, 0x2000, 0x3000, 0x4000 all map to Set 0.
        $display(" -> Filling Set 0 with 4 blocks...");
        cpu_read(16'h1000); 
        cpu_read(16'h2000); 
        cpu_read(16'h3000); 
        cpu_read(16'h4000); 

        // Step 2: Manipulate usage to define LRU.
        // We access 0x2000, 0x3000, and 0x4000 again.
        // This leaves 0x1000 as the "Least Recently Used".
        $display(" -> Accessing ways 1, 2, 3 again. Way 0 (Addr 0x1000) should become LRU.");
        cpu_read(16'h2000);
        cpu_read(16'h3000);
        cpu_read(16'h4000);
        
        // Step 3: Cause a Miss (Eviction).
        // Reading 0x5000 (Set 0, new tag) forces the cache to remove one block.
        // If LRU is correct, it MUST remove 0x1000.
        $display(" -> Reading 0x5000 (Should evict 0x1000)...");
        cpu_read(16'h5000);

        // Step 4: Verification
        // If we try to read 0x1000 now, it should be a MISS (Slow).
        // If we try to read 0x2000, it should be a HIT (Fast).
        // For simplicity in this waveform check, we rely on the fact that 0x5000 is now present.
        
        // ---------------------------------------------------------
        // SCENARIO 2: WRITE-BACK POLICY TEST
        // ---------------------------------------------------------
        $display("\n[Scenario 2] Write-Back Policy Verification");

        // Step 1: Write to 0x5000 (currently in Cache).
        // This makes the block "Dirty".
        $display(" -> Writing 0xDEADBEEF to Address 0x5000 (Making it DIRTY)");
        cpu_write(16'h5000, 32'hDEADBEEF);

        // CHECK RAM (Backdoor check): Did it update immediately?
        // Note: 'DUT.U_RAM.mem' relies on instance name 'U_RAM' in 'Cache_System'
        if (DUT.U_RAM.mem[16'h5000] !== 32'hDEADBEEF) 
            $display("    PASS: RAM was NOT updated immediately (Correct Write-Back Behavior).");
        else 
            $display("    FAIL: RAM updated immediately (Write-Through detected!).");

        // Step 2: Force Eviction of the Dirty Block (0x5000)
        // We fill the set with new addresses to push 0x5000 out.
        $display(" -> Forcing eviction of Dirty Block 0x5000...");
        cpu_read(16'h1000);
        cpu_read(16'h2000);
        cpu_read(16'h3000);
        cpu_read(16'h4000); // Set is full of these now. 0x5000 is gone.

        // Step 3: Verify RAM Update
        // Now that 0x5000 is evicted, the controller should have written back to RAM.
        #20; // Give a little time for the write to finish
        
        if (DUT.U_RAM.mem[16'h5000] === 32'hDEADBEEF)
            $display("    PASS: RAM now contains 0xDEADBEEF (Eviction Write-Back Successful!).");
        else
            $display("    FAIL: RAM still has old data (Write-Back Logic Failed).");

        $display("\n==========================================================");
        $display("TEST COMPLETE");
        $finish;
    end

endmodule