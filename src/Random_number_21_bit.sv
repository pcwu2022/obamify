module o_random_number_21_bit (
    input           i_clk,
    input           i_rst_n,
    output  [20:0]   o_random_number
);

    // 32-bit state register for xorshift32 PRNG
    reg [31:0] state;
    wire [31:0] next_state;

    // xorshift32 algorithm
    // x ^= (x << 13)
    // x ^= (x >> 17)
    // x ^= (x << 5)
    assign next_state = ((state ^ (state << 13)) ^ ((state ^ (state << 13)) >> 17)) ^ (((state ^ (state << 13)) ^ ((state ^ (state << 13)) >> 17)) << 5);

    // Output the lower 21 bits of the state
    assign o_random_number = state[20:0];

    // Update state on clock edge
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            // Initialize with default seed (1, since 0 is not allowed in xorshift32)
            state <= 32'd1;
        end
        else begin
            state <= next_state;
        end
    end

endmodule