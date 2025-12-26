`include "SDRAM_Params.vh"

module SDRAM_datapath (
        input  logic                CLK,     // System Clock
        input  logic                RESET_N, // System Reset
        input  logic [`DSIZE-1:0]   DATAIN,  // Data input from the host
        input  logic [`DSIZE/8-1:0] DM,      // Byte data masks
        output logic [`DSIZE-1:0]   DQOUT,
        output logic [`DSIZE/8-1:0] DQM      // SDRAM data mask outputs
);

// Align the input and output data to the SDRAM control path
always_ff @(posedge CLK or negedge RESET_N)
begin
        if (RESET_N == 0) 
                                DQM <= 4'hF;
        else
                                DQM <= DM;                 
end

assign DQOUT = DATAIN;

endmodule