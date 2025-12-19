module SDRAM_control_interface(
    input  logic             CLK,        // System Clock
    input  logic             RESET_N,    // System Reset
    input  logic [2:0]       CMD,        // Command input
    input  logic [`ASIZE-1:0] ADDR,      // Address
    input  logic             REF_ACK,    // Refresh request acknowledge
    input  logic             INIT_ACK,   // Initial request acknowledge
    input  logic             CM_ACK,     // Command acknowledge
    output logic             NOP,        // Decoded NOP command
    output logic             READA,      // Decoded READA command
    output logic             WRITEA,     // Decoded WRITEA command
    output logic             REFRESH,    // Decoded REFRESH command
    output logic             PRECHARGE,  // Decoded PRECHARGE command
    output logic             LOAD_MODE,  // Decoded LOAD_MODE command
    output logic [`ASIZE-1:0] SADDR,     // Registered version of ADDR
    output logic             REF_REQ,    // Hidden refresh request
    output logic             INIT_REQ,   // Hidden initial request
    output logic             CMD_ACK     // Command acknowledge
);

`include "SDRAM_Params.vh"

logic [15:0] timer;
logic [15:0] init_timer;

// Command decode and ADDR register
always_ff @(posedge CLK or negedge RESET_N)
begin
        if (RESET_N == 0) 
        begin
                NOP             <= 0;
                READA           <= 0;
                WRITEA          <= 0;
                SADDR           <= 0;
        end
        
        else
        begin
        
                SADDR <= ADDR;                                  // register the address to keep proper
                                                                // alignment with the command
                                                             
                if (CMD == 3'b000)                              // NOP command
                        NOP <= 1;
                else
                        NOP <= 0;
                        
                if (CMD == 3'b001)                              // READA command
                        READA <= 1;
                else
                        READA <= 0;
                 
                if (CMD == 3'b010)                              // WRITEA command
                        WRITEA <= 1;
                else
                        WRITEA <= 0;
                        
        end
end


//  Generate CMD_ACK
always_ff @(posedge CLK or negedge RESET_N)
begin
        if (RESET_N == 0)
                CMD_ACK <= 0;
        else
                if ((CM_ACK == 1) & (CMD_ACK == 0))
                        CMD_ACK <= 1;
                else
                        CMD_ACK <= 0;
end


// refresh timer
always_ff @(posedge CLK or negedge RESET_N) begin
        if (RESET_N == 0) 
        begin
                timer           <= 0;
                REF_REQ         <= 0;
        end        
        else 
        begin
                if (REF_ACK == 1)
				begin
                	timer <= REF_PER;
					REF_REQ	<=0;
				end
				else if (INIT_REQ == 1)
				begin
                	timer <= REF_PER+200;
					REF_REQ	<=0;					
				end
                else
                	timer <= timer - 1'b1;

                if (timer==0)
                    REF_REQ    <= 1;

        end
end

// initial timer
always_ff @(posedge CLK or negedge RESET_N) begin
        if (RESET_N == 0) 
        begin
                init_timer      <= 0;
				REFRESH         <= 0;
                PRECHARGE      	<= 0; 
				LOAD_MODE		<= 0;
				INIT_REQ		<= 0;
        end        
        else 
        begin
                if (init_timer < (INIT_PER+201))
					init_timer 	<= init_timer+1;
					
				if (init_timer < INIT_PER)
				begin
					REFRESH		<=0;
					PRECHARGE	<=0;
					LOAD_MODE	<=0;
					INIT_REQ	<=1;
				end
				else if(init_timer == (INIT_PER+20))
				begin
					REFRESH		<=0;
					PRECHARGE	<=1;
					LOAD_MODE	<=0;
					INIT_REQ	<=0;
				end
				else if( 	(init_timer == (INIT_PER+40))	||
							(init_timer == (INIT_PER+60))	||
							(init_timer == (INIT_PER+80))	||
							(init_timer == (INIT_PER+100))	||
							(init_timer == (INIT_PER+120))	||
							(init_timer == (INIT_PER+140))	||
							(init_timer == (INIT_PER+160))	||
							(init_timer == (INIT_PER+180))	)
				begin
					REFRESH		<=1;
					PRECHARGE	<=0;
					LOAD_MODE	<=0;
					INIT_REQ	<=0;
				end
				else if(init_timer == (INIT_PER+200))
				begin
					REFRESH		<=0;
					PRECHARGE	<=0;
					LOAD_MODE	<=1;
					INIT_REQ	<=0;				
				end
				else
				begin
					REFRESH		<=0;
					PRECHARGE	<=0;
					LOAD_MODE	<=0;
					INIT_REQ	<=0;									
				end
        end
end

endmodule