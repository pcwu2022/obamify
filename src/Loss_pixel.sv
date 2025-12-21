module Loss_pixel (
    input   [23:0]  i_pixel_a,
    input   [23:0]  i_pixel_b,
    output  [7:0]   o_loss
);

    wire [7:0] r_diff;
    wire [7:0] g_diff;
    wire [7:0] b_diff;
    wire [15:0] loss_temp;

    assign r_diff = (i_pixel_a[23:16] > i_pixel_b[23:16]) ? (i_pixel_a[23:16] - i_pixel_b[23:16]) : (i_pixel_b[23:16] - i_pixel_a[23:16]);
    assign g_diff = (i_pixel_a[15:8]  > i_pixel_b[15:8])  ? (i_pixel_a[15:8]  - i_pixel_b[15:8])  : (i_pixel_b[15:8]  - i_pixel_a[15:8]);
    assign b_diff = (i_pixel_a[7:0]   > i_pixel_b[7:0])   ? (i_pixel_a[7:0]   - i_pixel_b[7:0])   : (i_pixel_b[7:0]   - i_pixel_a[7:0]);

    assign loss_temp = (r_diff * r_diff + g_diff * g_diff + b_diff * b_diff) >> 8;
    assign o_loss = (loss_temp > 8'hFF) ? 8'hFF : loss_temp[7:0];

endmodule