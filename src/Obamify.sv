module Obamify (
    input           i_clk,
    input           i_rst_n,

    // Init Controls (Given along with i_start)
    input  [2:0]    target_image_index,

    // Global Controls (i_start -> N epochs -> o_finished)
    input           i_start,
    output          o_finished,

    // Epoch Controls (i_epoch_start -> M iterations -> o_epoch_finished -> (VGA) -> Repeat)
    input           i_epoch_start,
    output          o_epoch_finished,
    output  [15:0]  o_current_epoch,

    // SRAM Controls
    output  [19:0]  o_sram_addr,
    input   [31:0]  i_sram_data,
    output  [31:0]  o_sram_data,
    output          o_sram_we       // Write enable for SRAM

);

// === PARAMETERS === //

// Image dimensions
localparam W = 128;
localparam H = 128;
localparam MAX_LENGTH = 8;
localparam N = 1024;    // Number of epochs
localparam M = 1024;    // Number of iterations per epoch

// Addresses
localparam TARGET_IMAGE_ADDR = 20'h50000;
localparam logic [19:0] SOURCE_IMAGE_ADDRS [5] = '{
    20'h00000,
    20'h01000,
    20'h02000,
    20'h03000,
    20'h04000
};

// FSM States
localparam S_IDLE           = 4'd0;     // Waiting for i_start
localparam S_CALC_INIT      = 4'd1;     // Load random_number_r, calculate indices
localparam S_READ_SOURCE_1  = 4'd2;     // Request read source: pixel 1
localparam S_READ_SOURCE_2  = 4'd3;     // Request read source: pixel 2
localparam S_READ_TARGET_1  = 4'd4;     // Request read target: pixel 1
localparam S_READ_TARGET_2  = 4'd5;     // Request read target: pixel 2
localparam S_CALC_LOSS      = 4'd6;     // Calculate loss and decide swap
localparam S_WRITE_SOURCE_1 = 4'd7;     // Request write source: pixel 1    
localparam S_WRITE_SOURCE_2 = 4'd8;     // Request write source: pixel 2
localparam S_EPOCH_DONE     = 4'd9;     // Epoch finished, wait for next epoch
localparam S_FINISHED       = 4'd10;    // All epochs finished

// Movement directions: (di, dj) for directions 0,1,2,3
// Direction 0: (0, 1), Direction 1: (1, 0), Direction 2: (0, -1), Direction 3: (-1, 0)

// === REGISTERS === //

// FSM State
logic   [3:0]   state_r, state_w;

// Epochs and Iterations
logic   [15:0]  epoch_r, epoch_w;
logic   [15:0]  iteration_r, iteration_w;

// Source image base address
logic   [19:0]  source_base_addr_r, source_base_addr_w;

// Pixels: r, g, b, loss (8-bit each) = 32 bits
logic   [31:0]  source_pixel_1_r, source_pixel_1_w;
logic   [31:0]  source_pixel_2_r, source_pixel_2_w;
logic   [31:0]  target_pixel_1_r, target_pixel_1_w;
logic   [31:0]  target_pixel_2_r, target_pixel_2_w;

// Random number register
logic   [20:0]  random_number_r;

// Calculated indices (registered for timing)
logic   [6:0]   i_idx_r, i_idx_w;       // source pixel 1 x-coordinate
logic   [6:0]   j_idx_r, j_idx_w;       // source pixel 1 y-coordinate
logic   [6:0]   k_idx_r, k_idx_w;       // source pixel 2 x-coordinate
logic   [6:0]   l_idx_r, l_idx_w;       // source pixel 2 y-coordinate
logic           valid_move_r, valid_move_w;  // Whether the calculated move is valid

// Output registers
logic           finished_r, finished_w;
logic           epoch_finished_r, epoch_finished_w;

// SRAM control registers
logic   [19:0]  sram_addr_r, sram_addr_w;
logic   [31:0]  sram_data_out_r, sram_data_out_w;
logic           sram_we_r, sram_we_w;

// === WIRES === //

// Random number from generator
logic   [20:0]  random_number_w;

// Extracted fields from random number
logic   [2:0]   deviation;          // random_number[2:0] for deviation (0-7)
logic   [1:0]   direction;          // random_number[4:3] for direction (0-3)
logic   [6:0]   rand_i;             // random_number[11:5] for i
logic   [6:0]   rand_j;             // random_number[18:12] for j

// Calculated target indices
logic signed [7:0]  k_calc, l_calc;
logic           move_valid;

// Loss calculation wires
logic   [7:0]   loss_forward;       // Loss for pixel_s_1 moving to target_2
logic   [7:0]   loss_reverse;       // Loss for pixel_s_2 moving to target_1
logic   [8:0]   loss_old;           // Current loss sum (9-bit to handle overflow)
logic   [8:0]   loss_new;           // New loss sum after swap

// Swapped pixel values
logic   [31:0]  swapped_pixel_1;
logic   [31:0]  swapped_pixel_2;

// === MODULE INSTANTIATIONS === //

// Random Number Generator
Random_number_21_bit random_gen (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .o_random_number(random_number_w)
);

// Loss calculators (need two: forward and reverse)
Loss_pixel loss_calc_forward (
    .i_pixel_a(source_pixel_1_r[31:8]),  // RGB of source pixel 1
    .i_pixel_b(target_pixel_2_r[31:8]),  // RGB of target pixel 2
    .o_loss(loss_forward)
);

Loss_pixel loss_calc_reverse (
    .i_pixel_a(source_pixel_2_r[31:8]),  // RGB of source pixel 2
    .i_pixel_b(target_pixel_1_r[31:8]),  // RGB of target pixel 1
    .o_loss(loss_reverse)
);

// === OUTPUT ASSIGNMENTS === //

assign o_finished = finished_r;
assign o_epoch_finished = epoch_finished_r;
assign o_current_epoch = epoch_r;
assign o_sram_addr = sram_addr_r;
assign o_sram_data = sram_data_out_r;
assign o_sram_we = sram_we_r;

// === COMBINATIONAL LOGIC === //

// Extract random number fields
assign deviation = random_number_r[2:0];                    // 3 bits for 0-7
assign direction = random_number_r[6:5];                    // 2 bits for 0-3 (bits 3-4 skipped)
assign rand_i = random_number_r[13:7];                      // 7 bits for 0-127
assign rand_j = random_number_r[20:14];                     // 7 bits for 0-127

// Calculate target indices based on direction
// Direction 0: (0, +1), Direction 1: (+1, 0), Direction 2: (0, -1), Direction 3: (-1, 0)
always_comb begin
    case (direction)
        2'd0: begin // (0, +1)
            k_calc = {1'b0, rand_i};
            l_calc = {1'b0, rand_j} + {5'b0, deviation};
        end
        2'd1: begin // (+1, 0)
            k_calc = {1'b0, rand_i} + {5'b0, deviation};
            l_calc = {1'b0, rand_j};
        end
        2'd2: begin // (0, -1)
            k_calc = {1'b0, rand_i};
            l_calc = {1'b0, rand_j} - {5'b0, deviation};
        end
        2'd3: begin // (-1, 0)
            k_calc = {1'b0, rand_i} - {5'b0, deviation};
            l_calc = {1'b0, rand_j};
        end
    endcase
end

// Check if move is within bounds
assign move_valid = (k_calc >= 0) && (k_calc < W) && (l_calc >= 0) && (l_calc < H);

// Loss calculations
assign loss_old = {1'b0, source_pixel_1_r[7:0]} + {1'b0, source_pixel_2_r[7:0]};
assign loss_new = {1'b0, loss_forward} + {1'b0, loss_reverse};

// Swapped pixel values (swap RGB, update loss byte)
assign swapped_pixel_1 = {source_pixel_2_r[31:8], loss_reverse};  // RGB from pixel 2, new loss
assign swapped_pixel_2 = {source_pixel_1_r[31:8], loss_forward};  // RGB from pixel 1, new loss

// Address calculation helper function (inline)
// Address = base + j * W + i (row-major order)
function automatic [19:0] calc_addr;
    input [19:0] base;
    input [6:0] x;
    input [6:0] y;
    begin
        calc_addr = base + {6'b0, y, 7'b0} + {13'b0, x};  // y * 128 + x
    end
endfunction

// === FSM COMBINATIONAL LOGIC === //

always_comb begin
    // Default assignments (hold values)
    state_w = state_r;
    epoch_w = epoch_r;
    iteration_w = iteration_r;
    source_base_addr_w = source_base_addr_r;
    
    source_pixel_1_w = source_pixel_1_r;
    source_pixel_2_w = source_pixel_2_r;
    target_pixel_1_w = target_pixel_1_r;
    target_pixel_2_w = target_pixel_2_r;
    
    i_idx_w = i_idx_r;
    j_idx_w = j_idx_r;
    k_idx_w = k_idx_r;
    l_idx_w = l_idx_r;
    valid_move_w = valid_move_r;
    
    finished_w = 1'b0;
    epoch_finished_w = 1'b0;
    
    sram_addr_w = sram_addr_r;
    sram_data_out_w = sram_data_out_r;
    sram_we_w = 1'b0;
    
    case (state_r)
        S_IDLE: begin
            if (i_start) begin
                epoch_w = 16'd0;
                iteration_w = 16'd0;
                source_base_addr_w = SOURCE_IMAGE_ADDRS[target_image_index];
                state_w = S_CALC_INIT;
            end
        end
        
        S_CALC_INIT: begin
            // Latch random number and calculate indices
            i_idx_w = rand_i;
            j_idx_w = rand_j;
            k_idx_w = k_calc[6:0];
            l_idx_w = l_calc[6:0];
            valid_move_w = move_valid;
            
            if (move_valid) begin
                // Set up read for source pixel 1
                sram_addr_w = calc_addr(source_base_addr_r, rand_i, rand_j);
                state_w = S_READ_SOURCE_1;
            end else begin
                // Invalid move, skip to next iteration
                if (iteration_r == M - 1) begin
                    state_w = S_EPOCH_DONE;
                end else begin
                    iteration_w = iteration_r + 16'd1;
                    state_w = S_CALC_INIT;
                end
            end
        end
        
        S_READ_SOURCE_1: begin
            // Capture source pixel 1 data
            source_pixel_1_w = i_sram_data;
            // Set up read for source pixel 2
            sram_addr_w = calc_addr(source_base_addr_r, k_idx_r, l_idx_r);
            state_w = S_READ_SOURCE_2;
        end
        
        S_READ_SOURCE_2: begin
            // Capture source pixel 2 data
            source_pixel_2_w = i_sram_data;
            // Set up read for target pixel 1
            sram_addr_w = calc_addr(TARGET_IMAGE_ADDR, i_idx_r, j_idx_r);
            state_w = S_READ_TARGET_1;
        end
        
        S_READ_TARGET_1: begin
            // Capture target pixel 1 data
            target_pixel_1_w = i_sram_data;
            // Set up read for target pixel 2
            sram_addr_w = calc_addr(TARGET_IMAGE_ADDR, k_idx_r, l_idx_r);
            state_w = S_READ_TARGET_2;
        end
        
        S_READ_TARGET_2: begin
            // Capture target pixel 2 data
            target_pixel_2_w = i_sram_data;
            state_w = S_CALC_LOSS;
        end
        
        S_CALC_LOSS: begin
            // Loss calculation is combinational, check if swap improves loss
            if (loss_new <= loss_old) begin
                // Swap improves or maintains loss, write back swapped pixels
                sram_addr_w = calc_addr(source_base_addr_r, i_idx_r, j_idx_r);
                sram_data_out_w = swapped_pixel_1;
                sram_we_w = 1'b1;
                state_w = S_WRITE_SOURCE_1;
            end else begin
                // No improvement, skip write and go to next iteration
                if (iteration_r == M - 1) begin
                    state_w = S_EPOCH_DONE;
                end else begin
                    iteration_w = iteration_r + 16'd1;
                    state_w = S_CALC_INIT;
                end
            end
        end
        
        S_WRITE_SOURCE_1: begin
            // Write source pixel 2
            sram_addr_w = calc_addr(source_base_addr_r, k_idx_r, l_idx_r);
            sram_data_out_w = swapped_pixel_2;
            sram_we_w = 1'b1;
            state_w = S_WRITE_SOURCE_2;
        end
        
        S_WRITE_SOURCE_2: begin
            // Finish this iteration
            sram_we_w = 1'b0;
            if (iteration_r == M - 1) begin
                state_w = S_EPOCH_DONE;
            end else begin
                iteration_w = iteration_r + 16'd1;
                state_w = S_CALC_INIT;
            end
        end
        
        S_EPOCH_DONE: begin
            epoch_finished_w = 1'b1;
            // Wait for next epoch start or finish if all epochs done
            if (epoch_r == N - 1) begin
                state_w = S_FINISHED;
            end else if (i_epoch_start) begin
                epoch_w = epoch_r + 16'd1;
                iteration_w = 16'd0;
                state_w = S_CALC_INIT;
            end
        end
        
        S_FINISHED: begin
            finished_w = 1'b1;
            state_w = S_IDLE;
        end
        
        default: begin
            state_w = S_IDLE;
        end
    endcase
end

// === SEQUENTIAL LOGIC === //

always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state_r <= S_IDLE;
        epoch_r <= 16'd0;
        iteration_r <= 16'd0;
        source_base_addr_r <= 20'd0;
        
        source_pixel_1_r <= 32'd0;
        source_pixel_2_r <= 32'd0;
        target_pixel_1_r <= 32'd0;
        target_pixel_2_r <= 32'd0;
        
        random_number_r <= 21'd0;
        
        i_idx_r <= 7'd0;
        j_idx_r <= 7'd0;
        k_idx_r <= 7'd0;
        l_idx_r <= 7'd0;
        valid_move_r <= 1'b0;
        
        finished_r <= 1'b0;
        epoch_finished_r <= 1'b0;
        
        sram_addr_r <= 20'd0;
        sram_data_out_r <= 32'd0;
        sram_we_r <= 1'b0;
    end else begin
        state_r <= state_w;
        epoch_r <= epoch_w;
        iteration_r <= iteration_w;
        source_base_addr_r <= source_base_addr_w;
        
        source_pixel_1_r <= source_pixel_1_w;
        source_pixel_2_r <= source_pixel_2_w;
        target_pixel_1_r <= target_pixel_1_w;
        target_pixel_2_r <= target_pixel_2_w;
        
        // Latch random number at CALC_INIT state
        if (state_r == S_CALC_INIT || state_r == S_IDLE) begin
            random_number_r <= random_number_w;
        end
        
        i_idx_r <= i_idx_w;
        j_idx_r <= j_idx_w;
        k_idx_r <= k_idx_w;
        l_idx_r <= l_idx_w;
        valid_move_r <= valid_move_w;
        
        finished_r <= finished_w;
        epoch_finished_r <= epoch_finished_w;
        
        sram_addr_r <= sram_addr_w;
        sram_data_out_r <= sram_data_out_w;
        sram_we_r <= sram_we_w;
    end
end

endmodule