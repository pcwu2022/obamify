module Camera_capture (
    input  logic        iCLK,
    input  logic        iRST,
    input  logic [11:0] iDATA,
    input  logic        iFVAL,
    input  logic        iLVAL,
    input  logic        iSTART,
    input  logic        iEND,
    output logic [11:0] oDATA,
    output logic [15:0] oX_Cnt,
    output logic [15:0] oY_Cnt,
    output logic [31:0] oFrame_Cnt,
    output logic        oDVAL
);

logic        Pre_FVAL;
logic        mCCD_FVAL;
logic        mCCD_LVAL;
logic [11:0] mCCD_DATA;
logic [15:0] X_Cont;
logic [15:0] Y_Cont;
logic [31:0] Frame_Cont;
logic        mSTART;

parameter COLUMN_WIDTH = 256;

assign oX_Cnt     = X_Cont;
assign oY_Cnt     = Y_Cont;
assign oFrame_Cnt = Frame_Cont;
assign oDATA       = mCCD_DATA;
assign oDVAL       = mCCD_FVAL & mCCD_LVAL;

always_ff @(posedge iCLK or negedge iRST) begin
    if (!iRST)
        mSTART <= 1'b0;
    else begin
        if (iSTART)
            mSTART <= 1'b1;
        if (iEND)
            mSTART <= 1'b0;
    end
end

always_ff @(posedge iCLK or negedge iRST) begin
    if (!iRST) begin
        Pre_FVAL  <= 1'b0;
        mCCD_FVAL <= 1'b0;
        mCCD_LVAL <= 1'b0;
        X_Cont    <= 16'd0;
        Y_Cont    <= 16'd0;
    end
    else begin
        Pre_FVAL <= iFVAL;
        if (({Pre_FVAL, iFVAL} == 2'b01) && mSTART)
            mCCD_FVAL <= 1'b1;
        else if ({Pre_FVAL, iFVAL} == 2'b10)
            mCCD_FVAL <= 1'b0;
        mCCD_LVAL <= iLVAL;
        if (mCCD_FVAL) begin
            if (mCCD_LVAL) begin
                if (X_Cont < (COLUMN_WIDTH - 1))
                    X_Cont <= X_Cont + 16'd1;
                else begin
                    X_Cont <= 16'd0;
                    Y_Cont <= Y_Cont + 16'd1;
                end
            end
        end
        else begin
            X_Cont <= 16'd0;
            Y_Cont <= 16'd0;
        end
    end
end

always_ff @(posedge iCLK or negedge iRST) begin
    if (!iRST)
        Frame_Cont <= 32'd0;
    else begin
        if (({Pre_FVAL, iFVAL} == 2'b01) && mSTART)
            Frame_Cont <= Frame_Cont + 32'd1;
    end
end

always_ff @(posedge iCLK or negedge iRST) begin
    if (!iRST)
        mCCD_DATA <= 12'd0;
    else if (iLVAL)
        mCCD_DATA <= iDATA;
    else
        mCCD_DATA <= 12'd0;
end

logic        ifval_dealy;
logic [15:0] y_cnt_d;
logic        ifval_fedge;

always_ff @(posedge iCLK or negedge iRST) begin
    if (!iRST)
        y_cnt_d <= 16'd0;
    else
        y_cnt_d <= Y_Cont;
end

always_ff @(posedge iCLK or negedge iRST) begin
    if (!iRST)
        ifval_dealy <= 1'b0;
    else
        ifval_dealy <= iFVAL;
end

assign ifval_fedge = ({ifval_dealy, iFVAL} == 2'b10) ? 1'b1 : 1'b0;

endmodule