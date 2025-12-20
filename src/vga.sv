module	VGA	(	//	Host Side
	input iRed,
	input iGreen,
	input iBlue,
	output oAddress,
	output oRequest,
	//	VGA Side
	output oVGA_R,
	output oVGA_G,
	output oVGA_B,
	output oVGA_HS,
	output oVGA_VS,
	output oVGA_SYNC,
	output oVGA_BLANK,
	output oVGA_CLOCK,
	//	Control Signal
	input	 iCLK,
	input	 iRST_N	
);

//	Host Side
logic		[9:0]	iRed;
logic		[9:0]	iGreen;
logic		[9:0]	iBlue;
logic		[21:0]	oAddress;
// Host Side
logic  [9:0]  iRed;
logic  [9:0]  iGreen;
logic  [9:0]  iBlue;
logic  [21:0] oAddress;
logic  [10:0] oCurrent_X;
logic  [10:0] oCurrent_Y;
output logic         oRequest;
// VGA Side
logic  [9:0]  oVGA_R;
logic  [9:0]  oVGA_G;
logic  [9:0]  oVGA_B;
logic         oVGA_HS;
logic         oVGA_VS;
logic         oVGA_SYNC;
logic         oVGA_BLANK;
logic         oVGA_CLOCK;
// Control Signal
logic         iCLK;
logic         iRST_N;    
// Internal Registers
logic  [10:0] H_Cont;
logic  [10:0] V_Cont;

////////////////////////////////////////////////////////////
//	Horizontal Parameter
parameter	H_FRONT	=	16;
parameter	H_SYNC	=	96;
parameter	H_BACK	=	48;
parameter	H_ACT	=	640;
parameter	H_BLANK	=	H_FRONT+H_SYNC+H_BACK;
parameter	H_TOTAL	=	H_FRONT+H_SYNC+H_BACK+H_ACT;
////////////////////////////////////////////////////////////
//	Vertical Parameter
parameter	V_FRONT	=	11;
parameter	V_SYNC	=	2;
parameter	V_BACK	=	31;
parameter	V_ACT	=	480;
parameter	V_BLANK	=	V_FRONT+V_SYNC+V_BACK;
parameter	V_TOTAL	=	V_FRONT+V_SYNC+V_BACK+V_ACT;
////////////////////////////////////////////////////////////
assign	oVGA_SYNC	=	1'b1;			//	This pin is unused.
assign	oVGA_BLANK	=	~((H_Cont<H_BLANK)||(V_Cont<V_BLANK));
assign	oVGA_CLOCK	=	~iCLK;
assign	oVGA_R		=	10'b0000010100 //iRed;
assign	oVGA_G		=	10'b0000010100//iGreen;
assign	oVGA_B		=	10'b0000010100//iBlue;
assign	oAddress	=	oCurrent_Y*H_ACT+oCurrent_X;
assign	oRequest	=	((H_Cont>=H_BLANK && H_Cont<H_TOTAL)	&&
						 (V_Cont>=V_BLANK && V_Cont<V_TOTAL));
assign	oCurrent_X	=	(H_Cont>=H_BLANK)	?	H_Cont-H_BLANK	:	11'h0	;
assign	oCurrent_Y	=	(V_Cont>=V_BLANK)	?	V_Cont-V_BLANK	:	11'h0	;

//	Horizontal Generator: Refer to the pixel clock
always_ff @(posedge iCLK or negedge iRST_N)
begin
	if(!iRST_N)
	begin
		H_Cont		<=	0;
		oVGA_HS		<=	1;
	end
	else
	begin
		if(H_Cont<H_TOTAL)
			H_Cont	<=	H_Cont+1'b1;
		else
			H_Cont	<=	0;
		//	Horizontal Sync
		if(H_Cont==H_FRONT-1)			//	Front porch end
			oVGA_HS	<=	1'b0;
		if(H_Cont==H_FRONT+H_SYNC-1)	//	Sync pulse end
			oVGA_HS	<=	1'b1;
	end
end

//	Vertical Generator: Refer to the horizontal sync
always_ff @(posedge oVGA_HS or negedge iRST_N)
begin
	if(!iRST_N)
	begin
		V_Cont		<=	0;
		oVGA_VS		<=	1;
	end
	else
	begin
		if(V_Cont<V_TOTAL)
			V_Cont	<=	V_Cont+1'b1;
		else
			V_Cont	<=	0;
		//	Vertical Sync
		if(V_Cont==V_FRONT-1)			//	Front porch end
			oVGA_VS	<=	1'b0;
		if(V_Cont==V_FRONT+V_SYNC-1)	//	Sync pulse end
			oVGA_VS	<=	1'b1;
	end
end

endmodule