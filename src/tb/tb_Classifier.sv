`timescale 1ns/100ps

module tb_Classifier;

    // Clock and reset
    logic        i_clk;
    logic        i_rst_n;
    logic        i_start;
    logic [15:0] i_SRAM_data;
    logic [19:0] o_SRAM_addr;
    logic        o_SRAM_enable;
    logic [2:0]  o_result;
    logic        o_done;

    // Clock period
    localparam CLK_PERIOD = 20; // 50 MHz

    // Image size
    localparam IMG_WIDTH  = 128;
    localparam IMG_HEIGHT = 128;
    localparam PIXELS_PER_IMG = IMG_WIDTH * IMG_HEIGHT;

    // SRAM model - 6 images (1 source + 5 targets), each 128x128 pixels, 2 reads per pixel
    // Address format: {13-bit image_id, 7-bit y, 7-bit x, 1-bit counter}
    logic [15:0] sram_mem [0:6*PIXELS_PER_IMG*2-1];

    // DUT instantiation
    Classifier dut (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .i_start      (i_start),
        .i_SRAM_data  (i_SRAM_data),
        .o_SRAM_addr  (o_SRAM_addr),
        .o_SRAM_enable(o_SRAM_enable),
        .o_result     (o_result),
        .o_done       (o_done)
    );

    // Clock generation
    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD/2) i_clk = ~i_clk;
    end

    // Convert hierarchical address to linear address for SRAM model
    function automatic int get_linear_addr(input logic [19:0] addr);
        logic [12:0] img_id;
        logic [6:0]  y, x;
        logic        cnt;
        img_id = addr[19:15];
        y      = addr[14:8];
        x      = addr[7:1];
        cnt    = addr[0];
        return img_id * PIXELS_PER_IMG * 2 + y * IMG_WIDTH * 2 + x * 2 + cnt;
    endfunction

    // SRAM data output - combinational (same cycle as address)
    assign i_SRAM_data = sram_mem[get_linear_addr(o_SRAM_addr)];

    // Task to initialize SRAM with test patterns
    task automatic init_sram_with_pattern(
        input int img_id,
        input logic [7:0] r_base,
        input logic [7:0] g_base,
        input logic [7:0] b_base
    );
        int base_addr;
        base_addr = img_id * PIXELS_PER_IMG * 2;
        for (int y = 0; y < IMG_HEIGHT; y++) begin
            for (int x = 0; x < IMG_WIDTH; x++) begin
                // First read: R[7:0] in upper byte, G[7:0] in lower byte
                sram_mem[base_addr + y*IMG_WIDTH*2 + x*2]     = {r_base, g_base};
                // Second read: B[7:0] in upper byte (lower byte unused)
                sram_mem[base_addr + y*IMG_WIDTH*2 + x*2 + 1] = {b_base, 8'h00};
            end
        end
    endtask

    // Task to initialize SRAM with random data
    task automatic init_sram_random(input int img_id, input int seed);
        int base_addr;
        base_addr = img_id * PIXELS_PER_IMG * 2;
        for (int y = 0; y < IMG_HEIGHT; y++) begin
            for (int x = 0; x < IMG_WIDTH; x++) begin
                sram_mem[base_addr + y*IMG_WIDTH*2 + x*2]     = $urandom(seed + y*IMG_WIDTH + x);
                sram_mem[base_addr + y*IMG_WIDTH*2 + x*2 + 1] = $urandom(seed + y*IMG_WIDTH + x + 1000);
            end
        end
    endtask

    // Task to copy image data
    task automatic copy_image(input int src_id, input int dst_id);
        int src_base, dst_base;
        src_base = src_id * PIXELS_PER_IMG * 2;
        dst_base = dst_id * PIXELS_PER_IMG * 2;
        for (int i = 0; i < PIXELS_PER_IMG * 2; i++) begin
            sram_mem[dst_base + i] = sram_mem[src_base + i];
        end
    endtask

    // Task to run classification
    task automatic run_classification();
        @(posedge i_clk);
        i_start = 1'b1;
        @(posedge i_clk);
        i_start = 1'b0;
        
        // Wait for done
        while (!o_done) begin
            @(posedge i_clk);
        end
        
        $display("Classification complete. Result: %0d", o_result);
    endtask

    initial begin
        $fsdbDumpfile("classifier.fsdb");
        $fsdbDumpvars(0, tb_Classifier, "+mda");
    end

    // Test sequence
    initial begin
        $display("===========================================");
        $display("       Classifier Testbench Started");
        $display("===========================================");

        // Initialize signals
        i_rst_n = 1'b0;
        i_start = 1'b0;

        // Reset sequence
        repeat(5) @(posedge i_clk);
        i_rst_n = 1'b1;
        repeat(5) @(posedge i_clk);

        // =========================================
        // Test Case 1: Source matches Image 1 exactly
        // =========================================
        $display("\n--- Test Case 1: Source matches Target 1 ---");
        
        // Initialize all images with different patterns
        init_sram_with_pattern(0, 8'h80, 8'h80, 8'h80); // Source
        init_sram_with_pattern(1, 8'h80, 8'h80, 8'h80); // Target 1 - same as source
        init_sram_with_pattern(2, 8'hFF, 8'h00, 8'h00); // Target 2 - different
        init_sram_with_pattern(3, 8'h00, 8'hFF, 8'h00); // Target 3 - different
        init_sram_with_pattern(4, 8'h00, 8'h00, 8'hFF); // Target 4 - different
        init_sram_with_pattern(5, 8'hFF, 8'hFF, 8'hFF); // Target 5 - different
        
        run_classification();
        
        if (o_result == 3'd0) begin
            $display("PASS: Correctly identified Target 1 (result=%0d)", o_result);
        end else begin
            $display("FAIL: Expected result=0, got result=%0d", o_result);
        end

        // Reset for next test
        i_rst_n = 1'b0;
        repeat(5) @(posedge i_clk);
        i_rst_n = 1'b1;
        repeat(5) @(posedge i_clk);

        // =========================================
        // Test Case 2: Source matches Image 3 exactly
        // =========================================
        $display("\n--- Test Case 2: Source matches Target 3 ---");
        
        init_sram_with_pattern(0, 8'h40, 8'h60, 8'hA0); // Source
        init_sram_with_pattern(1, 8'hFF, 8'h00, 8'h00); // Target 1
        init_sram_with_pattern(2, 8'h00, 8'hFF, 8'h00); // Target 2
        init_sram_with_pattern(3, 8'h40, 8'h60, 8'hA0); // Target 3 - same as source
        init_sram_with_pattern(4, 8'h00, 8'h00, 8'hFF); // Target 4
        init_sram_with_pattern(5, 8'hFF, 8'hFF, 8'hFF); // Target 5
        
        run_classification();
        
        if (o_result == 3'd2) begin
            $display("PASS: Correctly identified Target 3 (result=%0d)", o_result);
        end else begin
            $display("FAIL: Expected result=2, got result=%0d", o_result);
        end

        // Reset for next test
        i_rst_n = 1'b0;
        repeat(5) @(posedge i_clk);
        i_rst_n = 1'b1;
        repeat(5) @(posedge i_clk);

        // =========================================
        // Test Case 3: Source matches Image 5 exactly
        // =========================================
        $display("\n--- Test Case 3: Source matches Target 5 ---");
        
        init_sram_with_pattern(0, 8'hC0, 8'hC0, 8'hC0); // Source
        init_sram_with_pattern(1, 8'h10, 8'h20, 8'h30); // Target 1
        init_sram_with_pattern(2, 8'h40, 8'h50, 8'h60); // Target 2
        init_sram_with_pattern(3, 8'h70, 8'h80, 8'h90); // Target 3
        init_sram_with_pattern(4, 8'hA0, 8'hB0, 8'hC0); // Target 4
        init_sram_with_pattern(5, 8'hC0, 8'hC0, 8'hC0); // Target 5 - same as source
        
        run_classification();
        
        if (o_result == 3'd4) begin
            $display("PASS: Correctly identified Target 5 (result=%0d)", o_result);
        end else begin
            $display("FAIL: Expected result=4, got result=%0d", o_result);
        end

        // Reset for next test
        i_rst_n = 1'b0;
        repeat(5) @(posedge i_clk);
        i_rst_n = 1'b1;
        repeat(5) @(posedge i_clk);

        // =========================================
        // Test Case 4: Source closest to Image 2
        // =========================================
        $display("\n--- Test Case 4: Source closest to Target 2 ---");
        
        init_sram_with_pattern(0, 8'h82, 8'h82, 8'h82); // Source
        init_sram_with_pattern(1, 8'h00, 8'h00, 8'h00); // Target 1 - far
        init_sram_with_pattern(2, 8'h80, 8'h80, 8'h80); // Target 2 - closest
        init_sram_with_pattern(3, 8'hFF, 8'hFF, 8'hFF); // Target 3 - far
        init_sram_with_pattern(4, 8'h40, 8'h40, 8'h40); // Target 4 - medium
        init_sram_with_pattern(5, 8'hC0, 8'hC0, 8'hC0); // Target 5 - medium
        
        run_classification();
        
        if (o_result == 3'd1) begin
            $display("PASS: Correctly identified Target 2 as closest (result=%0d)", o_result);
        end else begin
            $display("FAIL: Expected result=1, got result=%0d", o_result);
        end

        // Reset for next test
        i_rst_n = 1'b0;
        repeat(5) @(posedge i_clk);
        i_rst_n = 1'b1;
        repeat(5) @(posedge i_clk);

        // =========================================
        // Test Case 5: Random images with known best match
        // =========================================
        $display("\n--- Test Case 5: Random source, copy to Target 4 ---");
        
        init_sram_random(0, 12345); // Random source
        init_sram_random(1, 11111);
        init_sram_random(2, 22222);
        init_sram_random(3, 33333);
        copy_image(0, 4);           // Target 4 = exact copy of source
        init_sram_random(5, 55555);
        
        run_classification();
        
        if (o_result == 3'd3) begin
            $display("PASS: Correctly identified Target 4 (result=%0d)", o_result);
        end else begin
            $display("FAIL: Expected result=3, got result=%0d", o_result);
        end

        // =========================================
        // Summary
        // =========================================
        $display("\n===========================================");
        $display("       Classifier Testbench Complete");
        $display("===========================================");
        
        #100;
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000000; // 100ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

    // Monitor state transitions (optional - for debugging)
    logic [3:0] prev_state;
    always_ff @(posedge i_clk) begin
        prev_state <= dut.state_r;
        if (prev_state != dut.state_r) begin
            case (dut.state_r)
                4'd0: $display("[%0t] State: IDLE", $time);
                4'd1: $display("[%0t] State: SRC (x=%0d, y=%0d)", $time, dut.x_cnt_r, dut.y_cnt_r);
                4'd2: $display("[%0t] State: IMG1", $time);
                4'd3: $display("[%0t] State: IMG2", $time);
                4'd4: $display("[%0t] State: IMG3", $time);
                4'd5: $display("[%0t] State: IMG4", $time);
                4'd6: $display("[%0t] State: IMG5", $time);
                4'd7: $display("[%0t] State: COMP", $time);
                4'd8: $display("[%0t] State: DONE", $time);
            endcase
        end
    end

    // Dump waveforms
    initial begin
        $dumpfile("tb_Classifier.vcd");
        $dumpvars(0, tb_Classifier);
    end

endmodule
