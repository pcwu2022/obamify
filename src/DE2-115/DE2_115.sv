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
	input [11:0] D5M_D,
	input D5M_FVAL,
	input D5M_LVAL,
	input D5M_PIXLCLK,
	output D5M_RESET_N,
	output D5M_SCLK,
	inout D5M_SDATA,
	input D5M_STROBE,
	output D5M_TRIGGER,
	output D5M_XCLKIN
);

// SevenHexDecoder seven_dec0(
// 	.i_hex(random_value),
// 	.o_seven_ten(HEX1),
// 	.o_seven_one(HEX0)
// );

logic [7:0] camera_Red, camera_Green, camera_Blue;
logic raw2RGB_valid;
logic [15:0] Camera_raw_data;
logic [9:0] raw_X, raw_Y;
logic [9:0] pixel_X, pixel_Y;
logic [31:0] Frame_cnt;
logic [31:0] SDRAM_to_SRAM_data;
logic SDRAM_to_SRAM_valid;
logic [31:0] SRAM_to_SDRAM_data;
logic SRAM_to_SDRAM_valid;
logic [9:0] iter_cnt_r, iter_cnt_w;
logic [31:0] SDRAM_to_VGA_data;
logic VGA_Read;
logic DSP_start, DSP_start_d;
logic Camera_valid;
logic [9:0] vga_r10;
logic [9:0] vga_g10;
logic [9:0] vga_b10;
logic [9:0] mRed;
logic [9:0] mGreen;
logic [9:0] mBlue;
logic sdram_ctrl_clk;
logic DLY_RST_0, DLY_RST_1, DLY_RST_2, DLY_RST_3, DLY_RST_4;
logic auto_start;
logic [11:0] rCCD_DATA;
logic        rCCD_LVAL;
logic        rCCD_FVAL;
logic mt_SRAM_ce, mt_SRAM_we;
logic [19:0] mt_SRAM_addr;
logic SRAM_Read;
logic mt_SDRAM_write;
logic [15:0] mt_SRAM_data_in;
logic [15:0] mt_SRAM_data_out;
logic mt_done;
logic cl_SRAM_ce;
logic [19:0] cl_SRAM_addr;
logic [15:0] cl_SRAM_data;
logic [2:0] cl_result;
logic cl_done;
logic [2:0] state_r, state_w;
logic DSP_START_0, DSP_START_1, DSP_START_2, DSP_START_3, DSP_START_4;
// ============== signal ===================
logic vga_done;
logic o_classifier_start, o_classifier_done;
assign VGA_R 		= vga_r10[9:2];
assign VGA_G 		= vga_g10[9:2];
assign VGA_B 		= vga_b10[9:2];
assign D5M_TRIGGER 	= 1'b1;
assign D5M_RESET_N 	= DLY_RST_1;

assign mRed 		= {SDRAM_to_VGA_data[23:16], 2'b00};
// assign mRed 		= {SDRAM_to_VGA_data[7:0], 2'b00};
assign mGreen 		= {SDRAM_to_VGA_data[15:8], 2'b00};
assign mBlue 		= {SDRAM_to_VGA_data[7:0], 2'b00};
// assign mBlue 		= {SDRAM_to_VGA_data[23:16], 2'b00};

assign auto_start = ((KEY[1])&&(DLY_RST_3)&&(!DLY_RST_4))? 1'b1:1'b0;

logic keydown1, keydown2;

Top top1(
	.i_clk(CLOCK_50),
	.i_rst_n(KEY[0]),

	.i_key_1(keydown1),
	.i_key_2(keydown2),

	.i_vga_done(vga_done),
	.i_classifier_done(),
	.i_obamify_finished(),
	.i_obamify_epoch_finished(),
	.i_memory_done(),

	.o_camera_start(),
	.o_camera_end(),
	.o_classifier_start(),
	.o_obamify_start(),
	.o_obamify_epoch_start(),
	.o_memory_start(),
	.o_state()
);

Debounce deb1(
	.i_in(KEY[1]),
	.i_rst_n(KEY[0]),
	.i_clk(CLOCK_50),
	.o_neg(keydown1)
);

Debounce deb2(
	.i_in(KEY[2]),
	.i_rst_n(KEY[0]),
	.i_clk(CLOCK_50),
	.o_neg(keydown2)
);

Reset_Delay reset_delay0(
	.iCLK(CLOCK_50),
	.iRST(KEY[1]),
	.oRST_0(DLY_RST_0),
	.oRST_1(DLY_RST_1),
	.oRST_2(DLY_RST_2),
	.oRST_3(DLY_RST_3),
	.oRST_4(DLY_RST_4)
);

Reset_Delay reset_delay1(
	.iCLK(CLOCK_50),
	.iRST(!keydown1),
	.oRST_0(DSP_START_0),
	.oRST_1(DSP_START_1),
	.oRST_2(DSP_START_2),
	.oRST_3(DSP_START_3),
	.oRST_4(DSP_START_4)
);

// pll
sdram_pll pll_0(
	.inclk0(CLOCK_50),
	.c0(sdram_ctrl_clk),
	.c1(DRAM_CLK),
	.c2(D5M_XCLKIN), //25M
	.c3(VGA_CLK_in),     	//25M 
	.c4()     			//40M
);

// SDRAM Controller
SDRAM_control	sdram_ctrl_0	(	
	.RESET_N(KEY[1]),
	.CLK(sdram_ctrl_clk),
	// FIFO Write Side 1: from Camera raw2RGB
	// .WR1_DATA({8'd0, camera_Red, camera_Green, camera_Blue}), // Data Input
	.WR1_DATA({8'd0, camera_Blue, camera_Green, camera_Red}), // Data Input
	.WR1(raw2RGB_valid),          						// Write Request
	.WR1_ADDR(23'd0),     								// Write Start Address
	.WR1_MAX_ADDR(23'd16384), 							// Write Max Address (128x128x3/4 = 12288)
	.WR1_LENGTH(8'd128),									// Write Burst Length
	.WR1_LOAD(!DLY_RST_0),     								// Write FIFO Clear
	.WR1_CLK(D5M_PIXLCLK),      							// Write FIFO Clock
	// FIFO Write Side 2: from Memory Transfer
	.WR2_DATA(SRAM_to_SDRAM_data),          			// Data Input
	.WR2(SRAM_to_SDRAM_valid),          				// Write Request
	.WR2_ADDR(23'd16384*(iter_cnt_r+1)),     				// Write Start Address
	.WR2_MAX_ADDR(23'd16384*(iter_cnt_r+2)), 				// Write Max Address
	.WR2_LENGTH(8'd128),									// Write Burst Length
	.WR2_LOAD(!DLY_RST_0),     								// Write FIFO Clear
	.WR2_CLK(CLOCK_50),      								// Write FIFO Clock
	// FIFO Read Side 1: from VGA
	.RD1_DATA(SDRAM_to_VGA_data),     					// Data Output
	.RD1(VGA_Read),          							// Read Request
	.RD1_ADDR(23'd16384*iter_cnt_r),     					// Read Start Address
	.RD1_MAX_ADDR(23'd16384*(iter_cnt_r+1)), 				// Read Max Address
	.RD1_LENGTH(8'd128),									// Read Burst Length
	.RD1_LOAD(!DLY_RST_0),     							// Read FIFO Clear
	.RD1_CLK(~VGA_CLK_in),      							// Read FIFO Clock
	// FIFO Read Side 2: from Memory Transfer
	.RD2_DATA(SDRAM_to_SRAM_data),     					// Data Output
	.RD2(SRAM_Read),          							// Read Request
	.RD2_ADDR(23'd0),     								// Read Start Address
	.RD2_MAX_ADDR(23'd16384), 							// Read Max Address
	.RD2_LENGTH(8'd128),									// Read Burst Length
	.RD2_LOAD(!DLY_RST_0 || keydown1),     				// Read FIFO Clear
	.RD2_CLK(~CLOCK_50),      							// Read FIFO Clock
	// SDRAM Side
	.SA(DRAM_ADDR),
	.BA(DRAM_BA),
	.CS_N(DRAM_CS_N),
	.CKE(DRAM_CKE),
	.RAS_N(DRAM_RAS_N),
	.CAS_N(DRAM_CAS_N),
	.WE_N(DRAM_WE_N),
	.DQ(DRAM_DQ),
	.DQM(DRAM_DQM)
);

// SRAM Controller
SRAM_control	sram_ctrl_0	(
    .i_state(state_r),
    // Memory transfer side
    .i_mt_ce(mt_SRAM_ce),
    .i_mt_we(mt_SRAM_we),
    .i_mt_addr(mt_SRAM_addr),
    .i_mt_data(mt_SRAM_data_out),
    .o_mt_data(mt_SRAM_data_in),
    // Classifier side
    .i_cl_ce(cl_SRAM_ce),
    .i_cl_addr(cl_SRAM_addr),
    .o_cl_data(cl_SRAM_data),
    // Obamify side
    .i_ob_ce(),
    .i_ob_we(),
    .i_ob_addr(),
    .i_ob_data(),
    .o_ob_data(),
    // SRAM interface
    .SRAM_DQ(SRAM_DQ),
    .SRAM_ADDR(SRAM_ADDR),
    .SRAM_CE_N(SRAM_CE_N),
    .SRAM_OE_N(SRAM_OE_N),
    .SRAM_UB_N(SRAM_UB_N),
    .SRAM_LB_N(SRAM_LB_N),
    .SRAM_WE_N(SRAM_WE_N)
);

// Memory Transfer Module
Memory_transfer	memory_transfer_0	(
	.i_clk(CLOCK_50),
	.i_rst_n(DLY_RST_0),
	// SRAM interface
	.i_SRAM_data(mt_SRAM_data_in),
	.o_SRAM_addr(mt_SRAM_addr),
	.o_SRAM_enable(mt_SRAM_ce),
	.o_SRAM_write(mt_SRAM_we),
	.o_SRAM_data(mt_SRAM_data_out),
	// tmp
	.i_iter_cnt(iter_cnt_r),
	// SDRAM interface
	.i_SDRAM_data(SDRAM_to_SRAM_data),
	.o_SDRAM_read(SRAM_Read),
	.o_SDRAM_write(SRAM_to_SDRAM_valid),
	.o_SDRAM_data(SRAM_to_SDRAM_data),
	// Control signals
	.i_SRAM_to_SDRAM_valid(1'b0),
	.i_SDRAM_to_SRAM_valid(DSP_START_3 && !DSP_START_4),
	.o_done(mt_done)
);

// Camera Modules
Camera_I2C_config  camera_i2c_0 (
	.iCLK(CLOCK_50),
	.iRST_N(DLY_RST_2),
	.iZOOM_MODE_SW(SW[0]),
	.iEXPOSURE_ADJ(1'b1),
	.iEXPOSURE_DEC_p(1'b0),
	// I2C Side
	.I2C_SCLK(D5M_SCLK),
	.I2C_SDAT(D5M_SDATA)
);

Camera_capture  camera_capture_0 (
	.iDATA(rCCD_DATA),
	.iFVAL(rCCD_FVAL),
	.iLVAL(rCCD_LVAL),
	.iSTART(auto_start),
	.iEND(keydown1),
	.iCLK(~D5M_PIXLCLK),
	.iRST(DLY_RST_2),
	.oDATA(Camera_raw_data),
	.oX_Cnt(raw_X),
	.oY_Cnt(raw_Y),
	.oFrame_Cnt(Frame_cnt),
	.oDVAL(Camera_valid)
);

Camera_raw2RGB  camera_raw2RGB_0 (
	.iCLK(D5M_PIXLCLK),
	.iRST(DLY_RST_1),
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

// Classifier Module
Classifier classifier_0 (
	.i_clk(CLOCK_50),
	.i_rst_n(DLY_RST_0),
	.i_start(mt_done),
	.i_SRAM_data(cl_SRAM_data),
	.o_SRAM_addr(cl_SRAM_addr),
	.o_SRAM_enable(cl_SRAM_ce),
	.o_result(cl_result),
	.o_done(cl_done)
);

// VGA Module
VGA	vga_0	(	//	Host Side
	.iRed(mRed),
	.iGreen(mGreen),
	.iBlue(mBlue),
	.oAddress(), //not used
	.oRequest(VGA_Read),
	.o_done(vga_done),
	//	VGA Side
	.oVGA_R(vga_r10),
	.oVGA_G(vga_g10),
	.oVGA_B(vga_b10),
	.oVGA_HS(VGA_HS),
	.oVGA_VS(VGA_VS),
	.oVGA_SYNC(VGA_SYNC_N),
	.oVGA_BLANK(VGA_BLANK_N),
	.oVGA_CLOCK(VGA_CLK),
	.o_done(),
	//	Control Signal
	.iCLK(VGA_CLK_in),
	.iRST_N(DLY_RST_2)
);

// tmp, for testing
always_comb begin
	// if (mt_done) iter_cnt_w = iter_cnt_r + 10'd1;
	// else iter_cnt_w = iter_cnt_r;
	iter_cnt_w = iter_cnt_r;
	if (mt_done) begin
		state_w = 3'd1;
	end
	else begin
		state_w = state_r;
	end
end

always_ff @(posedge CLOCK_50 or negedge DLY_RST_2) begin
	if (!DLY_RST_2) begin
		iter_cnt_r <= 10'd0;
		DSP_start_d <= 1'b0;
		DSP_start <= 1'b0;
		state_r <= 3'd2;
	end
	else begin
		iter_cnt_r <= iter_cnt_w;
		DSP_start_d <= DSP_start;
		DSP_start <= keydown0;
		state_r <= state_w;
	end
end

always@(posedge D5M_PIXLCLK)
begin
	rCCD_DATA	<=	D5M_D;
	rCCD_LVAL	<=	D5M_LVAL;
	rCCD_FVAL	<=	D5M_FVAL;
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
