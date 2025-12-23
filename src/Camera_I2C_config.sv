`include "VGA_Param.vh"
module Camera_I2C_config (
    input  logic       iCLK,
    input  logic       iRST_N,
    input  logic       iZOOM_MODE_SW,
    input  logic       iEXPOSURE_ADJ,
    input  logic       iEXPOSURE_DEC_p,
	output wire        I2C_SCLK,
	inout  wire        I2C_SDAT
);

logic [15:0] mI2C_CLK_DIV;
logic [31:0] mI2C_DATA;
logic        mI2C_CTRL_CLK;
logic        mI2C_GO;
logic        mI2C_END;
logic        mI2C_ACK;
logic [23:0] LUT_DATA;
logic [5:0]  LUT_INDEX;
logic [3:0]  mSetup_ST;


//////////////   CMOS sensor registers setting //////////////////////

//parameter   default_exposure           = 16'h07c0;
parameter   default_exposure           = 16'h03E8;
parameter   exposure_change_value      = 16'd200;

logic [24:0] combo_cnt;
logic        combo_pulse;

logic [1:0]  izoom_mode_sw_delay;

logic [3:0]  iexposure_adj_delay;
logic        exposure_adj_set;
logic        exposure_adj_reset;
logic [15:0] sensor_exposure;
logic [17:0] sensor_exposure_temp;

logic [23:0] sensor_start_row;
logic [23:0] sensor_start_column;
logic [23:0] sensor_row_size;
logic [23:0] sensor_column_size; 
logic [23:0] sensor_row_mode;
logic [23:0] sensor_column_mode;

assign sensor_start_row 		= iZOOM_MODE_SW ?  24'h0102CC : 24'h0101CC; // 716 or 460
assign sensor_start_column 		= iZOOM_MODE_SW ?  24'h020410 : 24'h020310; // 1040 or 784
// `ifdef VGA_640x480p60
// assign sensor_row_size	 		= iZOOM_MODE_SW ?  24'h0303BF : 24'h03077F;
// assign sensor_column_size 		= iZOOM_MODE_SW ?  24'h0404FF : 24'h0409FF;
// `else
// assign sensor_row_size	 		= iZOOM_MODE_SW ?  24'h030257 : 24'h0304AF; //600
// assign sensor_column_size 		= iZOOM_MODE_SW ?  24'h04031F : 24'h04063F; //800
// `endif
assign sensor_row_size	 		= iZOOM_MODE_SW ?  24'h0301FF : 24'h0303FF; // 512 or 1024
assign sensor_column_size 		= iZOOM_MODE_SW ?  24'h0401FF : 24'h0403FF; // 512 or 1024

assign sensor_row_mode 			= iZOOM_MODE_SW ?  24'h220011 : 24'h220033;
assign sensor_column_mode		= iZOOM_MODE_SW ?  24'h230011 : 24'h230033;

	
always_ff @(posedge iCLK or negedge iRST_N) begin
    if (!iRST_N)
        iexposure_adj_delay <= '0;
    else 
        iexposure_adj_delay <= {iexposure_adj_delay[2:0],iEXPOSURE_ADJ};
end

assign 	exposure_adj_set = ({iexposure_adj_delay[0],iEXPOSURE_ADJ}==2'b10) ? 1 : 0 ;
assign  exposure_adj_reset = ({iexposure_adj_delay[3:2]}==2'b10) ? 1 : 0 ;		
assign  sensor_exposure_temp = iEXPOSURE_DEC_p ? (sensor_exposure - exposure_change_value) : (sensor_exposure + exposure_change_value);

always_ff @(posedge iCLK or negedge iRST_N) begin
    if (!iRST_N)
        sensor_exposure <= default_exposure;
    else if (exposure_adj_set|combo_pulse)
        if (sensor_exposure_temp[17])
            sensor_exposure <= '0;
        else if (sensor_exposure_temp[16])
            sensor_exposure <= 16'hffff;
        else
            sensor_exposure <= sensor_exposure_temp[15:0];
end			
				
		
always_ff @(posedge iCLK or negedge iRST_N) begin
    if (!iRST_N)
        combo_cnt <= '0;
    else if (!iexposure_adj_delay[3])
        combo_cnt <= combo_cnt + 1'b1;
    else
        combo_cnt <= '0;
end
	
assign combo_pulse = (combo_cnt == 25'h1fffff) ? 1 : 0;				
		
logic	i2c_reset;		

assign i2c_reset = iRST_N & ~exposure_adj_reset & ~combo_pulse ;

/////////////////////////////////////////////////////////////////////

//	Clock Setting
parameter	CLK_Freq	=	50000000;	//	50	MHz
parameter	I2C_Freq	=	20000;		//	20	KHz
//	LUT Data Number
parameter	LUT_SIZE	=	25;

/////////////////////	I2C Control Clock	////////////////////////
always_ff @(posedge iCLK or negedge i2c_reset) begin
	if(!i2c_reset)
	begin
		mI2C_CTRL_CLK <= 1'b0;
		mI2C_CLK_DIV  <= '0;
	end
	else
	begin
		if (mI2C_CLK_DIV < (CLK_Freq/I2C_Freq))
			mI2C_CLK_DIV <= mI2C_CLK_DIV + 16'd1;
		else begin
			mI2C_CLK_DIV  <= '0;
			mI2C_CTRL_CLK <= ~mI2C_CTRL_CLK;
		end
	end
end
////////////////////////////////////////////////////////////////////
Camera_I2C_controller 	u0	(	.CLOCK(mI2C_CTRL_CLK),
						.I2C_SCLK(I2C_SCLK),
						.I2C_SDAT(I2C_SDAT),
						.I2C_DATA(mI2C_DATA),
						.GO(mI2C_GO),
						.o_END(mI2C_END),
						.ACK(mI2C_ACK),
						.RESET(i2c_reset)
					);
////////////////////////////////////////////////////////////////////
//////////////////////	Config Control	////////////////////////////
//always@(posedge mI2C_CTRL_CLK or negedge iRST_N)
always_ff @(posedge mI2C_CTRL_CLK or negedge i2c_reset) begin
	if(!i2c_reset)
	begin
		LUT_INDEX 	<= 6'd0;
		mSetup_ST 	<= 3'd0;
		mI2C_GO 	<= 1'b0;

	end

	else if(LUT_INDEX<LUT_SIZE)
		begin
			case(mSetup_ST)
			3'd0:	begin
					mI2C_DATA 	<= {8'hBA,LUT_DATA};
					mI2C_GO 	<= 1'b1;
					mSetup_ST	<= 3'd1;
				end
			3'd1:	begin
					if(mI2C_END)
					begin
						if(!mI2C_ACK)
						mSetup_ST	<= 3'd2;
						else
						mSetup_ST	<= 3'd0;							
						mI2C_GO		<= 1'b0;
					end
				end
			3'd2:	begin
					LUT_INDEX	<= LUT_INDEX + 6'd1;
					mSetup_ST	<= 3'd0;
				end
			endcase
		end
end
////////////////////////////////////////////////////////////////////
/////////////////////	Config Data LUT	  //////////////////////////		
always_comb begin
	case(LUT_INDEX)
	6'd0	:	LUT_DATA	<=	24'h000000;
	6'd1	:	LUT_DATA	<=	24'h20c000;				//	Mirror Row and Columns
	6'd2	:	LUT_DATA	<=	{8'h09,sensor_exposure};//	Exposure
	6'd3	:	LUT_DATA	<=	24'h050000;				//	H_Blanking
	6'd4	:	LUT_DATA	<=	24'h060019;				//	V_Blanking	
	6'd5	:	LUT_DATA	<=	24'h0A8000;				//	change latch
	6'd6	:	LUT_DATA	<=	24'h2B0013;				//	Green 1 Gain
	6'd7	:	LUT_DATA	<=	24'h2D019C;				//	Blue Gain
	6'd8	:	LUT_DATA	<=	24'h2C009A;				//	Red Gain
	6'd9	:	LUT_DATA	<=	24'h2E0013;				//	Green 2 Gain
	6'd10	:	LUT_DATA	<=	24'h100051;				//	set up PLL power on
`ifdef VGA_640x480p60	
	6'd11	:	LUT_DATA	<=	24'h111f04;				//	PLL_m_Factor<<8+PLL_n_Divider
	6'd12	:	LUT_DATA	<=	24'h120001;				//	PLL_p1_Divider
`else
	6'd11	:	LUT_DATA	<=	24'h111805;				//	PLL_m_Factor<<8+PLL_n_Divider
	6'd12	:	LUT_DATA	<=	24'h120001;				//	PLL_p1_Divider
`endif
	6'd13	:	LUT_DATA	<=	24'h100053;				//	set USE PLL	 
	6'd14	:	LUT_DATA	<=	24'h980000;				//	disble calibration 	
	6'd15	:	LUT_DATA	<=	24'hA00000;				//	Test pattern control 
	6'd16	:	LUT_DATA	<=	24'hA10000;				//	Test green pattern value
	6'd17	:	LUT_DATA	<=	24'hA20FFF;				//	Test red pattern value
	6'd18	:	LUT_DATA	<=	sensor_start_row;	    //	set start row	
	6'd19	:	LUT_DATA	<=	sensor_start_column;	//	set start column 	
	6'd20	:	LUT_DATA	<=	sensor_row_size;		//	set row size	
	6'd21	:	LUT_DATA	<=	sensor_column_size;		//	set column size
	6'd22	:	LUT_DATA	<=	sensor_row_mode;		//	set row mode in bin mode
	6'd23	:	LUT_DATA	<=	sensor_column_mode;		//	set column mode	 in bin mode
	6'd24	:	LUT_DATA	<=	24'h4901A8;				//	row black target		
	default :   LUT_DATA	<=	24'h000000;
	endcase
end

endmodule