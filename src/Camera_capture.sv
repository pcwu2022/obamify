`include "VGA_Param.vh"
module Camera_capture(
    input  logic [11:0]	iDATA;
    input  logic 		iFVAL;
    input  logic 		iLVAL;
    input  logic 		iSTART;
    input  logic 		iEND;
    input  logic 		iCLK;
    input  logic 		iRST;
    output logic [11:0]	oDATA;
    output logic [15:0]	oX_Cnt;
    output logic [15:0]	oY_Cnt;
    output logic [31:0]	oFrame_Cnt;
    output logic 		oDVAL;
);

logic iFVAL_d;
logic iLVAL_d;
logic fval_r, fval_w;
logic lval_r, lval_w;
logic en_r, en_w;
logic [11:0] data_r, data_w;
logic [15:0] x_cnt_r, x_cnt_w;
logic [15:0] y_cnt_r, y_cnt_w;
logic [31:0] frame_cnt_r, frame_cnt_w;

`ifdef VGA_640x480p60
parameter COLUMN_WIDTH = 1280;
`else
parameter COLUMN_WIDTH = 800;
`endif

assign oDATA = data_r;
assign oX_Cnt = x_cnt_r;
assign oY_Cnt = y_cnt_r;
assign oFrame_Cnt = frame_cnt_r;
assign oDVAL = (fval_r & lval_r);

always_comb begin
    if (iEND) en_w = 1'b0;
    else if (iSTART) en_w = 1'b1;
    else en_w = en_r;
end

always_comb begin
    lval_w = iLVAL;

    if ({iFVAL_d, iFVAL} == 2'b01 && en_r) fval_w = 1'b1;
    else if ({iFVAL_d, iFVAL} == 2'b10) fval_w = 1'b0;
    else fval_w = fval_r;
end

always_comb begin
    if (fval_r) begin
        if (lval_r) begin
            if (x_cnt_r < (COLUMN_WIDTH - 1)) begin
                x_cnt_w = x_cnt_r + 16'd1;
                y_cnt_w = y_cnt_r;
            end else begin
                x_cnt_w = 16'd0;
                y_cnt_w = y_cnt_r + 16'd1;
            end
        end
        else begin
            x_cnt_w = x_cnt_r;
            y_cnt_w = y_cnt_r;
        end
    end
    else begin
        x_cnt_w = 16'd0;
        y_cnt_w = 16'd0;
    end
end

always_comb begin
    if ({iFVAL_d, iFVAL} == 2'b01 && en_r) frame_cnt_w = frame_cnt_r + 32'd1;
    else frame_cnt_w = frame_cnt_r;
end

always_comb begin
    if (iLVAL) data_w = iDATA;
    else data_w = 12'd0;
end

always_ff @(posedge iCLK or negedge iRST) begin
    if (!iRST) begin
        iFVAL_d <= 1'b0;
        iLVAL_d <= 1'b0;
        fval_r <= 1'b0;
        lval_r <= 1'b0;
        en_r <= 1'b0;
        data_r <= 12'd0;
        x_cnt_r <= 16'd0;
        y_cnt_r <= 16'd0;
        frame_cnt_r <= 32'd0;
    end else begin
        iFVAL_d <= iFVAL;
        iLVAL_d <= iLVAL;
        fval_r <= fval_w;
        lval_r <= lval_w;
        en_r <= en_w;
        data_r <= data_w;
        x_cnt_r <= x_cnt_w;
        y_cnt_r <= y_cnt_w;
        frame_cnt_r <= frame_cnt_w;
    end
end

endmodule