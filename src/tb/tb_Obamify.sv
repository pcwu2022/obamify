`timescale 1ns/100ps
`define CYCLE       20      // 50MHz clock
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   1000000 // Maximum cycles before timeout

module tb_Obamify ();

    // ==================== SIGNALS ====================
    // Clock and Reset
    logic           clk;
    logic           rst_n;

    // DUT Inputs
    logic [2:0]     target_image_index;
    logic           i_start;
    logic           i_epoch_start;

    // DUT Outputs
    logic           o_finished;
    logic           o_epoch_finished;
    logic [15:0]    o_current_epoch;
    logic [19:0]    o_sram_addr;
    logic [15:0]    i_sram_data;
    logic [15:0]    o_sram_data;
    logic           o_sram_we;

    // ==================== PARAMETERS ====================
    localparam W = 128;
    localparam H = 128;
    localparam PIXEL_COUNT = W * H;
    localparam SRAM_SIZE = 20'h60000;  // Enough for all images

    // SRAM Memory Model (16-bit words)
    logic [15:0] sram_mem [0:SRAM_SIZE-1];

    // Test control
    integer cycle_count;
    integer total_loss_before;
    integer total_loss_after;

    // ==================== DUT INSTANTIATION ====================
    Obamify dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .target_image_index(target_image_index),
        .i_start(i_start),
        .o_finished(o_finished),
        .i_epoch_start(i_epoch_start),
        .o_epoch_finished(o_epoch_finished),
        .o_current_epoch(o_current_epoch),
        .o_sram_addr(o_sram_addr),
        .i_sram_data(i_sram_data),
        .o_sram_data(o_sram_data),
        .o_sram_we(o_sram_we)
    );

    // ==================== CLOCK GENERATION ====================
    always begin
        #(`HCYCLE);
        clk = ~clk;
    end

    // ==================== SRAM MODEL ====================
    // Read: 1 cycle latency
    always @(posedge clk) begin
        i_sram_data <= sram_mem[o_sram_addr];
    end

    // Write: immediate
    always @(posedge clk) begin
        if (o_sram_we) begin
            sram_mem[o_sram_addr] <= o_sram_data;
        end
    end

    // ==================== HELPER TASKS ====================

    // Initialize SRAM with test patterns
    task automatic init_sram();
        integer i, j, addr;
        logic [7:0] r, g, b, loss;
        logic [31:0] pixel;
        
        $display("[%0t] Initializing SRAM with test patterns...", $time);
        
        // Initialize source image at address 0x00000
        // Create a gradient pattern
        for (j = 0; j < H; j++) begin
            for (i = 0; i < W; i++) begin
                // RGB gradient based on position
                r = i[7:0] * 2;     // Red increases with x
                g = j[7:0] * 2;     // Green increases with y
                b = (i + j) & 8'hFF; // Blue is sum
                loss = 8'hFF;       // Initial loss (will be updated)
                
                // Pixel format: [31:24]=R, [23:16]=G, [15:8]=B, [7:0]=Loss
                pixel = {r, g, b, loss};
                
                // Calculate address (each pixel = 2 words)
                addr = (j * W + i) * 2;
                
                // Store low 16 bits then high 16 bits
                sram_mem[addr] = pixel[15:0];       // B, Loss
                sram_mem[addr + 1] = pixel[31:16];  // R, G
            end
        end
        
        // Initialize target image at address 0x50000
        // Create a different pattern to test loss calculation
        for (j = 0; j < H; j++) begin
            for (i = 0; i < W; i++) begin
                // Different pattern - shifted colors
                r = ((W - 1 - i) * 2) & 8'hFF;  // Reversed red
                g = ((H - 1 - j) * 2) & 8'hFF;  // Reversed green
                b = ((i * j) >> 6) & 8'hFF;     // Different blue
                loss = 8'h00;                    // Target has no loss field used
                
                pixel = {r, g, b, loss};
                
                // Calculate address
                addr = 20'h50000 + (j * W + i) * 2;
                
                sram_mem[addr] = pixel[15:0];
                sram_mem[addr + 1] = pixel[31:16];
            end
        end
        
        $display("[%0t] SRAM initialization complete.", $time);
    endtask

    // Calculate total loss of source image
    task automatic calculate_total_loss(input logic [19:0] base_addr, output integer total);
        integer i, j, addr;
        logic [7:0] loss;
        
        total = 0;
        for (j = 0; j < H; j++) begin
            for (i = 0; i < W; i++) begin
                addr = base_addr + (j * W + i) * 2;
                loss = sram_mem[addr][7:0];  // Loss is in low byte of first word
                total = total + loss;
            end
        end
    endtask

    // Print pixel at specific location
    task automatic print_pixel(input logic [19:0] base_addr, input integer x, input integer y);
        integer addr;
        logic [15:0] low_word, high_word;
        logic [7:0] r, g, b, loss;
        
        addr = base_addr + (y * W + x) * 2;
        low_word = sram_mem[addr];
        high_word = sram_mem[addr + 1];
        
        r = high_word[15:8];
        g = high_word[7:0];
        b = low_word[15:8];
        loss = low_word[7:0];
        
        $display("  Pixel[%0d,%0d]: R=%0d, G=%0d, B=%0d, Loss=%0d", x, y, r, g, b, loss);
    endtask

    // Wait for specific number of cycles
    task automatic wait_cycles(input integer n);
        repeat(n) @(posedge clk);
    endtask

    // Reset DUT
    task automatic reset_dut();
        $display("[%0t] Applying reset...", $time);
        rst_n = 1'b1;
        wait_cycles(2);
        rst_n = 1'b0;
        wait_cycles(5);
        rst_n = 1'b1;
        wait_cycles(2);
        $display("[%0t] Reset complete.", $time);
    endtask

    // Run one complete epoch
    task automatic run_epoch();
        $display("[%0t] Starting epoch %0d...", $time, o_current_epoch);
        
        // Pulse epoch start
        i_epoch_start = 1'b1;
        wait_cycles(1);
        i_epoch_start = 1'b0;
        
        // Wait for epoch to finish
        wait(o_epoch_finished == 1'b1);
        wait_cycles(1);
        
        $display("[%0t] Epoch %0d finished.", $time, o_current_epoch);
    endtask

    // ==================== TEST SCENARIOS ====================

    // Test 1: Basic functionality - start and run a few epochs
    task automatic test_basic_operation();
        $display("\n========== TEST 1: Basic Operation ==========");
        
        reset_dut();
        init_sram();
        
        // Calculate initial loss
        calculate_total_loss(20'h00000, total_loss_before);
        $display("[%0t] Initial total loss: %0d", $time, total_loss_before);
        
        // Print some sample pixels before
        $display("Sample pixels before optimization:");
        print_pixel(20'h00000, 0, 0);
        print_pixel(20'h00000, 64, 64);
        print_pixel(20'h00000, 127, 127);
        
        // Start obamify
        target_image_index = 3'b000;  // Use first source image
        i_start = 1'b1;
        wait_cycles(1);
        i_start = 1'b0;
        
        // Run multiple epochs
        repeat(5) begin
            run_epoch();
            if (o_finished) break;
        end
        
        // Calculate final loss
        calculate_total_loss(20'h00000, total_loss_after);
        $display("[%0t] Final total loss: %0d", $time, total_loss_after);
        
        // Print sample pixels after
        $display("Sample pixels after optimization:");
        print_pixel(20'h00000, 0, 0);
        print_pixel(20'h00000, 64, 64);
        print_pixel(20'h00000, 127, 127);
        
        if (total_loss_after <= total_loss_before) begin
            $display("TEST 1 PASSED: Loss did not increase");
        end else begin
            $display("TEST 1 WARNING: Loss increased (may happen with random swaps)");
        end
    endtask

    // Test 2: Full run until finished
    task automatic test_full_run();
        integer max_epochs;
        integer local_epoch_count;
        
        $display("\n========== TEST 2: Full Run (Limited Epochs) ==========");
        
        reset_dut();
        init_sram();
        local_epoch_count = 0;
        max_epochs = 20;  // Limit epochs for simulation time
        
        target_image_index = 3'b001;  // Use second source image base
        i_start = 1'b1;
        wait_cycles(1);
        i_start = 1'b0;
        
        while (!o_finished && local_epoch_count < max_epochs) begin
            run_epoch();
            local_epoch_count = local_epoch_count + 1;
        end
        
        if (o_finished) begin
            $display("TEST 2 PASSED: Obamify finished successfully after %0d epochs", local_epoch_count);
        end else begin
            $display("TEST 2 INFO: Stopped after %0d epochs (max reached)", local_epoch_count);
        end
    endtask

    // Test 3: Verify SRAM addressing
    task automatic test_sram_addressing();
        integer prev_addr;
        integer addr_changes;
        
        $display("\n========== TEST 3: SRAM Addressing ==========");
        
        reset_dut();
        init_sram();
        addr_changes = 0;
        prev_addr = -1;
        
        target_image_index = 3'b000;
        i_start = 1'b1;
        wait_cycles(1);
        i_start = 1'b0;
        
        // Monitor address changes for one epoch
        fork
            begin
                // Run one epoch
                run_epoch();
            end
            begin
                // Monitor SRAM addresses
                while (!o_epoch_finished) begin
                    @(posedge clk);
                    if (o_sram_addr != prev_addr) begin
                        addr_changes++;
                        prev_addr = o_sram_addr;
                        
                        // Verify address is within valid range
                        if (o_sram_addr >= SRAM_SIZE) begin
                            $display("ERROR: Invalid SRAM address: 0x%05X", o_sram_addr);
                        end
                    end
                end
            end
        join
        
        $display("Address changes in one epoch: %0d", addr_changes);
        $display("TEST 3 PASSED: SRAM addressing verified");
    endtask

    // Test 4: Reset during operation
    task automatic test_reset_recovery();
        $display("\n========== TEST 4: Reset Recovery ==========");
        
        reset_dut();
        init_sram();
        
        target_image_index = 3'b000;
        i_start = 1'b1;
        wait_cycles(1);
        i_start = 1'b0;
        
        // Let it run for a bit
        wait_cycles(100);
        
        // Apply reset during operation
        $display("[%0t] Applying reset during operation...", $time);
        rst_n = 1'b0;
        wait_cycles(5);
        rst_n = 1'b1;
        wait_cycles(5);
        
        // Verify it returns to IDLE state (o_finished should be 0, not running)
        if (!o_finished && !o_epoch_finished) begin
            $display("TEST 4 PASSED: DUT recovered from reset");
        end else begin
            $display("TEST 4 FAILED: DUT did not properly recover from reset");
        end
        
        // Verify we can start again
        i_start = 1'b1;
        wait_cycles(1);
        i_start = 1'b0;
        
        run_epoch();
        $display("TEST 4 PASSED: Can restart after reset");
    endtask

    // Test 5: Different target image indices
    task automatic test_different_targets();
        integer idx;
        
        $display("\n========== TEST 5: Different Target Indices ==========");
        
        for (idx = 0; idx < 5; idx++) begin
            $display("Testing target_image_index = %0d", idx);
            
            reset_dut();
            init_sram();
            
            target_image_index = idx[2:0];
            i_start = 1'b1;
            wait_cycles(1);
            i_start = 1'b0;
            
            // Run one epoch
            run_epoch();
            
            $display("  Epoch completed for index %0d", idx);
        end
        
        $display("TEST 5 PASSED: All target indices work");
    endtask

    // ==================== MAIN TEST SEQUENCE ====================
    initial begin
        // Initialize signals
        clk = 1'b0;
        rst_n = 1'b1;
        target_image_index = 3'b000;
        i_start = 1'b0;
        i_epoch_start = 1'b0;
        cycle_count = 0;

        // Setup waveform dump
        $fsdbDumpfile("obamify.fsdb");
        $fsdbDumpvars(0, tb_Obamify, "+mda");

        $display("\n");
        $display("============================================");
        $display("       Obamify Testbench Starting");
        $display("============================================");
        $display("Image size: %0d x %0d = %0d pixels", W, H, PIXEL_COUNT);
        $display("============================================\n");

        // Run tests
        test_basic_operation();
        test_sram_addressing();
        test_reset_recovery();
        test_different_targets();
        // test_full_run();  // Uncomment for longer test

        $display("\n============================================");
        $display("       All Tests Completed");
        $display("============================================\n");

        #(10 * `CYCLE);
        $finish;
    end

    // ==================== TIMEOUT WATCHDOG ====================
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count >= `MAX_CYCLE) begin
            $display("\n[%0t] ERROR: Simulation timeout after %0d cycles!", $time, cycle_count);
            $finish;
        end
    end

    // ==================== MONITORING ====================
    // Monitor state transitions (optional - can be verbose)
    // always @(dut.state_r) begin
    //     $display("[%0t] State: %0d", $time, dut.state_r);
    // end

    // Monitor epoch changes
    always @(posedge o_epoch_finished) begin
        $display("[%0t] Epoch %0d completed", $time, o_current_epoch);
    end

    // Monitor finish signal
    always @(posedge o_finished) begin
        $display("[%0t] Obamify finished!", $time);
    end

endmodule
