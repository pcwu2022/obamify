`include "VGA_Param.vh"
module Camera_raw2RGB (
    input  logic 		iCLK,
    input  logic 		iRST,
    input  logic [11:0]	iData,
    input  logic 		iDval,
    input  logic [15:0]	iX_Cnt,
    input  logic [15:0]	iY_Cnt,
    output logic [7:0]	oRed,
    output logic [7:0]	oGreen,
    output logic [7:0]	oBlue,
    output logic [15:0] o_x,
    output logic [15:0] o_y,
    output logic 		oDval
);

logic [7:0]  r_data_r, r_data_w;
logic [8:0]  g_data_r, g_data_w;
logic [7:0]  b_data_r, b_data_w;
logic [15:0] x_cnt_r, x_cnt_w;
logic [15:0] y_cnt_r, y_cnt_w;
logic        dval_r, dval_w;

// Pipeline registers for timing fix
logic [15:0] iX_Cnt_d, iY_Cnt_d;
logic [11:0] iData_d;
logic        iDval_d;

// `ifdef VGA_640x480p60
// parameter COLUMN_WIDTH = 1280;
// `else
// parameter COLUMN_WIDTH = 800;
// `endif
parameter COLUMN_WIDTH = 256;

// line buffer
logic [7:0] buf_r[0:COLUMN_WIDTH-1], buf_w[0:COLUMN_WIDTH-1];

assign oRed   = r_data_r;
assign oGreen = g_data_r[7:0];
assign oBlue  = b_data_r;
assign o_x    = x_cnt_r;
assign o_y    = y_cnt_r;
assign oDval  = dval_r;

always_comb begin
    for (int i=0; i<COLUMN_WIDTH; i=i+1) begin
        buf_w[i] = buf_r[i];
    end
    if (iDval_d && (iY_Cnt_d[0] == 1'b0)) begin // odd line
        buf_w[iX_Cnt_d] = iData_d[11:4];
    end
end

always_comb begin
    if (iDval_d && (iY_Cnt_d[0] == 1'b1)) begin // even line
        if (iX_Cnt_d[0] == 1'b0) begin // odd pixel
            dval_w = 1'b0;
            x_cnt_w = x_cnt_r;
            y_cnt_w = y_cnt_r;
            r_data_w = iData_d[11:4];
            g_data_w = buf_r[iX_Cnt_d];
            b_data_w = buf_r[iX_Cnt_d + 1];
            // r_data_w = buf_r[iX_Cnt_d + 1];
            // g_data_w = iData_d[11:4];
            // b_data_w = 8'd0;
        end
        else begin // even pixel, output
            dval_w = 1'b1;
            x_cnt_w = {1'b0, iX_Cnt_d[15:1]};
            y_cnt_w = {1'b0, iY_Cnt_d[15:1]};
            r_data_w = r_data_r;
            g_data_w = ((g_data_r + iData_d[11:4]) >> 1);
            b_data_w = b_data_r;
            // r_data_w = r_data_r;
            // g_data_w = (g_data_r + buf_r[iX_Cnt_d - 1]) >> 1;
            // b_data_w = iData_d[11:4];
        end
    end
    else begin
        dval_w = 1'b0;
        x_cnt_w = x_cnt_r;
        y_cnt_w = y_cnt_r;
        r_data_w = r_data_r;
        g_data_w = g_data_r;
        b_data_w = b_data_r;
    end
end

always_ff @(posedge iCLK or negedge iRST) begin
    if (!iRST) begin
        // Pipeline registers
        iX_Cnt_d <= 16'd0;
        iY_Cnt_d <= 16'd0;
        iData_d <= 12'd0;
        iDval_d <= 1'b0;
        
        for (int i=0; i<COLUMN_WIDTH; i=i+1) begin
            buf_r[i] <= 8'd0;
        end
        r_data_r <= 8'd0;
        g_data_r <= 9'd0;
        b_data_r <= 8'd0;
        x_cnt_r <= 16'd0;
        y_cnt_r <= 16'd0;
        dval_r <= 1'b0;
    end
    else begin
        // Pipeline stage
        iX_Cnt_d <= iX_Cnt;
        iY_Cnt_d <= iY_Cnt;
        iData_d <= iData;
        iDval_d <= iDval;
        
        for (int i=0; i<COLUMN_WIDTH; i=i+1) begin
            buf_r[i] <= buf_w[i];
        end
        r_data_r <= r_data_w;
        g_data_r <= g_data_w;
        b_data_r <= b_data_w;
        x_cnt_r <= x_cnt_w;
        y_cnt_r <= y_cnt_w;
        dval_r <= dval_w;
    end
end

endmodule