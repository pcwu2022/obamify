module Memory_transfer(
    input  logic        i_clk,
    input  logic        i_rst_n,
    // Flash interface
    input  logic        i_FL_data_valid,
    input  logic [7:0]  i_FL_data,
    output logic        o_FL_read,
    output logic [22:0] o_FL_addr,
    // SRAM interface
    input  logic [31:0] i_SRAM_data,
    output logic [19:0] o_SRAM_addr,
    output logic        o_SRAM_enable,
    output logic        o_SRAM_write,
    output logic [31:0] o_SRAM_data,
    // SDRAM interface
    input  logic [31:0] i_SDRAM_data,
    output logic        o_SDRAM_read,
    output logic        o_SDRAM_write,
    output logic [22:0] o_SDRAM_addr,
    output logic [31:0] o_SDRAM_data,
    // Control signals
    input  logic        i_start,
    input  logic        i_SRAM_to_SDRAM_valid,
    input  logic        i_SDRAM_to_SRAM_valid,
    output logic        o_done
);



endmodule