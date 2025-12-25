module Obamify (
    input           i_clk,
    input           i_rst_n,

    // Init Controls (Given along with i_start)
    input  [2:0]    target_image_index,

    // Global Controls (i_start -> N epochs -> o_finished)
    input           i_start,
    output          o_finished,

    // Epoch Controls (i_epoch_start -> M iterations -> o_epoch_finished -> (VGA) -> Repeat)
    input           i_epoch_start,
    output          o_epoch_finished,
    output  [15:0]  o_current_epoch,

    // SRAM Controls
    output  [19:0]  o_sram_addr,
    input   [15:0]  i_sram_data,
    output  [15:0]  o_sram_data,
    output          o_sram_we       // Write enable for SRAM

);

parameter IDLE = 2'b00;
parameter OBMF = 2'b01;

localparam SOURCE_IMAGE_ADDR = 20'h28000;

logic [19:0] addr_r, addr_w;
logic [15:0] data_r, data_w;
logic we_r, we_w;
logic [9:0] counter_r, counter_w;
logic finished_r, finished_w;
logic [1:0] state_r, state_w;

assign o_sram_addr = addr_r;
assign o_sram_data = data_r;
assign o_sram_we = we_r;
assign o_current_epoch = counter_r;
assign o_finished = finished_r;

always_comb begin
    if (i_start) begin
        counter_w = 10'b0;
    end else begin
        if (i_epoch_start) begin
            if (counter_r == 10'd1023) begin
                counter_w = counter_r;
            end else begin
                counter_w = counter_r + 10'd1;
            end
        end else begin
            counter_w = counter_r;
        end
    end
end

always_comb begin
    case (state_r)
        IDLE: begin
            state_w = i_epoch_start ? OBMF : IDLE;
            addr_w = 20'b0;
            data_w = 16'b0;
            we_w = 1'b0;
        end
        OBMF: begin
            state_w = IDLE;
            addr_w = SOURCE_IMAGE_ADDR + ({10'b0, counter_r} << 1);
            data_w = 16'h1010;
            we_w = 1'b1;
        end
        default: begin
            state_w = IDLE;
            addr_w = 20'b0;
            data_w = 16'b0;
            we_w = 1'b0;
        end
    endcase 
end


always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        addr_r <= 20'b0;
        data_r <= 16'b0;
        we_r <= 1'b0;
        counter_r <= 10'b0;
        finished_r <= 1'b0;
        state_r <= IDLE;
    end
    else begin
        addr_r <= addr_w;
        data_r <= data_w;
        we_r <= we_w;
        counter_r <= counter_w;
        finished_r <= finished_w;
        state_r <= state_w;
    end
end



endmodule