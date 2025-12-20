`timescale 1ns/1ps

module tb_Camera;

    // Clock and Reset
    logic clk_50mhz;
    logic rst_n;
    
    // I2C signals
    logic i2c_sclk;
    wire  i2c_sdat;
    logic i2c_sdat_drive;
    logic i2c_sdat_value;
    
    // Camera GPIO signals
    logic [35:0] gpio;
    logic pixclk;
    logic [11:0] cam_data;
    logic lval, fval, strobe;
    logic xclkin;
    logic trigger;
    
    // Camera control signals
    logic zoom_mode_sw;
    logic exposure_adj;
    logic exposure_dec_p;
    
    // Camera capture outputs
    logic [11:0] capture_data;
    logic [9:0] x_cnt, y_cnt;
    logic [31:0] frame_cnt;
    logic dval;
    
    // Camera raw2RGB outputs
    logic [7:0] rgb_red, rgb_green, rgb_blue;
    logic [15:0] rgb_x, rgb_y;
    logic rgb_dval;
    
    // Test control
    integer error_count;
    integer test_count;
    
    // I2C tri-state handling
    assign i2c_sdat = i2c_sdat_drive ? i2c_sdat_value : 1'bz;
    
    //===========================================
    // DUT Instantiations
    //===========================================
    
    // Camera I2C Configuration Module
    Camera_I2C_config u_i2c_config (
        .iCLK(clk_50mhz),
        .iRST_N(rst_n),
        .iZOOM_MODE_SW(zoom_mode_sw),
        .iEXPOSURE_ADJ(exposure_adj),
        .iEXPOSURE_DEC_p(exposure_dec_p),
        .I2C_SCLK(i2c_sclk),
        .I2C_SDAT(i2c_sdat)
    );
    
    // Camera Capture Module
    Camera_capture u_capture (
        .iDATA(cam_data),
        .iFVAL(fval),
        .iLVAL(lval),
        .iSTART(trigger),
        .iEND(1'b0),
        .iCLK(pixclk),
        .iRST(rst_n),
        .oDATA(capture_data),
        .oX_Cnt(x_cnt),
        .oY_Cnt(y_cnt),
        .oFrame_Cnt(frame_cnt),
        .oDVAL(dval)
    );
    
    // Camera Raw to RGB Conversion Module
    Camera_raw2RGB u_raw2rgb (
        .iCLK(pixclk),
        .iRST(rst_n),
        .iData(capture_data),
        .iDval(dval),
        .iX_Cnt({6'd0, x_cnt}),
        .iY_Cnt({6'd0, y_cnt}),
        .oRed(rgb_red),
        .oGreen(rgb_green),
        .oBlue(rgb_blue),
        .o_x(rgb_x),
        .o_y(rgb_y),
        .oDval(rgb_dval)
    );
    
    //===========================================
    // Clock Generation
    //===========================================
    
    // 50MHz system clock (20ns period)
    initial begin
        clk_50mhz = 0;
        forever #10 clk_50mhz = ~clk_50mhz;
    end
    
    // 25MHz pixel clock (40ns period) - typical for camera
    initial begin
        pixclk = 0;
        forever #20 pixclk = ~pixclk;
    end
    
    //===========================================
    // I2C Slave Simulation (ACK generation)
    //===========================================
    
    logic [7:0] i2c_bit_counter;
    logic i2c_active;
    
    initial begin
        i2c_sdat_drive = 0;
        i2c_sdat_value = 1;
        i2c_bit_counter = 0;
        i2c_active = 0;
    end
    
    // Simple I2C slave that ACKs every byte
    always @(negedge i2c_sclk or negedge rst_n) begin
        if (!rst_n) begin
            i2c_sdat_drive <= 0;
            i2c_sdat_value <= 1;
            i2c_bit_counter <= 0;
        end else begin
            i2c_bit_counter <= i2c_bit_counter + 1;
            
            // ACK bits come at positions 9, 18, 27, 36
            if (i2c_bit_counter == 8 || i2c_bit_counter == 17 || 
                i2c_bit_counter == 26 || i2c_bit_counter == 35) begin
                i2c_sdat_drive <= 1;  // Drive ACK
                i2c_sdat_value <= 0;  // ACK = 0
            end else begin
                i2c_sdat_drive <= 0;  // Release line
            end
            
            // Reset counter after full transaction
            if (i2c_bit_counter >= 40) begin
                i2c_bit_counter <= 0;
            end
        end
    end
    
    //===========================================
    // Camera Data Pattern Generation
    //===========================================
    
    localparam int FRAME_ROWS = 256;
    localparam int FRAME_COLS = 256;

    task automatic generate_frame;
        integer r, c;
        begin
            $display("[%0t] Generating camera frame: %0d x %0d", $time, FRAME_ROWS, FRAME_COLS);
            
            // Frame valid pulse
            @(negedge pixclk);
            fval <= 1'b1;
            
            for (r = 0; r < FRAME_ROWS; r++) begin
                @(negedge pixclk);
                lval <= 1'b1;
                
                for (c = 0; c < FRAME_COLS; c++) begin
                    @(negedge pixclk);
                    // Generate a gradient pattern
                    cam_data <= (r * 16 + c) % 4096;
                end
                
                @(negedge pixclk);
                lval <= 1'b0;
                
                // H-blanking period
                repeat(10) @(negedge pixclk);
            end
            
            @(negedge pixclk);
            fval <= 1'b0;
            
            // V-blanking period
            repeat(20) @(negedge pixclk);
            
            $display("[%0t] Frame generation complete", $time);
        end
    endtask
    
    //===========================================
    // Test Monitoring Tasks
    //===========================================
    
    task check_i2c_transaction;
        integer timeout;
        begin
            $display("[%0t] Checking I2C transaction...", $time);
            timeout = 0;
            
            // Wait for I2C activity (START condition: SDAT falls while SCLK is high)
            wait(i2c_sclk == 1'b0 || timeout > 100000);
            
            if (timeout > 100000) begin
                $display("[%0t] ERROR: I2C timeout - no activity detected", $time);
                error_count++;
            end else begin
                $display("[%0t] I2C transaction detected", $time);
                test_count++;
            end
        end
    endtask
    
    task check_capture_counters;
        begin
            if (dval) begin
                $display("[%0t] Capture active: X=%0d, Y=%0d, Frame=%0d, Data=0x%03x", 
                         $time, x_cnt, y_cnt, frame_cnt, capture_data);
                test_count++;
            end
        end
    endtask
    
    task check_rgb_output;
        begin
            if (rgb_dval) begin
                $display("[%0t] RGB output: X=%0d, Y=%0d, R=%02x, G=%02x, B=%02x", 
                         $time, rgb_x, rgb_y, rgb_red, rgb_green, rgb_blue);
                test_count++;
            end
        end
    endtask
    
    //===========================================
    // Main Test Sequence
    //===========================================
    
    initial begin
        // Initialize
        $display("===========================================");
        $display("Camera Module Testbench Starting");
        $display("===========================================");
        
        error_count = 0;
        test_count = 0;
        
        // Initialize signals
        rst_n = 0;
        zoom_mode_sw = 0;
        exposure_adj = 0;
        exposure_dec_p = 0;
        trigger = 0;
        cam_data = 12'd0;
        lval = 0;
        fval = 0;
        strobe = 0;
        xclkin = 0;
        
        // Reset pulse
        repeat(10) @(posedge clk_50mhz);
        rst_n = 1;
        $display("[%0t] Reset released", $time);

        // Hold trigger high so capture enable (iSTART) stays asserted
        // throughout the simulation; iEND is tied low in the DUT.
        trigger = 1'b1;
        repeat(4) @(posedge pixclk);
        
        //===========================================
        // TEST 1: I2C Initialization
        //===========================================
        $display("\n===========================================");
        $display("TEST 1: I2C Configuration Initialization");
        $display("===========================================");
        
        // Wait for I2C configuration to start
        repeat(100) @(posedge clk_50mhz);
        
        // Monitor first few I2C transactions
        repeat(5) begin
            check_i2c_transaction();
            // Wait between transactions
            repeat(5000) @(posedge clk_50mhz);
        end
        
        //===========================================
        // TEST 2: Zoom Mode Change
        //===========================================
        $display("\n===========================================");
        $display("TEST 2: Zoom Mode Switch Test");
        $display("===========================================");
        
        zoom_mode_sw = 1;
        $display("[%0t] Zoom mode enabled", $time);
        repeat(10000) @(posedge clk_50mhz);
        
        zoom_mode_sw = 0;
        $display("[%0t] Zoom mode disabled", $time);
        repeat(10000) @(posedge clk_50mhz);
        
        //===========================================
        // TEST 3: Exposure Adjustment
        //===========================================
        $display("\n===========================================");
        $display("TEST 3: Exposure Adjustment Test");
        $display("===========================================");
        
        // Increase exposure
        exposure_dec_p = 0;
        exposure_adj = 1;
        repeat(10) @(posedge clk_50mhz);
        exposure_adj = 0;
        $display("[%0t] Exposure increase triggered", $time);
        repeat(5000) @(posedge clk_50mhz);
        
        // Decrease exposure
        exposure_dec_p = 1;
        exposure_adj = 1;
        repeat(10) @(posedge clk_50mhz);
        exposure_adj = 0;
        $display("[%0t] Exposure decrease triggered", $time);
        repeat(5000) @(posedge clk_50mhz);
        
        //===========================================
        // TEST 4: Camera Capture - Single Frame
        //===========================================
        $display("\n===========================================");
        $display("TEST 4: Camera Capture - Single Frame");
        $display("===========================================");
        
        // Capture is enabled by trigger already high; generate a fixed 256x256 frame
        generate_frame();
        
        // Check that frame counter incremented
        @(posedge pixclk);
        if (frame_cnt > 0) begin
            $display("[%0t] PASS: Frame counter = %0d", $time, frame_cnt);
            test_count++;
        end else begin
            $display("[%0t] ERROR: Frame counter did not increment", $time);
            error_count++;
        end
        
        //===========================================
        // TEST 5: Camera Capture - Multiple Frames
        //===========================================
        $display("\n===========================================");
        $display("TEST 5: Camera Capture - Multiple Frames");
        $display("===========================================");
        
        repeat(3) begin
            generate_frame();
        end
        
        // Verify frame counter
        if (frame_cnt >= 4) begin
            $display("[%0t] PASS: Multiple frames captured, count = %0d", $time, frame_cnt);
            test_count++;
        end else begin
            $display("[%0t] ERROR: Frame counter = %0d, expected >= 4", $time, frame_cnt);
            error_count++;
        end
        
        //===========================================
        // TEST 6: RGB Conversion
        //===========================================
        $display("\n===========================================");
        $display("TEST 6: Raw to RGB Conversion");
        $display("===========================================");
        
        // Generate a frame and monitor RGB output
        fork
            begin
                generate_frame();
            end
            begin
                repeat(100) begin
                    @(posedge pixclk);
                    if (rgb_dval) begin
                        check_rgb_output();
                    end
                end
            end
        join
        
        //===========================================
        // TEST 7: Pixel Coordinates Verification
        //===========================================
        $display("\n===========================================");
        $display("TEST 7: Pixel Coordinates Verification");
        $display("===========================================");
        
        // Monitor coordinates during capture
        fork
            begin
                generate_frame();
            end
            begin
                logic [9:0] prev_x, prev_y;
                prev_x = 0;
                prev_y = 0;
                
                repeat(1000) begin
                    @(posedge pixclk);
                    if (dval) begin
                        // Check X counter increments or wraps
                        if (x_cnt == 0 && prev_x == 255) begin
                            $display("[%0t] X counter wrapped correctly at Y=%0d", $time, y_cnt);
                        end else if (x_cnt != prev_x + 1 && !(x_cnt == 0 && prev_x == 0)) begin
                            $display("[%0t] WARNING: X counter jump from %0d to %0d", 
                                   $time, prev_x, x_cnt);
                        end
                        prev_x = x_cnt;
                        prev_y = y_cnt;
                    end
                end
            end
        join
        
        //===========================================
        // Test Summary
        //===========================================
        repeat(100) @(posedge clk_50mhz);
        
        $display("\n===========================================");
        $display("Test Summary");
        $display("===========================================");
        $display("Total tests run: %0d", test_count);
        $display("Total errors: %0d", error_count);
        
        if (error_count == 0) begin
            $display("Status: ALL TESTS PASSED");
        end else begin
            $display("Status: TESTS FAILED");
        end
        $display("===========================================\n");
        
        $finish;
    end
    
    //===========================================
    // Waveform Dump
    //===========================================
    
    initial begin
        $dumpfile("tb_camera.vcd");
        $dumpvars(0, tb_Camera);
    end
    
    //===========================================
    // Timeout Watchdog
    //===========================================
    
    initial begin
        #50_000_000; // 50ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
