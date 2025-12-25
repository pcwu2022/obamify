module Random_number_21_bit (
    input           i_clk,
    input           i_rst_n,
    output  [20:0]   o_random_number
);

    // 32-bit state register for xorshift32 PRNG
    logic [31:0] state;
    logic [31:0] next_state;
    logic [31:0] temp1, temp2;

    // xorshift32 algorithm
    // x ^= (x << 13)
    // x ^= (x >> 17)
    // x ^= (x << 5)
    assign temp1 = state ^ (state << 13);
    assign temp2 = temp1 ^ (temp1 >> 17);
    assign next_state = temp2 ^ (temp2 << 5);

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