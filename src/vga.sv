module	VGA	(	//	Host Side
	input [9:0] iRed,
	input [9:0] iGreen,
	input [9:0] iBlue,
	output [21:0] oAddress,
	output oRequest,
	//	VGA Side
	output [9:0] oVGA_R,
	output [9:0] oVGA_G,
	output [9:0] oVGA_B,
	output oVGA_HS,
	output oVGA_VS,
	output oVGA_SYNC,
	output oVGA_BLANK,
	output oVGA_CLOCK,
	//	Control Signal
	input	 iCLK,
	input	 iRST_N	
);

logic  		[10:0]  Current_X;
logic  		[10:0]  Current_Y;
   
// Internal Registers
logic  [10:0] H_Cont, H_Cont_nxt;
logic  [10:0] V_Cont, V_Cont_nxt;
logic hs_nxt, hs;
logic vs_nxt, vs;
logic o_addr_nxt, o_addr;
logic o_blank_nxt, o_blank;
logic o_request_nxt, o_request;
logic h_flag_nxt, h_flag;
logic v_flag_nxt, v_flag;
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
// Image Parameter
parameter	IMG_H	=	128;
parameter	IMG_V	=	128;
// parameter   H_MAR   =   (H_ACT - IMG_H)/2;
// parameter   V_MAR   =   (V_ACT - IMG_V)/2;
parameter   H_MAR   =   (H_ACT - 2*IMG_H)/2;
parameter   V_MAR   =   (V_ACT - 2*IMG_V)/2;
////////////////////////////////////////////////////////////
logic [2*IMG_H-1:0][9:0] h_back_up_r[0:2], h_back_up_w[0:2]; // RGB back up
logic [9:0] iRed_final;
logic [9:0] iGreen_final;
logic [9:0] iBlue_final;
assign	oVGA_SYNC	=	1'b1;			//	This pin is unused.
assign	oVGA_BLANK	=	~((H_Cont<H_BLANK)||(V_Cont<V_BLANK));
assign	oVGA_CLOCK	=	~iCLK;

assign	oAddress	=	Current_Y*H_ACT+Current_X;
assign	oRequest	=	((H_Cont>=H_BLANK+H_MAR-1 && H_Cont<=H_BLANK+H_MAR+2*IMG_H-2) && (V_Cont>=V_BLANK+V_MAR && V_Cont<=V_BLANK+V_MAR+2*IMG_V-1) && h_flag && v_flag) ? 1'b1 : 1'b0;
assign  in_frame    =   (H_Cont>=H_BLANK+H_MAR && H_Cont<=H_BLANK+H_MAR+2*IMG_H-1) && (V_Cont>=V_BLANK+V_MAR && V_Cont<=V_BLANK+V_MAR+2*IMG_V-1);
assign	Current_X	=	(H_Cont>=H_BLANK)	?	H_Cont-H_BLANK	:	11'h0	;
assign	Current_Y	=	(V_Cont>=V_BLANK)	?	V_Cont-V_BLANK	:	11'h0	;
assign	oVGA_HS		=	hs;
assign	oVGA_VS		=	vs;

assign	oVGA_R		=	(in_frame) ? iRed_final 	: 10'b0;   //(oVGA_BLANK == 1'b1) ? 10'b1000000000 : 10'b0000000000; //iRed;
assign	oVGA_G		=	(in_frame) ? iGreen_final 	: 10'b0; //10'b0000000000; //iGreen;
assign	oVGA_B		=	(in_frame) ? iBlue_final 	: 10'b0;  //10'b0000000000; //iBlue;

// assign	oVGA_R		=	(o_request == 1'b1) ? 10'b1000000000 	: 10'b0;   //(oVGA_BLANK == 1'b1) ? 10'b1000000000 : 10'b0000000000; //iRed;
// assign	oVGA_G		=	(o_request == 1'b1) ? 10'b0100000000 	: 10'b0; //10'b0000000000; //iGreen;
// assign	oVGA_B		=	(o_request == 1'b1) ? 10'b1100000000 	: 10'b0;  //10'b0000000000; //iBlue;

// assign	oVGA_R		=	(oVGA_BLANK == 1'b1) ? 10'b1000000000   : 10'b0;
// assign	oVGA_G		=	(oVGA_BLANK == 1'b1) ? 10'b0100000000 	: 10'b0;
// assign	oVGA_B		=	(oVGA_BLANK == 1'b1) ? 10'b1100000000 	: 10'b0;

always_comb begin
	for (int i = 0; i < 3; i++) begin
		for (int j = 0; j < 2*IMG_H; j++) begin
			h_back_up_w[i][j] = h_back_up_r[i][j];
		end
	end
	if(o_request) begin
		iRed_final   = iRed;
		iGreen_final = iGreen;
		iBlue_final  = iBlue;
		// iRed_final   = 10'b1000000000;
		// iGreen_final = 10'b0100000000;
		// iBlue_final  = 10'b0010000000;
		
		h_back_up_w[0][H_Cont-H_BLANK-H_MAR] = iRed;
		h_back_up_w[1][H_Cont-H_BLANK-H_MAR] = iGreen;
		h_back_up_w[2][H_Cont-H_BLANK-H_MAR] = iBlue;

		h_back_up_w[0][H_Cont-H_BLANK-H_MAR+1] = iRed;
		h_back_up_w[1][H_Cont-H_BLANK-H_MAR+1] = iGreen;
		h_back_up_w[2][H_Cont-H_BLANK-H_MAR+1] = iBlue;
	end
	else begin
		iRed_final   = h_back_up_r[0][H_Cont-H_BLANK-H_MAR];
		iGreen_final = h_back_up_r[1][H_Cont-H_BLANK-H_MAR];
		iBlue_final  = h_back_up_r[2][H_Cont-H_BLANK-H_MAR];
	end
end

always_comb begin
	if(H_Cont==H_TOTAL-1)
		h_flag_nxt = 1'b1;
	else if((H_Cont>=H_BLANK+H_MAR-1) && (H_Cont<=H_BLANK+H_MAR+2*IMG_H-2))
		h_flag_nxt = ~h_flag;
	else
		h_flag_nxt = h_flag;
	
	if (V_Cont==V_TOTAL-1)
		v_flag_nxt = 1'b1;
	else if((H_Cont==H_TOTAL-1) && (V_Cont>=V_BLANK+V_MAR) && (V_Cont<=V_BLANK+V_MAR+2*IMG_V-1))
		v_flag_nxt = ~v_flag;
	else
		v_flag_nxt = v_flag;
end

//	Horizontal Generator: Refer to the pixel clock
always_comb begin
	if(H_Cont<H_TOTAL-1)
		H_Cont_nxt = H_Cont+1'b1;
	else
		H_Cont_nxt = 0;
	//	Horizontal Sync
	if(H_Cont==H_FRONT-1)		begin	//	Front porch end
		hs_nxt	=	1'b0;
	end
	else if(H_Cont==H_FRONT+H_SYNC-1)	begin//	Sync pulse end
		hs_nxt	=	1'b1;
	end
	else begin
		hs_nxt	=	hs;
	end
end

//	Vertical Generator: Refer to the horizontal sync
always_comb begin
	if (hs_nxt == 1'b1 && hs == 1'b0) begin
		if(V_Cont<V_TOTAL-1)
			V_Cont_nxt	=	V_Cont+1'b1;
		else
			V_Cont_nxt	=	0;
		//	Vertical Sync
		if(V_Cont==V_FRONT-1)	begin		//	Front porch end
			vs_nxt	=	1'b0;
		end
		else if(V_Cont==V_FRONT+V_SYNC-1)	begin	//	Sync pulse end
			vs_nxt	=	1'b1;
		end
		else begin
			vs_nxt	=	vs;
		end
	end
	else begin
		V_Cont_nxt = V_Cont;
		vs_nxt = vs;
	end
	
end

always_comb begin 
	o_request_nxt = oRequest;
end

always_ff @(posedge iCLK or negedge iRST_N)
begin
	if(!iRST_N)
	begin
		H_Cont		<=	0;
		V_Cont		<=	0;
		hs			<=	1;
		vs			<=	1;
		o_request	<=	1'b0;
		h_flag		<=	1'b1;
		v_flag		<=	1'b1;
		for (int i = 0; i < 3; i++) begin
			for (int j = 0; j < 2*IMG_H; j++) begin
				h_back_up_r[i][j] <= 10'd0;
			end
		end
	end
	else
	begin
		H_Cont		<=	H_Cont_nxt;
		V_Cont		<=	V_Cont_nxt;
		hs			<=	hs_nxt;
		vs			<=	vs_nxt;
		o_request	<=	o_request_nxt;
		h_flag		<=	h_flag_nxt;
		v_flag		<=	v_flag_nxt;
		for (int i = 0; i < 3; i++) begin
			for (int j = 0; j < 2*IMG_H; j++) begin
				h_back_up_r[i][j] <= h_back_up_w[i][j];
			end
		end
	end
end

endmodule