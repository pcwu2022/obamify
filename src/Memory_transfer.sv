module Memory_transfer(
    input               i_clk,
    input               i_rst_n,
    // Flash interface
    input               i_FL_data_valid,
    input        [7:0]  i_FL_data,
    output logic        o_FL_read,
    output logic [22:0] o_FL_addr,
    // SRAM interface
    input        [15:0] i_SRAM_data,
    output logic [19:0] o_SRAM_addr,
    output logic        o_SRAM_enable,
    output logic        o_SRAM_write,
    output logic [15:0] o_SRAM_data,
    // SDRAM interface
    input        [31:0] i_SDRAM_data,
    output logic        o_SDRAM_read,
    output logic        o_SDRAM_write,
    output logic [31:0] o_SDRAM_data,
    // Control signals
    input               i_start,
    input               i_SRAM_to_SDRAM_valid,
    input               i_SDRAM_to_SRAM_valid,
    output logic        o_done
);

logic [19:0] SRAM_addr_r, SRAM_addr_w;
logic SRAM_enable_r, SRAM_enable_w;
logic SRAM_write_r, SRAM_write_w;
logic [15:0] SRAM_data_r, SRAM_data_w;

logic SDRAM_read_r, SDRAM_read_w;
logic SDRAM_write_r, SDRAM_write_w;
logic [31:0] SDRAM_data_r, SDRAM_data_w;

logic done_r, done_w;

logic [2:0] state_r, state_w;
logic [6:0] x_cnt_r, x_cnt_w;
logic [6:0] y_cnt_r, y_cnt_w;
logic counter_r, counter_w;
logic [31:0] buffer_r, buffer_w;

localparam S_IDLE           = 3'd0;
localparam S_PREP           = 3'd1;
localparam S_SDRAM_to_SRAM  = 3'd2;
localparam S_SRAM_to_SDRAM  = 3'd3;
localparam S_DONE           = 3'd4;

localparam SRAM_BASE_ADDR   = 20'h5000;

// FSM
always_comb begin
    case (state_r)
        S_IDLE: begin
            if (i_SRAM_to_SDRAM_valid) begin
                state_w = S_SRAM_to_SDRAM;
            end
            else if (i_SDRAM_to_SRAM_valid) begin
                state_w = S_PREP;
            end
            else begin
                state_w = S_IDLE;
            end
        end
        S_PREP: begin
            state_w = S_SDRAM_to_SRAM;
        end
        S_SDRAM_to_SRAM, S_SRAM_to_SDRAM: begin
            if ((x_cnt_r == 7'd127) && (y_cnt_r == 7'd127) && counter_r) begin
                state_w = S_DONE;
            end
            else begin
                state_w = state_r;
            end
        end
        S_DONE: begin
            state_w = S_IDLE;
        end
        default: begin
            state_w = S_IDLE;
        end
    endcase
end

// SRAM side
always_comb begin
    case (state_r)
        S_SDRAM_to_SRAM: begin
            if (counter_r == 1'b0) begin
                SRAM_data_w = i_SDRAM_data[23:8];
            end
            else begin
                SRAM_data_w = {buffer_r[7:0], 8'd0};
            end
            SRAM_addr_w = SRAM_BASE_ADDR + {y_cnt_r, x_cnt_r, counter_r};
            SRAM_write_w = 1'b1;
            SRAM_enable_w = 1'b1;
        end
        S_SRAM_to_SDRAM: begin
            SRAM_data_w = 16'd0;
            SRAM_addr_w = SRAM_BASE_ADDR + {y_cnt_r, x_cnt_r, counter_r};
            SRAM_write_w = 1'b0;
            SRAM_enable_w = 1'b1;
        end
        default: begin
            SRAM_data_w = 16'd0;
            SRAM_addr_w = 20'd0;
            SRAM_write_w = 1'b0;
            SRAM_enable_w = 1'b0;
        end
    endcase
end

// SDRAM side
always_comb begin
    case (state_r)
        S_PREP: begin
            SDRAM_read_w = 1'b1;
            SDRAM_write_w = 1'b0;
            SDRAM_data_w = 32'd0;
        end
        S_SDRAM_to_SRAM: begin
            if ((x_cnt_r != 7'd127 || y_cnt_r != 7'd127) && counter_r == 1'b1) begin
                SDRAM_read_w = 1'b1;
            end
            else begin
                SDRAM_read_w = 1'b0;
            end
            SDRAM_write_w = 1'b0;
            SDRAM_data_w = 32'd0;
        end
        S_SRAM_to_SDRAM: begin
            SDRAM_read_w = 1'b0;
            if (counter_r == 1'b1) begin
                SDRAM_write_w = 1'b1;
                SDRAM_data_w = {8'd0, buffer_r[15:0], SRAM_data_r[15:8]};
            end
            else begin
                SDRAM_write_w = 1'b0;
                SDRAM_data_w = 32'd0;
            end
        end
        default: begin
            SDRAM_read_w = 1'b0;
            SDRAM_write_w = 1'b0;
            SDRAM_data_w = 32'd0;
        end
    endcase
end

// buffer
always_comb begin
    case (state_r)
        S_SDRAM_to_SRAM: begin
            if (counter_r == 1'b0) begin
                buffer_w = i_SDRAM_data;
            end
            else begin
                buffer_w = buffer_r;
            end
        end
        S_SRAM_to_SDRAM: begin
            if (counter_r == 1'b0) begin
                buffer_w = {16'd0, i_SRAM_data};
            end
            else begin
                buffer_w = buffer_r;
            end
        end
        default: begin
            buffer_w = 32'd0;
        end
    endcase
end

// sequential logic
always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state_r <= S_IDLE;
        x_cnt_r <= 7'd0;
        y_cnt_r <= 7'd0;
        counter_r <= 1'b0;
        buffer_r <= 32'd0;
        SRAM_addr_r <= 20'd0;
        SRAM_enable_r <= 1'b0;
        SRAM_write_r <= 1'b0;
        SRAM_data_r <= 16'd0;
        SDRAM_read_r <= 1'b0;
        SDRAM_write_r <= 1'b0;
        SDRAM_data_r <= 32'd0;
        done_r <= 1'b0;
    end
    else begin
        state_r <= state_w;
        x_cnt_r <= x_cnt_w;
        y_cnt_r <= y_cnt_w;
        counter_r <= counter_w;
        buffer_r <= buffer_w;
        SRAM_addr_r <= SRAM_addr_w;
        SRAM_enable_r <= SRAM_enable_w;
        SRAM_write_r <= SRAM_write_w;
        SRAM_data_r <= SRAM_data_w;
        SDRAM_read_r <= SDRAM_read_w;
        SDRAM_write_r <= SDRAM_write_w;
        SDRAM_data_r <= SDRAM_data_w;
        done_r <= done_w;
    end
end

endmodule