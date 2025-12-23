module SRAM_control (
    input               i_clk,
    input               i_rst_n,
    input        [2:0]  i_state,
    // Memory transfer side
    input               i_mt_ce,
    input               i_mt_we,
    input        [19:0] i_mt_addr,
    input        [15:0] i_mt_data,
    output logic [15:0] o_mt_data,
    // Classifier side
    input               i_cl_ce,
    input        [19:0] i_cl_addr,
    output logic [15:0] o_cl_data,
    // Obamify side
    input               i_ob_ce,
    input               i_ob_we,
    input        [19:0] i_ob_addr,
    input        [15:0] i_ob_data,
    output logic [15:0] o_ob_data,
    // SRAM interface
    inout  logic [15:0] SRAM_DQ,
    output logic [19:0] SRAM_ADDR,
    output logic        SRAM_CE_N,
    output logic        SRAM_OE_N,
    output logic        SRAM_UB_N,
    output logic        SRAM_LB_N,
    output logic        SRAM_WE_N
);

localparam S_CL = 3'd1;
localparam S_MT = 3'd2;
localparam S_OB = 3'd3;

assign SRAM_DQ = (!SRAM_WE_N) ? ((i_state == S_MT) ? i_mt_data : i_ob_data) : 16'bz;
assign SRAM_CE_N = 1'b1;
assign SRAM_OE_N = 1'b0;
assign SRAM_UB_N = 1'b0;
assign SRAM_LB_N = 1'b0;
assign SRAM_WE_N = (i_mt_we || i_ob_we) ? 1'b0 : 1'b1;

always_comb begin
    case (i_state)
        S_MT: begin
            SRAM_ADDR = (i_mt_ce || i_mt_we) ? i_mt_addr : 20'd0;
            o_mt_data = (!i_mt_we && i_mt_ce) ? SRAM_DQ : 16'd0;
            o_cl_data = 16'd0;
            o_ob_data = 16'd0;
        end
        S_CL: begin
            SRAM_ADDR = (i_cl_ce) ? i_cl_addr : 20'd0;
            o_mt_data = 16'd0;
            o_cl_data = (i_cl_ce) ? SRAM_DQ : 16'd0;
            o_ob_data = 16'd0;
        end
        S_OB: begin
            SRAM_ADDR = (i_ob_ce || i_ob_we) ? i_ob_addr : 20'd0;
            o_mt_data = 16'd0;
            o_cl_data = 16'd0;
            o_ob_data = (!i_ob_we && i_ob_ce) ? SRAM_DQ : 16'd0;
        end
        default: begin
            SRAM_ADDR = 20'd0;
            o_mt_data = 16'd0;
            o_cl_data = 16'd0;
            o_ob_data = 16'd0;
        end
    endcase
end

endmodule