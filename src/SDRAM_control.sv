`include "SDRAM_Params.vh"

module SDRAM_control (
    // HOST Side
    input  logic                    RESET_N,      // System Reset
    input  logic                    CLK,
    // FIFO Write Side 1
    input  logic [`WRSIZE-1:0]      WR1_DATA,     // Data Input
    input  logic                    WR1,          // Write Request
    input  logic [`ASIZE-1:0]       WR1_ADDR,     // Write Start Address
    input  logic [`ASIZE-1:0]       WR1_MAX_ADDR, // Write Max Address
    input  logic [7:0]              WR1_LENGTH,   // Write Length
    input  logic                    WR1_LOAD,     // Write FIFO Clear
    input  logic                    WR1_CLK,      // Write FIFO Clock
    // FIFO Write Side 2
    input  logic [`WRSIZE-1:0]      WR2_DATA,     // Data Input
    input  logic                    WR2,          // Write Request
    input  logic [`ASIZE-1:0]       WR2_ADDR,     // Write Start Address
    input  logic [`ASIZE-1:0]       WR2_MAX_ADDR, // Write Max Address
    input  logic [7:0]              WR2_LENGTH,   // Write Length
    input  logic                    WR2_LOAD,     // Write FIFO Clear
    input  logic                    WR2_CLK,      // Write FIFO Clock
    // FIFO Read Side 1
    output logic [`RDSIZE-1:0]      RD1_DATA,     // Data Output
    input  logic                    RD1,          // Read Request
    input  logic [`ASIZE-1:0]       RD1_ADDR,     // Read Start Address
    input  logic [`ASIZE-1:0]       RD1_MAX_ADDR, // Read Max Address
    input  logic [7:0]              RD1_LENGTH,   // Read Length
    input  logic                    RD1_LOAD,     // Read FIFO Clear
    input  logic                    RD1_CLK,      // Read FIFO Clock
    // FIFO Read Side 2
    output logic [`RDSIZE-1:0]      RD2_DATA,     // Data Output
    input  logic                    RD2,          // Read Request
    input  logic [`ASIZE-1:0]       RD2_ADDR,     // Read Start Address
    input  logic [`ASIZE-1:0]       RD2_MAX_ADDR, // Read Max Address
    input  logic [7:0]              RD2_LENGTH,   // Read Length
    input  logic                    RD2_LOAD,     // Read FIFO Clear
    input  logic                    RD2_CLK,      // Read FIFO Clock
    // SDRAM Side
    output logic [11:0]             SA,           // SDRAM address output
    output logic [1:0]              BA,           // SDRAM bank address
    output logic [1:0]              CS_N,         // SDRAM Chip Selects
    output logic                    CKE,          // SDRAM clock enable
    output logic                    RAS_N,        // SDRAM Row address Strobe
    output logic                    CAS_N,        // SDRAM Column address Strobe
    output logic                    WE_N,         // SDRAM write enable
    inout  wire  [`DSIZE-1:0]       DQ,           // SDRAM data bus
    output logic [`DSIZE/8-1:0]     DQM           // SDRAM data mask lines
);

// Controller state and address management
logic [`ASIZE-1:0] mADDR;
logic [7:0]        mLENGTH;
logic [`ASIZE-1:0] rWR1_ADDR, rWR1_MAX_ADDR;
logic [7:0]        rWR1_LENGTH;
logic [`ASIZE-1:0] rWR2_ADDR, rWR2_MAX_ADDR;
logic [7:0]        rWR2_LENGTH;
logic [`ASIZE-1:0] rRD1_ADDR, rRD1_MAX_ADDR;
logic [7:0]        rRD1_LENGTH;
logic [`ASIZE-1:0] rRD2_ADDR, rRD2_MAX_ADDR;
logic [7:0]        rRD2_LENGTH;
logic [1:0]        WR_MASK, RD_MASK;
logic              mWR_DONE, mRD_DONE;
logic              mWR, Pre_WR;
logic              mRD, Pre_RD;
logic [9:0]        ST;
logic [1:0]        CMD;
logic              PM_STOP, PM_DONE;
logic              Read, Write;
logic [`DSIZE-1:0] mDATAOUT;
logic [`DSIZE-1:0] mDATAIN, mDATAIN1, mDATAIN2;
logic              CMDACK;

// DRAM control links
logic [`DSIZE-1:0]  DQOUT;
logic [`DSIZE/8-1:0] IDQM;
logic [11:0]        ISA;
logic [1:0]         IBA;
logic [1:0]         ICS_N;
logic               ICKE;
logic               IRAS_N;
logic               ICAS_N;
logic               IWE_N;

// FIFO control
logic OUT_VALID, IN_REQ;
logic [7:0] write_side_fifo_rusedw1;
logic [7:0] write_side_fifo_rusedw2;
logic [7:0] read_side_fifo_wusedw1;
logic [7:0] read_side_fifo_wusedw2;

// DRAM internal control
logic [`ASIZE-1:0] saddr;
logic              load_mode;
logic              nop;
logic              reada;
logic              writea;
logic              refresh;
logic              precharge;
logic              oe;
logic              ref_ack;
logic              ref_req;
logic              init_req;
logic              cm_ack;
logic              active;

//=======================================================
//  Sub-modules
//=======================================================
SDRAM_control_interface u_control_interface (
    .CLK(CLK),
    .RESET_N(RESET_N),
    .CMD(CMD),
    .ADDR(mADDR),
    .REF_ACK(ref_ack),
    .INIT_ACK(1'b0),
    .CM_ACK(cm_ack),
    .NOP(nop),
    .READA(reada),
    .WRITEA(writea),
    .REFRESH(refresh),
    .PRECHARGE(precharge),
    .LOAD_MODE(load_mode),
    .SADDR(saddr),
    .REF_REQ(ref_req),
    .INIT_REQ(init_req),
    .CMD_ACK(CMDACK)
);

SDRAM_command u_command (
    .CLK(CLK),
    .RESET_N(RESET_N),
    .SADDR(saddr),
    .NOP(nop),
    .READA(reada),
    .WRITEA(writea),
    .REFRESH(refresh),
    .LOAD_MODE(load_mode),
    .PRECHARGE(precharge),
    .REF_REQ(ref_req),
    .INIT_REQ(init_req),
    .PM_STOP(PM_STOP),
    .PM_DONE(PM_DONE),
    .REF_ACK(ref_ack),
    .CM_ACK(cm_ack),
    .OE(oe),
    .SA(ISA),
    .BA(IBA),
    .CS_N(ICS_N),
    .CKE(ICKE),
    .RAS_N(IRAS_N),
    .CAS_N(ICAS_N),
    .WE_N(IWE_N)
);

SDRAM_datapath u_sdr_data_path (
    .CLK(CLK),
    .RESET_N(RESET_N),
    .DATAIN(mDATAIN),
    .DM(2'b00),
    .DQOUT(DQOUT),
    .DQM(IDQM)
);

SDRAM_WR_FIFO u_write1_fifo (
    .data(WR1_DATA),
    .wrreq(WR1),
    .wrclk(WR1_CLK),
    .aclr(WR1_LOAD),
    .rdreq(IN_REQ && WR_MASK[0]),
    .rdclk(CLK),
    .q(mDATAIN1),
    .rdusedw(write_side_fifo_rusedw1)
);

SDRAM_WR_FIFO u_write2_fifo (
    .data(WR2_DATA),
    .wrreq(WR2),
    .wrclk(WR2_CLK),
    .aclr(WR2_LOAD),
    .rdreq(IN_REQ && WR_MASK[1]),
    .rdclk(CLK),
    .q(mDATAIN2),
    .rdusedw(write_side_fifo_rusedw2)
);

SDRAM_RD_FIFO u_read1_fifo (
    .data(mDATAOUT),
    .wrreq(OUT_VALID && RD_MASK[0]),
    .wrclk(CLK),
    .aclr(RD1_LOAD),
    .rdreq(RD1),
    .rdclk(RD1_CLK),
    .q(RD1_DATA),
    .wrusedw(read_side_fifo_wusedw1)
);

SDRAM_RD_FIFO u_read2_fifo (
    .data(mDATAOUT),
    .wrreq(OUT_VALID && RD_MASK[1]),
    .wrclk(CLK),
    .aclr(RD2_LOAD),
    .rdreq(RD2),
    .rdclk(RD2_CLK),
    .q(RD2_DATA),
    .wrusedw(read_side_fifo_wusedw2)
);

//=======================================================
//  Structural coding
//=======================================================
assign mDATAIN = (WR_MASK[0]) ? mDATAIN1 : mDATAIN2;
assign DQ      = oe ? DQOUT : `DSIZE'hzzzz;
assign active  = Read | Write;

always_ff @(posedge CLK) begin
    SA       <= (ST == SC_CL + mLENGTH) ? 12'h200 : ISA;
    BA       <= IBA;
    CS_N     <= ICS_N;
    CKE      <= ICKE;
    RAS_N    <= (ST == SC_CL + mLENGTH) ? 1'b0 : IRAS_N;
    CAS_N    <= (ST == SC_CL + mLENGTH) ? 1'b1 : ICAS_N;
    WE_N     <= (ST == SC_CL + mLENGTH) ? 1'b0 : IWE_N;
    PM_STOP  <= (ST == SC_CL + mLENGTH) ? 1'b1 : 1'b0;
    PM_DONE  <= (ST == SC_CL + SC_RCD + mLENGTH + 2) ? 1'b1 : 1'b0;
    DQM      <= (active && (ST >= SC_CL)) ? (((ST == SC_CL + mLENGTH) && Write) ? 4'b1111 : 4'b0) : 4'b1111;
    mDATAOUT <= DQ;
end

always_ff @(posedge CLK or negedge RESET_N) begin
    if (!RESET_N) begin
        CMD       <= 0;
        ST        <= 0;
        Pre_RD    <= 0;
        Pre_WR    <= 0;
        Read      <= 0;
        Write     <= 0;
        OUT_VALID <= 0;
        IN_REQ    <= 0;
        mWR_DONE  <= 0;
        mRD_DONE  <= 0;
    end else begin
        Pre_RD <= mRD;
        Pre_WR <= mWR;
        case (ST)
            0: begin
                if (!Pre_RD && mRD) begin
                    Read  <= 1;
                    Write <= 0;
                    CMD   <= 2'b01;
                    ST    <= 1;
                end else if (!Pre_WR && mWR) begin
                    Read  <= 0;
                    Write <= 1;
                    CMD   <= 2'b10;
                    ST    <= 1;
                end
            end
            1: begin
                if (CMDACK) begin
                    CMD <= 2'b00;
                    ST  <= 2;
                end
            end
            default: begin
                if (ST != SC_CL + SC_RCD + mLENGTH + 1)
                    ST <= ST + 1;
                else
                    ST <= 0;
            end
        endcase

        if (Read) begin
            if (ST == SC_CL + SC_RCD + 1)
                OUT_VALID <= 1;
            else if (ST == SC_CL + SC_RCD + mLENGTH + 1) begin
                OUT_VALID <= 0;
                Read      <= 0;
                mRD_DONE  <= 1;
            end
        end else begin
            mRD_DONE <= 0;
        end

        if (Write) begin
            if (ST == SC_CL - 1)
                IN_REQ <= 1;
            else if (ST == SC_CL + mLENGTH - 1)
                IN_REQ <= 0;
            else if (ST == SC_CL + SC_RCD + mLENGTH) begin
                Write    <= 0;
                mWR_DONE <= 1;
            end
        end else begin
            mWR_DONE <= 0;
        end
    end
end

// Internal Address & Length Control
always_ff @(posedge CLK or negedge RESET_N) begin
    if (!RESET_N) begin
        rWR1_ADDR     <= WR1_ADDR;
        rWR2_ADDR     <= WR2_ADDR;
        rRD1_ADDR     <= RD1_ADDR;
        rRD2_ADDR     <= RD2_ADDR;
        rWR1_MAX_ADDR <= WR1_MAX_ADDR;
        rWR2_MAX_ADDR <= WR2_MAX_ADDR;
        rRD1_MAX_ADDR <= RD1_MAX_ADDR;
        rRD2_MAX_ADDR <= RD2_MAX_ADDR;

        rWR1_LENGTH <= WR1_LENGTH;
        rWR2_LENGTH <= WR2_LENGTH;
        rRD1_LENGTH <= RD1_LENGTH;
        rRD2_LENGTH <= RD2_LENGTH;
    end else begin
        // Write Side 1
        if (mWR_DONE && WR_MASK[0]) begin
            if (rWR1_ADDR < rWR1_MAX_ADDR - rWR1_LENGTH)
                rWR1_ADDR <= rWR1_ADDR + rWR1_LENGTH;
            else
                rWR1_ADDR <= WR1_ADDR;
        end
        // Write Side 2
        if (mWR_DONE && WR_MASK[1]) begin
            if (rWR2_ADDR < rWR2_MAX_ADDR - rWR2_LENGTH)
                rWR2_ADDR <= rWR2_ADDR + rWR2_LENGTH;
            else
                rWR2_ADDR <= WR2_ADDR;
        end
        // Read Side 1
        if (mRD_DONE && RD_MASK[0]) begin
            if (rRD1_ADDR < rRD1_MAX_ADDR - rRD1_LENGTH)
                rRD1_ADDR <= rRD1_ADDR + rRD1_LENGTH;
            else
                rRD1_ADDR <= RD1_ADDR;
        end
        // Read Side 2
        if (mRD_DONE && RD_MASK[1]) begin
            if (rRD2_ADDR < rRD2_MAX_ADDR - rRD2_LENGTH)
                rRD2_ADDR <= rRD2_ADDR + rRD2_LENGTH;
            else
                rRD2_ADDR <= RD2_ADDR;
        end
    end
end

// Auto Read/Write Control
always_ff @(posedge CLK or negedge RESET_N) begin
    if (!RESET_N) begin
        mWR     <= 0;
        mRD     <= 0;
        mADDR   <= 0;
        mLENGTH <= 0;
        RD_MASK <= 0;
        WR_MASK <= 0;
    end else begin
        if ((mWR == 0) && (mRD == 0) && (ST == 0) &&
            (WR_MASK == 0) && (RD_MASK == 0) &&
            (WR1_LOAD == 0) && (RD1_LOAD == 0) &&
            (WR2_LOAD == 0) && (RD2_LOAD == 0)) begin
            // Write Side 1
            if ((write_side_fifo_rusedw1 >= rWR1_LENGTH) && (rWR1_LENGTH != 0)) begin
                mADDR   <= rWR1_ADDR;
                mLENGTH <= rWR1_LENGTH;
                WR_MASK <= 2'b01;
                RD_MASK <= 2'b00;
                mWR     <= 1;
                mRD     <= 0;
            end
            // Write Side 2
            else if ((write_side_fifo_rusedw2 >= rWR2_LENGTH) && (rWR2_LENGTH != 0)) begin
                mADDR   <= rWR2_ADDR;
                mLENGTH <= rWR2_LENGTH;
                WR_MASK <= 2'b10;
                RD_MASK <= 2'b00;
                mWR     <= 1;
                mRD     <= 0;
            end
            // Read Side 1
            else if (read_side_fifo_wusedw1 < rRD1_LENGTH) begin
                mADDR   <= rRD1_ADDR;
                mLENGTH <= rRD1_LENGTH;
                WR_MASK <= 2'b00;
                RD_MASK <= 2'b01;
                mWR     <= 0;
                mRD     <= 1;
            end
            // Read Side 2
            else if (read_side_fifo_wusedw2 < rRD2_LENGTH) begin
                mADDR   <= rRD2_ADDR;
                mLENGTH <= rRD2_LENGTH;
                WR_MASK <= 2'b00;
                RD_MASK <= 2'b10;
                mWR     <= 0;
                mRD     <= 1;
            end
        end

        if (mWR_DONE) begin
            WR_MASK <= 0;
            mWR     <= 0;
        end

        if (mRD_DONE) begin
            RD_MASK <= 0;
            mRD     <= 0;
        end
    end
end

endmodule
