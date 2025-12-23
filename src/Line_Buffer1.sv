module Line_Buffer1 (
    input  logic        clken,
    input  logic        clock,
    input  logic [11:0] shiftin,
    output logic [11:0] shiftout,
    output logic [11:0] taps0x,
    output logic [11:0] taps1x
);

    logic [11:0] sub_wire0;
    logic [23:0] sub_wire1;

    assign shiftout = sub_wire0[11:0];
    assign taps0x   = sub_wire1[11:0];
    assign taps1x   = sub_wire1[23:12];

    altshift_taps ALTSHIFT_TAPS_component (
        .clken    (clken),
        .clock    (clock),
        .shiftin  (shiftin),
        .shiftout (sub_wire0),
        .taps     (sub_wire1)
        // synopsys translate_off
        ,
        .aclr (),
        .sclr ()
        // synopsys translate_on
    );

    defparam
        ALTSHIFT_TAPS_component.intended_device_family = "Cyclone IV E",
        ALTSHIFT_TAPS_component.lpm_hint = "RAM_BLOCK_TYPE=M9K",
        ALTSHIFT_TAPS_component.lpm_type = "altshift_taps",
        ALTSHIFT_TAPS_component.number_of_taps = 2,
        ALTSHIFT_TAPS_component.tap_distance = 1280,
        ALTSHIFT_TAPS_component.width = 12;

endmodule