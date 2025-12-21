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
    input   [19:0]  i_sram_data,
    output  [15:0]  o_sram_data

);

// === PARAMETERS === //

// Addresses
localparam TARGET_IMAGE_ADDR = 20'h50000;
localparam logic [19:0] SOURCE_IMAGE_ADDRS [5] = {
    20'h00000,
    20'h01000,
    20'h02000,
    20'h03000,
    20'h04000
};

// States
localparam CALC_INIT        = 0;    // load random_source_index_r
localparam READ_SOURCE_1    = 1;    // request read source: pixel 1
localparam READ_SOURCE_2    = 2;    // request read source: pixel 2
localparam READ_TARGET_1    = 3;    // request read target: pixel 1
localparam READ_TARGET_2    = 4;    // request read target: pixel 2
localparam CALC_LOSS        = 5;    // calculate loss
localparam WRITE_SOURCE_1   = 6;    // request write source: pixel 1    
localparam WRITE_SOURCE_2   = 7;    // request write source: pixel 2    

// === REGISTERS === //

// Epochs and Iterations
logic   [15:0]  epoch_r, epoch_w;
logic   [15:0]  iteration_r, iteration_w;

// States for Each Iteration
logic   [2:0]   state_r, state_w;

// Random Numbers
logic   [20:0]  random_number_w, random_number_r;        
logic   [4:0]   deviation;       // random_number_r[4:0] for deviation
logic   [1:0]   direction;       // random_number_r[6:5] for direction
logic   [6:0]   source_index_i;  // random_number_r[13:7] for source pixel 1
logic   [6:0]   source_index_j;  // random_number_r[20:14] for source pixel 2
logic   [6:0]   target_index_i;  // source_index_i + deviation and direction
logic   [6:0]   target_index_j;  // source_index_j + deviation and direction

// Random Number module
Random_number_21_bit random_gen (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .o_random_number(random_number_w)
)

// Combinational Circuit
always_comb begin
    
end

// Sequential Circuit
always_ff @(posedge i_clk or negedge i_rst_n) begin : blockName
    
end

endmodule