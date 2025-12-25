module Reset_Delay (
    input  logic        iCLK,
    input  logic        iRST,
    output logic        oRST_0,
    output logic        oRST_1,
    output logic        oRST_2,
    output logic        oRST_3,
    output logic        oRST_4
);

logic [31:0] Cont;

always_ff @(posedge iCLK or negedge iRST) begin
    if (!iRST) begin
        Cont   <= '0;
        oRST_0 <= 1'b0;
        oRST_1 <= 1'b0;
        oRST_2 <= 1'b0;
        oRST_3 <= 1'b0;
        oRST_4 <= 1'b0;
    end
    else begin
        if (Cont != 32'h02FFFFFF)
            Cont <= Cont + 1'b1;
        if (Cont >= 32'h001FFFFF)
            oRST_0 <= 1'b1;
        if (Cont >= 32'h002FFFFF)
            oRST_1 <= 1'b1;
        if (Cont >= 32'h011FFFFF)
            oRST_2 <= 1'b1;
        if (Cont >= 32'h026FFFFF)
            oRST_3 <= 1'b1;
        if (Cont >= 32'h02FFFFFF)
            oRST_4 <= 1'b1;
    end
end

endmodule