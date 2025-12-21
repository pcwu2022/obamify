// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module SDRAM_WR_FIFO (
	input logic	         aclr,
	input logic	 [31:0]  data,
	input logic	         rdclk,
	input logic	         rdreq,
	input logic	         wrclk,
	input logic	         wrreq,
	output logic [31:0]  q,
	output logic [7:0]   rdusedw
);

// `ifndef ALTERA_RESERVED_QIS
// // synopsys translate_off
// `endif
// 	tri0	  aclr;
// `ifndef ALTERA_RESERVED_QIS
// // synopsys translate_on
// `endif

	logic [31:0] sub_wire0;
	logic [7:0] sub_wire1;

	assign q = sub_wire0[31:0];
	assign rdusedw = sub_wire1[7:0];

	dcfifo_mixed_widths	dcfifo_mixed_widths_component (
				.wrclk (wrclk),
				.rdreq (rdreq),
				.aclr (aclr),
				.rdclk (rdclk),
				.wrreq (wrreq),
				.data (data),
				.q (sub_wire0),
				.rdusedw (sub_wire1)
				// synopsys translate_off
				,
				.rdempty (),
				.rdfull (),
				.wrempty (),
				.wrfull (),
				.wrusedw ()
				// synopsys translate_on
				);
	defparam
		dcfifo_mixed_widths_component.intended_device_family = "Cyclone IV E",
		dcfifo_mixed_widths_component.lpm_numwords = 512,
		dcfifo_mixed_widths_component.lpm_showahead = "OFF",
		dcfifo_mixed_widths_component.lpm_type = "dcfifo",
		dcfifo_mixed_widths_component.lpm_width = 32,
		dcfifo_mixed_widths_component.lpm_widthu = 9,
		dcfifo_mixed_widths_component.lpm_widthu_r = 8,
		dcfifo_mixed_widths_component.lpm_width_r = 32,
		dcfifo_mixed_widths_component.overflow_checking = "ON",
		dcfifo_mixed_widths_component.rdsync_delaypipe = 4,
		dcfifo_mixed_widths_component.underflow_checking = "ON",
		dcfifo_mixed_widths_component.use_eab = "ON",
		dcfifo_mixed_widths_component.write_aclr_synch = "OFF",
		dcfifo_mixed_widths_component.wrsync_delaypipe = 4;


endmodule