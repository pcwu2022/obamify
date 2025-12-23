module Camera_raw2RGB (
    input  logic        iCLK,
    input  logic        iRST,
    input  logic [10:0] iX_Cnt,
    input  logic [10:0] iY_Cnt,
    input  logic [11:0] iData,
    input  logic        iDval,
    output logic [11:0] oRed,
    output logic [11:0] oGreen,
    output logic [11:0] oBlue,
    output logic [15:0] o_x,
    output logic [15:0] o_y,
    output logic        oDval
);

logic [11:0] mDATA_0;
logic [11:0] mDATA_1;
logic [11:0] mDATAd_0;
logic [11:0] mDATAd_1;
logic [11:0] mCCD_R;
logic [12:0] mCCD_G;
logic [11:0] mCCD_B;
logic        mDVAL;

assign oRed   = mCCD_R[11:0];
assign oGreen = mCCD_G[12:1];
assign oBlue  = mCCD_B[11:0];
assign oDval  = mDVAL;
assign o_x = 16'd0;
assign o_y = 16'd0;

Line_Buffer1 u0 (
    .clken   (iDval),
    .clock   (iCLK),
    .shiftin (iData),
    .taps0x  (mDATA_1),
    .taps1x  (mDATA_0)
);

always_ff @(posedge iCLK or negedge iRST) begin
    if (!iRST) begin
        mCCD_R   <= 12'd0;
        mCCD_G   <= 13'd0;
        mCCD_B   <= 12'd0;
        mDATAd_0 <= 12'd0;
        mDATAd_1 <= 12'd0;
        mDVAL    <= 1'b0;
    end
    else begin
        mDATAd_0 <= mDATA_0;
        mDATAd_1 <= mDATA_1;
        mDVAL    <= (iY_Cnt[0] | iX_Cnt[0]) ? 1'b0 : iDval;
        
        case ({iY_Cnt[0], iX_Cnt[0]})
            2'b10: begin
                mCCD_R <= mDATA_0;
                mCCD_G <= mDATAd_0 + mDATA_1;
                mCCD_B <= mDATAd_1;
            end
            2'b11: begin
                mCCD_R <= mDATAd_0;
                mCCD_G <= mDATA_0 + mDATAd_1;
                mCCD_B <= mDATA_1;
            end
            2'b00: begin
                mCCD_R <= mDATA_1;
                mCCD_G <= mDATA_0 + mDATAd_1;
                mCCD_B <= mDATAd_0;
            end
            2'b01: begin
                mCCD_R <= mDATAd_1;
                mCCD_G <= mDATAd_0 + mDATA_1;
                mCCD_B <= mDATA_0;
            end
        endcase
    end
end

endmodule