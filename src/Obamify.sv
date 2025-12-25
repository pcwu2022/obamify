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
    input   [15:0]  i_sram_data,
    output  [15:0]  o_sram_data,
    output          o_sram_we       // Write enable for SRAM

);

// === PARAMETERS === //

// Image dimensions
localparam W = 128;
localparam W_bits = 7;
localparam MAX_LENGTH = 8;
localparam N = 480;    // Number of epochs
localparam M = 1024;    // Number of iterations per epoch

// Addresses (each pixel is 2 words, so multiply by 2 for word address)
localparam SOURCE_IMAGE_ADDR = 20'h28000;
localparam logic [19:0] TARGET_IMAGE_ADDRS [5] = '{
    20'h00000,
    20'h08000,
    20'h10000,
    20'h18000,
    20'h20000
};

// FSM States - expanded to handle 16-bit SRAM for 32-bit pixels
// Added WAIT states for proper SRAM timing (address setup before read)
localparam S_IDLE               = 5'd0;     // Waiting for i_start
localparam S_CALC_INIT          = 5'd1;     // Load random_number_r, calculate indices
localparam S_ADDR_SOURCE_1_LO   = 5'd2;     // Set address for source pixel 1: low 16 bits
localparam S_WAIT_SOURCE_1_LO   = 5'd3;     // Wait for SRAM data (source pixel 1 low)
localparam S_READ_SOURCE_1_LO   = 5'd4;     // Read source pixel 1: low 16 bits
localparam S_WAIT_SOURCE_1_HI   = 5'd5;     // Wait for SRAM data (source pixel 1 high)
localparam S_READ_SOURCE_1_HI   = 5'd6;     // Read source pixel 1: high 16 bits
localparam S_WAIT_SOURCE_2_LO   = 5'd7;     // Wait for SRAM data (source pixel 2 low)
localparam S_READ_SOURCE_2_LO   = 5'd8;     // Read source pixel 2: low 16 bits
localparam S_WAIT_SOURCE_2_HI   = 5'd9;     // Wait for SRAM data (source pixel 2 high)
localparam S_READ_SOURCE_2_HI   = 5'd10;    // Read source pixel 2: high 16 bits
localparam S_WAIT_TARGET_1_LO   = 5'd11;    // Wait for SRAM data (target pixel 1 low)
localparam S_READ_TARGET_1_LO   = 5'd12;    // Read target pixel 1: low 16 bits
localparam S_WAIT_TARGET_1_HI   = 5'd13;    // Wait for SRAM data (target pixel 1 high)
localparam S_READ_TARGET_1_HI   = 5'd14;    // Read target pixel 1: high 16 bits
localparam S_WAIT_TARGET_2_LO   = 5'd15;    // Wait for SRAM data (target pixel 2 low)
localparam S_READ_TARGET_2_LO   = 5'd16;    // Read target pixel 2: low 16 bits
localparam S_WAIT_TARGET_2_HI   = 5'd17;    // Wait for SRAM data (target pixel 2 high)
localparam S_READ_TARGET_2_HI   = 5'd18;    // Read target pixel 2: high 16 bits
localparam S_CALC_LOSS          = 5'd19;    // Calculate loss and decide swap
localparam S_WRITE_SOURCE_1_LO  = 5'd20;    // Write source pixel 1: low 16 bits
localparam S_WRITE_SOURCE_1_HI  = 5'd21;    // Write source pixel 1: high 16 bits
localparam S_WRITE_SOURCE_2_LO  = 5'd22;    // Write source pixel 2: low 16 bits
localparam S_WRITE_SOURCE_2_HI  = 5'd23;    // Write source pixel 2: high 16 bits
localparam S_NEXT_ITER          = 5'd24;    // Move to next iteration
localparam S_EPOCH_DONE         = 5'd25;    // Epoch finished, wait for next epoch
localparam S_FINISHED           = 5'd26;    // All epochs finished

// Movement directions: (di, dj) for directions 0,1,2,3
// Direction 0: (0, 1), Direction 1: (1, 0), Direction 2: (0, -1), Direction 3: (-1, 0)

// === REGISTERS === //

// FSM State
logic   [4:0]   state_r, state_w;

// Epochs and Iterations
logic   [15:0]  epoch_r, epoch_w;
logic   [15:0]  iteration_r, iteration_w;

// Source image base address
logic   [19:0]  target_base_addr_r, target_base_addr_w;

// Pixels: r, g, b, loss (8-bit each) = 32 bits
// Format: [31:24]=R, [23:16]=G, [15:8]=B, [7:0]=Loss
logic   [31:0]  source_pixel_1_r, source_pixel_1_w;
logic   [31:0]  source_pixel_2_r, source_pixel_2_w;
logic   [31:0]  target_pixel_1_r, target_pixel_1_w;
logic   [31:0]  target_pixel_2_r, target_pixel_2_w;

// Random number register
logic   [20:0]  random_number_r, random_number_next;

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
logic   [15:0]  sram_data_out_r, sram_data_out_w;
logic           sram_we_r, sram_we_w;

// === WIRES === //

// Random number from generator
logic   [20:0]  random_number_w;

// Extracted fields from random number
logic   [2:0]   deviation;          // random_number[2:0] for deviation (0-7)
logic   [1:0]   direction;          // random_number[6:5] for direction (0-3)
logic   [6:0]   rand_i;             // random_number[13:7] for i
logic   [6:0]   rand_j;             // random_number[20:14] for j

// Calculated target indices
logic signed [8:0]  k_calc, l_calc;
logic           move_valid;

// Loss calculation wires
logic   [7:0]   loss_forward;       // Loss for pixel_s_1 moving to target_2
logic   [7:0]   loss_reverse;       // Loss for pixel_s_2 moving to target_1
logic   [8:0]   loss_old;           // Current loss sum (9-bit to handle overflow)
logic   [8:0]   loss_new;           // New loss sum after swap
logic           should_swap;        // Whether swap improves loss

// Swapped pixel values
logic   [31:0]  swapped_pixel_1;
logic   [31:0]  swapped_pixel_2;

// Address calculation helpers
logic   [19:0]  pixel_1_addr;       // Base address for pixel 1 (i, j)
logic   [19:0]  pixel_2_addr;       // Base address for pixel 2 (k, l)
logic   [19:0]  target_pixel_1_addr;
logic   [19:0]  target_pixel_2_addr;

// === MODULE INSTANTIATIONS === //

// Random Number Generator
Random_number_21_bit random_gen (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .o_random_number(random_number_w)
);

// Loss calculators (need two: forward and reverse)
// Format: [31:24]=R, [23:16]=G, [15:8]=B
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

// Extract random number fields (matching Python implementation)
// deviation = random_21_bits % MAX_LENGTH (bits 0-2 for 0-7)
// direction = (random_21_bits >> 5) % 4 (bits 5-6 for 0-3)
// i = (random_21_bits >> 7) % W (bits 7-13 for 0-127)
// j = (random_21_bits >> 14) % W (bits 14-20 for 0-127)
assign deviation = random_number_r[2:0];                    // 3 bits for 0-7
assign direction = random_number_r[6:5];                    // 2 bits for 0-3
assign rand_i = random_number_r[13:7];                      // 7 bits for 0-127
assign rand_j = random_number_r[20:14];                     // 7 bits for 0-127

// Calculate k and l based on direction and deviation
// Direction 0: (di=0, dj=1)  -> k=i, l=j+deviation
// Direction 1: (di=1, dj=0)  -> k=i+deviation, l=j
// Direction 2: (di=0, dj=-1) -> k=i, l=j-deviation
// Direction 3: (di=-1, dj=0) -> k=i-deviation, l=j

// Wires for calculating k/l from the NEW random number (for use in S_CALC_INIT)
logic   [2:0]   deviation_new;
logic   [1:0]   direction_new;
logic   [6:0]   rand_i_new;
logic   [6:0]   rand_j_new;
logic signed [8:0]  k_calc_new, l_calc_new;
logic           move_valid_new;

assign deviation_new = random_number_w[2:0];
assign direction_new = random_number_w[6:5];
assign rand_i_new = random_number_w[13:7];
assign rand_j_new = random_number_w[20:14];

always_comb begin
    case (direction)
        2'd0: begin
            k_calc = {2'b0, rand_i};
            l_calc = {2'b0, rand_j} + {6'b0, deviation};
        end
        2'd1: begin
            k_calc = {2'b0, rand_i} + {6'b0, deviation};
            l_calc = {2'b0, rand_j};
        end
        2'd2: begin
            k_calc = {2'b0, rand_i};
            l_calc = {2'b0, rand_j} - {6'b0, deviation};
        end
        2'd3: begin
            k_calc = {2'b0, rand_i} - {6'b0, deviation};
            l_calc = {2'b0, rand_j};
        end
        default: begin
            k_calc = {2'b0, rand_i};
            l_calc = {2'b0, rand_j};
        end
    endcase
end

// Calculate k_calc_new and l_calc_new from the NEW random number
always_comb begin
    case (direction_new)
        2'd0: begin
            k_calc_new = {2'b0, rand_i_new};
            l_calc_new = {2'b0, rand_j_new} + {6'b0, deviation_new};
        end
        2'd1: begin
            k_calc_new = {2'b0, rand_i_new} + {6'b0, deviation_new};
            l_calc_new = {2'b0, rand_j_new};
        end
        2'd2: begin
            k_calc_new = {2'b0, rand_i_new};
            l_calc_new = {2'b0, rand_j_new} - {6'b0, deviation_new};
        end
        2'd3: begin
            k_calc_new = {2'b0, rand_i_new} - {6'b0, deviation_new};
            l_calc_new = {2'b0, rand_j_new};
        end
        default: begin
            k_calc_new = {2'b0, rand_i_new};
            l_calc_new = {2'b0, rand_j_new};
        end
    endcase
end

// Check if calculated indices are within bounds [0, W-1] and [0, W-1]
assign move_valid = (k_calc >= 0) && (k_calc < W) && (l_calc >= 0) && (l_calc < W);
assign move_valid_new = (k_calc_new >= 0) && (k_calc_new < W) && (l_calc_new >= 0) && (l_calc_new < W);

// Address calculations: pixel address = base + 2(jW + i) (each pixel is 2 words)
// Source pixel 1 at (i_idx_r, j_idx_r)
assign pixel_1_addr = SOURCE_IMAGE_ADDR + ((({13'b0, j_idx_r} << W_bits) + ({13'b0, i_idx_r})) << 1);
// Source pixel 2 at (k_idx_r, l_idx_r)
assign pixel_2_addr = SOURCE_IMAGE_ADDR + ((({13'b0, l_idx_r} << W_bits) + ({13'b0, k_idx_r})) << 1);
// Target pixel 1 at (i_idx_r, j_idx_r)
assign target_pixel_1_addr = target_base_addr_r + ((({13'b0, j_idx_r} << W_bits) + ({13'b0, i_idx_r})) << 1);
// Target pixel 2 at (k_idx_r, l_idx_r)
assign target_pixel_2_addr = target_base_addr_r + ((({13'b0, l_idx_r} << W_bits) + ({13'b0, k_idx_r})) << 1);

// Loss calculations
assign loss_old = {1'b0, source_pixel_1_r[7:0]} + {1'b0, source_pixel_2_r[7:0]};
assign loss_new = {1'b0, loss_forward} + {1'b0, loss_reverse};
assign should_swap = (loss_new <= loss_old);

// Swapped pixels: swap RGB, update loss
// swapped_pixel_1 gets RGB from source_pixel_2, loss = loss_reverse
// swapped_pixel_2 gets RGB from source_pixel_1, loss = loss_forward
assign swapped_pixel_1 = {source_pixel_2_r[31:8], loss_reverse};
assign swapped_pixel_2 = {source_pixel_1_r[31:8], loss_forward};

// FSM and control logic
always_comb begin
    // Default: hold current values
    state_w = state_r;
    epoch_w = epoch_r;
    iteration_w = iteration_r;
    target_base_addr_w = target_base_addr_r;
    source_pixel_1_w = source_pixel_1_r;
    source_pixel_2_w = source_pixel_2_r;
    target_pixel_1_w = target_pixel_1_r;
    target_pixel_2_w = target_pixel_2_r;
    random_number_next = random_number_r;
    i_idx_w = i_idx_r;
    j_idx_w = j_idx_r;
    k_idx_w = k_idx_r;
    l_idx_w = l_idx_r;
    valid_move_w = valid_move_r;
    finished_w = 1'b0;          // Pulse signals
    epoch_finished_w = 1'b0;
    sram_addr_w = sram_addr_r;
    sram_data_out_w = sram_data_out_r;
    sram_we_w = 1'b0;           // Default: no write

    case (state_r)
        S_IDLE: begin
            if (i_start) begin
                // Initialize for first epoch
                epoch_w = 16'd0;
                iteration_w = 16'd0;
                // Clamp target_image_index to valid range [0-4]
                if (target_image_index < 3'd5) begin
                    target_base_addr_w = TARGET_IMAGE_ADDRS[target_image_index];
                end else begin
                    target_base_addr_w = TARGET_IMAGE_ADDRS[0];  // Default to first image
                end
                state_w = S_CALC_INIT;
            end
        end

        S_CALC_INIT: begin
            // Latch NEW random number and calculate indices from it
            random_number_next = random_number_w;
            i_idx_w = rand_i_new;
            j_idx_w = rand_j_new;
            k_idx_w = k_calc_new[6:0];
            l_idx_w = l_calc_new[6:0];
            valid_move_w = move_valid_new;

            if (!move_valid_new) begin
                // Invalid move, skip to next iteration
                state_w = S_NEXT_ITER;
            end else begin
                // Valid move, set address for source pixel 1
                state_w = S_ADDR_SOURCE_1_LO;
            end
        end

        S_ADDR_SOURCE_1_LO: begin
            // Set SRAM address to the low word of source pixel 1
            sram_addr_w = pixel_1_addr;
            state_w = S_WAIT_SOURCE_1_LO;  // Wait for address to propagate
        end

        S_WAIT_SOURCE_1_LO: begin
            // Wait state - address is stable, data will be ready next cycle
            state_w = S_READ_SOURCE_1_LO;
        end

        S_READ_SOURCE_1_LO: begin
            // Capture low 16 bits of source pixel 1 (B[7:0], Loss[7:0])
            // Then set address for the HIGH word of source pixel 1
            source_pixel_1_w = {source_pixel_1_r[31:16], i_sram_data};
            sram_addr_w = pixel_1_addr + 20'd1;
            state_w = S_WAIT_SOURCE_1_HI;
        end

        S_WAIT_SOURCE_1_HI: begin
            // Wait state for high word
            state_w = S_READ_SOURCE_1_HI;
        end

        S_READ_SOURCE_1_HI: begin
            // Capture high 16 bits of source pixel 1 (R[7:0], G[7:0])
            // Then set address to the low word of source pixel 2
            source_pixel_1_w = {i_sram_data, source_pixel_1_r[15:0]};
            sram_addr_w = pixel_2_addr;
            state_w = S_WAIT_SOURCE_2_LO;
        end

        S_WAIT_SOURCE_2_LO: begin
            // Wait state
            state_w = S_READ_SOURCE_2_LO;
        end

        S_READ_SOURCE_2_LO: begin
            // Capture low 16 bits of source pixel 2
            // Then set address for the HIGH word of source pixel 2
            source_pixel_2_w = {source_pixel_2_r[31:16], i_sram_data};
            sram_addr_w = pixel_2_addr + 20'd1;
            state_w = S_WAIT_SOURCE_2_HI;
        end

        S_WAIT_SOURCE_2_HI: begin
            // Wait state
            state_w = S_READ_SOURCE_2_HI;
        end

        S_READ_SOURCE_2_HI: begin
            // Capture high 16 bits of source pixel 2
            // Then set address to the low word of target pixel 1
            source_pixel_2_w = {i_sram_data, source_pixel_2_r[15:0]};
            sram_addr_w = target_pixel_1_addr;
            state_w = S_WAIT_TARGET_1_LO;
        end

        S_WAIT_TARGET_1_LO: begin
            // Wait state
            state_w = S_READ_TARGET_1_LO;
        end

        S_READ_TARGET_1_LO: begin
            // Capture low 16 bits of target pixel 1
            // Then set address for the HIGH word of target pixel 1
            target_pixel_1_w = {target_pixel_1_r[31:16], i_sram_data};
            sram_addr_w = target_pixel_1_addr + 20'd1;
            state_w = S_WAIT_TARGET_1_HI;
        end

        S_WAIT_TARGET_1_HI: begin
            // Wait state
            state_w = S_READ_TARGET_1_HI;
        end

        S_READ_TARGET_1_HI: begin
            // Capture high 16 bits of target pixel 1
            // Then set address to the low word of target pixel 2
            target_pixel_1_w = {i_sram_data, target_pixel_1_r[15:0]};
            sram_addr_w = target_pixel_2_addr;
            state_w = S_WAIT_TARGET_2_LO;
        end

        S_WAIT_TARGET_2_LO: begin
            // Wait state
            state_w = S_READ_TARGET_2_LO;
        end

        S_READ_TARGET_2_LO: begin
            // Capture low 16 bits of target pixel 2
            // Then set address for the HIGH word of target pixel 2
            target_pixel_2_w = {target_pixel_2_r[31:16], i_sram_data};
            sram_addr_w = target_pixel_2_addr + 20'd1;
            state_w = S_WAIT_TARGET_2_HI;
        end

        S_WAIT_TARGET_2_HI: begin
            // Wait state
            state_w = S_READ_TARGET_2_HI;
        end

        S_READ_TARGET_2_HI: begin
            // Capture high 16 bits of target pixel 2
            // Now all pixel words are captured; compute loss next
            target_pixel_2_w = {i_sram_data, target_pixel_2_r[15:0]};
            state_w = S_CALC_LOSS;
        end

        S_CALC_LOSS: begin
            // Loss calculators are combinational, results ready
            if (should_swap) begin
                // Perform swap: write swapped pixel 1
                sram_addr_w = pixel_1_addr;
                sram_data_out_w = swapped_pixel_1[15:0];
                sram_we_w = 1'b1;
                state_w = S_WRITE_SOURCE_1_LO;
            end else begin
                // No swap needed, go to next iteration
                state_w = S_NEXT_ITER;
            end
        end

        S_WRITE_SOURCE_1_LO: begin
            // Write HIGH 16 bits of swapped pixel 1 to pixel_1_addr+1
            sram_addr_w = pixel_1_addr + 20'd1;
            sram_data_out_w = swapped_pixel_1[31:16];
            sram_we_w = 1'b1;
            state_w = S_WRITE_SOURCE_1_HI;
        end

        S_WRITE_SOURCE_1_HI: begin
            // Write LOW 16 bits of swapped pixel 2 to pixel_2_addr
            sram_addr_w = pixel_2_addr;
            sram_data_out_w = swapped_pixel_2[15:0];
            sram_we_w = 1'b1;
            state_w = S_WRITE_SOURCE_2_LO;
        end

        S_WRITE_SOURCE_2_LO: begin
            // Write HIGH 16 bits of swapped pixel 2 to pixel_2_addr+1
            sram_addr_w = pixel_2_addr + 20'd1;
            sram_data_out_w = swapped_pixel_2[31:16];
            sram_we_w = 1'b1;
            state_w = S_WRITE_SOURCE_2_HI;
        end

        S_WRITE_SOURCE_2_HI: begin
            // Write complete, go to next iteration
            state_w = S_NEXT_ITER;
        end

        S_NEXT_ITER: begin
            if (iteration_r == M - 1) begin
                if (epoch_r == N - 1) begin 
                    // Epoch complete AND All Epochs complete
                    epoch_finished_w = 1'b1;
                    finished_w = 1'b1;
                    state_w = S_FINISHED;
                end
                else begin 
                    // Epoch complete
                    epoch_finished_w = 1'b1;
                    state_w = S_EPOCH_DONE;
                end
            end else begin
                // Continue to next iteration
                iteration_w = iteration_r + 16'd1;
                state_w = S_CALC_INIT;
            end
        end

        S_EPOCH_DONE: begin
            // Wait for next epoch trigger
            if (i_epoch_start) begin
                // Start next epoch
                epoch_w = epoch_r + 16'd1;
                iteration_w = 16'd0;
                state_w = S_CALC_INIT;
            end
        end

        S_FINISHED: begin
            // Stay in finished state until reset
            state_w = S_IDLE;
        end

        default: begin
            state_w = S_IDLE;
        end
    endcase
end

// Sequential logic
always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state_r <= S_IDLE;
        epoch_r <= 16'd0;
        iteration_r <= 16'd0;
        target_base_addr_r <= 20'd0;
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
        sram_data_out_r <= 16'd0;
        sram_we_r <= 1'b0;
    end else begin
        state_r <= state_w;
        epoch_r <= epoch_w;
        iteration_r <= iteration_w;
        target_base_addr_r <= target_base_addr_w;
        source_pixel_1_r <= source_pixel_1_w;
        source_pixel_2_r <= source_pixel_2_w;
        target_pixel_1_r <= target_pixel_1_w;
        target_pixel_2_r <= target_pixel_2_w;
        random_number_r <= random_number_next;
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