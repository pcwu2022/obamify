`timescale 1ns/100ps
`define CYCLE       40  // 25MHz
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   500000

module tb_VGA ();
  logic rst_n, clk;
  logic [9:0] oRed, oGreen, oBlue;
  logic [21:0] oAddress;
  logic oRequest;
  logic oHS, oVS, oSYNC, oBLANK, oCLOCK;
  VGA vga0 (
    .iRed(),
    .iGreen(),
    .iBlue(),
    .oAddress(oAddress),
    .oRequest(oRequest),
	//	VGA Side
    .oVGA_R(oRed),
    .oVGA_G(oGreen),
    .oVGA_B(oBlue),
    .oVGA_HS(oHS),
    .oVGA_VS(oVS),
    .oVGA_SYNC(oSYNC),
    .oVGA_BLANK(oBLANK),
    .oVGA_CLOCK(oCLOCK),
	//	Control Signal
    .iCLK(clk),
    .iRST_N	(rst_n));

  always begin
    #(`HCYCLE)
    clk = ~clk;
  end

  initial begin
    clk = 1'b0;
    $fsdbDumpfile("vga.fsdb");
    $fsdbDumpvars(0, tb_VGA, "+mda");
    rst_n = 1'b1;
    # (1.2 * `CYCLE);
    rst_n = 1'b0;
    # (2 * `CYCLE);
    rst_n = 1'b1;
    # (`CYCLE * `MAX_CYCLE);
    $finish;
  end

endmodule