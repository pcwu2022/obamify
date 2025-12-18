module I2C_Controller (
	input  logic         CLOCK,
	output wire          I2C_SCLK, // I2C CLOCK (driven by assign)
	inout  wire          I2C_SDAT, // I2C DATA (tri-state driven by assign)
	input  logic [31:0]  I2C_DATA, // DATA: [SLAVE_ADDR, SUB_ADDR, DATA]
	input  logic         GO,       // GO transfer
	output logic         o_END,    // END transfer
	input  logic         W_R,      // W_R
	output wire          ACK,      // ACK (driven by assign)
	input  logic         RESET
);

	logic        SDO;
	logic        SCLK;
	logic [31:0] SD;
	logic [6:0]  SD_COUNTER;

	assign I2C_SCLK = SCLK | ( ((SD_COUNTER >= 7'd4) & (SD_COUNTER <= 7'd39)) ? ~CLOCK : 1'b0 );
	assign I2C_SDAT = SDO ? 1'bz : 1'b0;

	logic ACK1, ACK2, ACK3, ACK4;
	assign ACK = ACK1 | ACK2 | ACK3 | ACK4;

	// I2C COUNTER
	always_ff @(posedge CLOCK or negedge RESET) begin
		if (!RESET) SD_COUNTER <= 7'd63; // reset to max sentinel
		else begin
			if (GO == 1'b0)
				SD_COUNTER <= 7'd0;
			else if (SD_COUNTER < 7'd41)
				SD_COUNTER <= SD_COUNTER + 7'd1;
		end
	end
	always_ff @(posedge CLOCK or negedge RESET) begin
		if (!RESET) begin
			SCLK  <= 1'b1;
			SDO   <= 1'b1;
			ACK1  <= 1'b0;
			ACK2  <= 1'b0;
			ACK3  <= 1'b0;
			ACK4  <= 1'b0;
			o_END   <= 1'b1;
		end else begin
			case (SD_COUNTER)
				6'd0  : begin
                    ACK1 <= 1'b0;
                    ACK2 <= 1'b0;
                    ACK3 <= 1'b0;
                    ACK4 <= 1'b0;
                    o_END <= 1'b0;
                    SDO <= 1'b1;
                    SCLK <= 1'b1;
                end
				// start
				6'd1  : begin
                    SD <= I2C_DATA;
                    SDO <= 1'b0;
                end
				6'd2  : SCLK <= 1'b0;
				// SLAVE ADDR
				6'd3  : SDO <= SD[31];
				6'd4  : SDO <= SD[30];
				6'd5  : SDO <= SD[29];
				6'd6  : SDO <= SD[28];
				6'd7  : SDO <= SD[27];
				6'd8  : SDO <= SD[26];
				6'd9  : SDO <= SD[25];
				6'd10 : SDO <= SD[24];
				6'd11 : SDO <= 1'b1; // ACK

				// SUB ADDR
				6'd12 : begin
                    SDO <= SD[23];
                    ACK1 <= I2C_SDAT;
                end
				6'd13 : SDO <= SD[22];
				6'd14 : SDO <= SD[21];
				6'd15 : SDO <= SD[20];
				6'd16 : SDO <= SD[19];
				6'd17 : SDO <= SD[18];
				6'd18 : SDO <= SD[17];
				6'd19 : SDO <= SD[16];
				6'd20 : SDO <= 1'b1; // ACK

				// DATA
				6'd21 : begin
                    SDO <= SD[15];
                    ACK2 <= I2C_SDAT;
                end
				6'd22 : SDO <= SD[14];
				6'd23 : SDO <= SD[13];
				6'd24 : SDO <= SD[12];
				6'd25 : SDO <= SD[11];
				6'd26 : SDO <= SD[10];
				6'd27 : SDO <= SD[9];
				6'd28 : SDO <= SD[8];
				6'd29 : SDO <= 1'b1; // ACK

				// DATA
				6'd30 : begin
                    SDO <= SD[7];
                    ACK3 <= I2C_SDAT;
                end
				6'd31 : SDO <= SD[6];
				6'd32 : SDO <= SD[5];
				6'd33 : SDO <= SD[4];
				6'd34 : SDO <= SD[3];
				6'd35 : SDO <= SD[2];
				6'd36 : SDO <= SD[1];
				6'd37 : SDO <= SD[0];
				6'd38 : SDO <= 1'b1; // ACK

				// stop
				6'd39 : begin
                    SDO <= 1'b0;
                    SCLK <= 1'b0;
                    ACK4 <= I2C_SDAT;
                end
				6'd40 : SCLK <= 1'b1;
				6'd41 : begin
                    SDO <= 1'b1;
                    o_END <= 1'b1;
                end
				default: ;
			endcase
		end
	end

endmodule