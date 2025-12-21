module DE2_115 (
	input CLOCK_50,
	input CLOCK2_50,
	input CLOCK3_50,
	input ENETCLK_25,
	input SMA_CLKIN,
	output SMA_CLKOUT,
	output [8:0] LEDG,
	output [17:0] LEDR,
	input [3:0] KEY,
	input [17:0] SW,
	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output [6:0] HEX4,
	output [6:0] HEX5,
	output [6:0] HEX6,
	output [6:0] HEX7,
	output LCD_BLON,
	inout [7:0] LCD_DATA,
	output LCD_EN,
	output LCD_ON,
	output LCD_RS,
	output LCD_RW,
	output UART_CTS,
	input UART_RTS,
	input UART_RXD,
	output UART_TXD,
	inout PS2_CLK,
	inout PS2_DAT,
	inout PS2_CLK2,
	inout PS2_DAT2,
	output SD_CLK,
	inout SD_CMD,
	inout [3:0] SD_DAT,
	input SD_WP_N,
	output [7:0] VGA_B,
	output VGA_BLANK_N,
	output VGA_CLK,
	output [7:0] VGA_G,
	output VGA_HS,
	output [7:0] VGA_R,
	output VGA_SYNC_N,
	output VGA_VS,
	input AUD_ADCDAT,
	inout AUD_ADCLRCK,
	inout AUD_BCLK,
	output AUD_DACDAT,
	inout AUD_DACLRCK,
	output AUD_XCK,
	output EEP_I2C_SCLK,
	inout EEP_I2C_SDAT,
	output I2C_SCLK,
	inout I2C_SDAT,
	output ENET0_GTX_CLK,
	input ENET0_INT_N,
	output ENET0_MDC,
	input ENET0_MDIO,
	output ENET0_RST_N,
	input ENET0_RX_CLK,
	input ENET0_RX_COL,
	input ENET0_RX_CRS,
	input [3:0] ENET0_RX_DATA,
	input ENET0_RX_DV,
	input ENET0_RX_ER,
	input ENET0_TX_CLK,
	output [3:0] ENET0_TX_DATA,
	output ENET0_TX_EN,
	output ENET0_TX_ER,
	input ENET0_LINK100,
	output ENET1_GTX_CLK,
	input ENET1_INT_N,
	output ENET1_MDC,
	input ENET1_MDIO,
	output ENET1_RST_N,
	input ENET1_RX_CLK,
	input ENET1_RX_COL,
	input ENET1_RX_CRS,
	input [3:0] ENET1_RX_DATA,
	input ENET1_RX_DV,
	input ENET1_RX_ER,
	input ENET1_TX_CLK,
	output [3:0] ENET1_TX_DATA,
	output ENET1_TX_EN,
	output ENET1_TX_ER,
	input ENET1_LINK100,
	input TD_CLK27,
	input [7:0] TD_DATA,
	input TD_HS,
	output TD_RESET_N,
	input TD_VS,
	inout [15:0] OTG_DATA,
	output [1:0] OTG_ADDR,
	output OTG_CS_N,
	output OTG_WR_N,
	output OTG_RD_N,
	input OTG_INT,
	output OTG_RST_N,
	input IRDA_RXD,
	output [12:0] DRAM_ADDR,
	output [1:0] DRAM_BA,
	output DRAM_CAS_N,
	output DRAM_CKE,
	output DRAM_CLK,
	output DRAM_CS_N,
	inout [31:0] DRAM_DQ,
	output [3:0] DRAM_DQM,
	output DRAM_RAS_N,
	output DRAM_WE_N,
	output [19:0] SRAM_ADDR,
	output SRAM_CE_N,
	inout [15:0] SRAM_DQ,
	output SRAM_LB_N,
	output SRAM_OE_N,
	output SRAM_UB_N,
	output SRAM_WE_N,
	output [22:0] FL_ADDR,
	output FL_CE_N,
	inout [7:0] FL_DQ,
	output FL_OE_N,
	output FL_RST_N,
	input FL_RY,
	output FL_WE_N,
	output FL_WP_N,
	inout [35:0] GPIO,
	input HSMC_CLKIN_P1,
	input HSMC_CLKIN_P2,
	input HSMC_CLKIN0,
	output HSMC_CLKOUT_P1,
	output HSMC_CLKOUT_P2,
	output HSMC_CLKOUT0,
	inout [3:0] HSMC_D,
	input [16:0] HSMC_RX_D_P,
	output [16:0] HSMC_TX_D_P,
	inout [6:0] EX_IO
);

// Camera to GPIO wrapper
Camera_GPIO_wrapper camera_gpio_inst (
	.GPIO(GPIO),
	.pixclk(Camera_CLK),
	.data(Camera_data),
	.lval(Camera_LVAL),
	.fval(Camera_FVAL),
	.strobe(Camera_strobe),
	.xclkin(Camera_XCLKIN),
	.reset_n(KEY[1]),
	.trigger(1'b1),
	.sclk(Camera_SCLK),
	.sdata(Camera_SDAT)
);


wire keydown;

Debounce deb0(
	.i_in(KEY[0]),
	.i_rst_n(KEY[1]),
	.i_clk(CLOCK_50),
	.o_neg(keydown)
);

// pll
sdram_pll pll_0(
	.inclk0(CLOCK_50),
	.c0(sdram_ctrl_clk),
	.c1(DRAM_CLK),
	.c2(Camera_XCLKIN), //25M
	.c3(VGA_CLK)     	//25M 
	.c4()     			//40M
);

// SevenHexDecoder seven_dec0(
// 	.i_hex(random_value),
// 	.o_seven_ten(HEX1),
// 	.o_seven_one(HEX0)
// );

logic [11:0] Camera_data;
logic Camera_FVAL;
logic Camera_LVAL;
logic [7:0] camera_Red, camera_Green, camera_Blue;
logic raw2RGB_valid;
logic [15:0] Camera_raw_data;
logic [9:0] raw_X, raw_Y;
logic [9:0] pixel_X, pixel_Y;
logic [31:0] Frame_cnt;
logic [23:0] SDRAM_to_SRAM_data;
logic SDRAM_to_SRAM_valid;
logic [23:0] SRAM_to_SDRAM_data;
logic SRAM_to_SDRAM_valid;
logic [9:0] iter_cnt;
logic [23:0] SDRAM_to_VGA_data;
logic VGA_Read;
logic Capture;
logic Camera_strobe;
logic Camera_CLK;
logic Camera_SCLK;
logic Camera_XCLKIN;
logic Camera_SDAT;
logic DSP_start, DSP_start_d;
logic Camera_valid;
logic sdram_ctrl_clk;

assign VGA_R = vga_r10[9:2];
assign VGA_G = vga_g10[9:2];
assign VGA_B = vga_b10[9:2];

// SDRAM Controller
SDRAM_control	sdram_ctrl_0	(	
	.RESET_N(KEY[1]),
	.CLK(sdram_ctrl_clk),
	// FIFO Write Side 1: from Camera raw2RGB
	.WR1_DATA({camera_Red, camera_Green, camera_Blue}), // Data Input
	.WR1(raw2RGB_valid),          						// Write Request
	.WR1_ADDR(23'd0),     								// Write Start Address
	.WR1_MAX_ADDR(23'd12288), 							// Write Max Address (128x128x3/4 = 12288)
	.WR1_LENGTH(8'd64),									// Write Burst Length
	.WR1_LOAD(KEY[1]),     								// Write FIFO Clear
	.WR1_CLK(Camera_CLK),      							// Write FIFO Clock
	// FIFO Write Side 2: from Memory Transfer
	.WR2_DATA(SRAM_to_SDRAM_data),          			// Data Input
	.WR2(SRAM_to_SDRAM_valid),          				// Write Request
	.WR2_ADDR(23'd12288*(iter_cnt+1)),     				// Write Start Address
	.WR2_MAX_ADDR(23'd12288*(iter_cnt+2)), 				// Write Max Address
	.WR2_LENGTH(8'd64),									// Write Burst Length
	.WR2_LOAD(KEY[1]),     								// Write FIFO Clear
	.WR2_CLK(CLOCK_50),      								// Write FIFO Clock
	// FIFO Read Side 1: from VGA
	.RD1_DATA(SDRAM_to_VGA_data),     					// Data Output
	.RD1(VGA_Read),          							// Read Request
	.RD1_ADDR(23'd12288*iter_cnt),     					// Read Start Address
	.RD1_MAX_ADDR(23'd12288*(iter_cnt+1)), 				// Read Max Address
	.RD1_LENGTH(8'd64),									// Read Burst Length
	.RD1_LOAD(KEY[1]),     								// Read FIFO Clear
	.RD1_CLK(VGA_CLK),      							// Read FIFO Clock
	// FIFO Read Side 2: from Memory Transfer
	.RD2_DATA(SDRAM_to_SRAM_data),     					// Data Output
	.RD2(SRAM_Read),          							// Read Request
	.RD2_ADDR(23'd0),     								// Read Start Address
	.RD2_MAX_ADDR(23'd12288), 							// Read Max Address
	.RD2_LENGTH(8'd64),									// Read Burst Length
	.RD2_LOAD(KEY[1] || DSP_start),     				// Read FIFO Clear
	.RD2_CLK(CLOCK_50),      							// Read FIFO Clock
	// SDRAM Side
	.DRAM_ADDR(DRAM_ADDR),
	.DRAM_BA(DRAM_BA),
	.DRAM_CAS_N(DRAM_CAS_N),
	.DRAM_CKE(DRAM_CKE),
	.DRAM_CLK(DRAM_CLK),
	.DRAM_CS_N(DRAM_CS_N),
	.DRAM_DQ(DRAM_DQ),
	.DRAM_DQM(DRAM_DQM),
	.DRAM_RAS_N(DRAM_RAS_N),
	.DRAM_WE_N(DRAM_WE_N)
);

// Camera Modules
Camera_I2C_config  camera_i2c_0 (
	.iCLK(CLOCK_50),
	.iRST_N(KEY[1]),
	.iZOOM_MODE_SW(1'b0),
	.iEXPOSURE_ADJ(1'b0),
	.iEXPOSURE_DEC_p(1'b0),
	// I2C Side
	.I2C_SCLK(Camera_SCLK),
	.I2C_SDAT(Camera_SDAT)
);

Camera_capture  camera_capture_0 (
	.iDATA(Camera_data),
	.iFVAL(Camera_FVAL),
	.iLVAL(Camera_LVAL),
	.iSTART(KEY[1] | keydown),
	.iEND(1'b0),
	.iCLK(Camera_CLK),
	.iRST(KEY[1]),
	.oDATA(Camera_raw_data),
	.oX_Cnt(raw_X),
	.oY_Cnt(raw_Y),
	.oFrame_Cnt(Frame_cnt),
	.oDVAL(Camera_valid)
);

Camera_raw2RGB  camera_raw2RGB_0 (
	.iCLK(Camera_CLK),
	.iRST(KEY[1]),
	.iData(Camera_raw_data),
	.iDval(Camera_valid),
	.iX_Cnt(raw_X),
	.iY_Cnt(raw_Y),
	.oRed(camera_Red),
	.oGreen(camera_Green),
	.oBlue(camera_Blue),
	.o_x(pixel_X),
	.o_y(pixel_Y),
	.oDval(raw2RGB_valid)
);

// VGA Module
VGA	vga_0	(	//	Host Side
          .iRed(mRed),
          .iGreen(mGreen),
          .iBlue(mBlue),
          .oCurrent_X(VGA_X),
          .oCurrent_Y(VGA_Y),
          .oRequest(VGA_Read),
          //	VGA Side
          .oVGA_R(vga_r10 ),
          .oVGA_G(vga_g10 ),
          .oVGA_B(vga_b10 ),
          .oVGA_HS(VGA_HS),
          .oVGA_VS(VGA_VS),
          .oVGA_SYNC(VGA_SYNC_N),
          .oVGA_BLANK(VGA_BLANK_N),
          .oVGA_CLOCK(VGA_CLK),
          //	Control Signal
          .iCLK(TD_CLK27),
          .iRST_N(KEY[1])
);

// tmp, for testing
always_ff @(posedge CLOCK_50 or negedge KEY[1]) begin
	if (!KEY[1]) begin
		iter_cnt <= 10'd0;
		DSP_start_d <= 1'b0;
		DSP_start <= 1'b0;
	end
	else begin
		iter_cnt <= 10'd0;
		DSP_start_d <= DSP_start;
		DSP_start <= keydown;
	end
end

assign HEX0 = '1;
assign HEX1 = '1;
assign HEX2 = '1;
assign HEX3 = '1;
assign HEX4 = '1;
assign HEX5 = '1;
assign HEX6 = '1;
assign HEX7 = '1;


endmodule
