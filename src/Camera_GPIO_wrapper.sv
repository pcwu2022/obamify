module Camera_GPIO_wrapper (
    inout  logic [35:0] GPIO,
    output logic        pixclk,
    output logic [11:0] data,
    output logic        lval,
    output logic        fval,
    output logic        strobe,
    input  logic        xclkin, // master clock input
    input  logic        reset_n,
    input  logic        trigger,
    input  logic        sclk, // I2C clock
    inout  logic        sdata
);

    // GPIO to FPGA inputs
    assign pixclk   = GPIO[0];
    assign data     = {GPIO[1], GPIO[3], GPIO[4], GPIO[5], GPIO[6], GPIO[7], GPIO[8], GPIO[9], GPIO[10], GPIO[11], GPIO[12], GPIO[13]};
    assign lval     = GPIO[21];
    assign fval     = GPIO[22];
    assign strobe   = GPIO[20];

    // FPGA to GPIO outputs
    assign GPIO[16] = xclkin;
    assign GPIO[17] = reset_n;
    assign GPIO[19] = trigger;
    assign GPIO[24] = sclk;

    // Bidirectional I2C data line
    assign sdata    = GPIO[23];

endmodule