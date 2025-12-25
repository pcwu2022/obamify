module Classifier (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_start,
    input  logic [15:0] i_SRAM_data,
    output logic [19:0] o_SRAM_addr,
    output logic        o_SRAM_enable,
    output logic [2:0]  o_result,
    output logic        o_done
);

logic [19:0] addr_r, addr_w;
logic        SRAM_enable_r, SRAM_enable_w;
logic [2:0]  result_r, result_w;
logic        done_r, done_w;

logic [3:0]  state_r, state_w;
logic        counter_r, counter_w;
logic [6:0]  x_cnt_r, x_cnt_w;
logic [6:0]  y_cnt_r, y_cnt_w;
logic [23:0] source_pixel_r, source_pixel_w;
logic [24:0] IMG1_sad_r, IMG1_sad_w;
logic [24:0] IMG2_sad_r, IMG2_sad_w;
logic [24:0] IMG3_sad_r, IMG3_sad_w;
logic [24:0] IMG4_sad_r, IMG4_sad_w;
logic [24:0] IMG5_sad_r, IMG5_sad_w;

logic [7:0] R_diff, G_diff, B_diff;

localparam S_IDLE     = 4'd0;
localparam S_SRC      = 4'd1;
localparam S_IMG1     = 4'd2;
localparam S_IMG2     = 4'd3;
localparam S_IMG3     = 4'd4;
localparam S_IMG4     = 4'd5;
localparam S_IMG5     = 4'd6;
localparam S_COMP     = 4'd7;
localparam S_DONE     = 4'd8;

assign o_SRAM_enable = SRAM_enable_r;
assign o_result      = result_r;
// assign o_done        = done_r;
assign o_done = (state_r == S_DONE) ? 1'b1 : 1'b0;

assign R_diff = (source_pixel_r[23:16] > i_SRAM_data[15:8]) ? (source_pixel_r[23:16] - i_SRAM_data[15:8]) : (i_SRAM_data[15:8] - source_pixel_r[23:16]);
assign G_diff = (source_pixel_r[15:8]  > i_SRAM_data[7:0])  ? (source_pixel_r[15:8]  - i_SRAM_data[7:0])  : (i_SRAM_data[7:0]  - source_pixel_r[15:8]);
assign B_diff = (source_pixel_r[7:0]   > i_SRAM_data[15:8]) ? (source_pixel_r[7:0]   - i_SRAM_data[15:8]) : (i_SRAM_data[15:8] - source_pixel_r[7:0]);

// FSM
always_comb begin
    case (state_r)
        S_IDLE: begin
            if (i_start) begin
                state_w = S_SRC;
            end
            else begin
                state_w = S_IDLE;
            end
        end
        S_SRC, S_IMG1, S_IMG2, S_IMG3, S_IMG4: begin
            if (counter_r == 1'b1) begin
                state_w = state_r + 4'd1;
            end
            else begin
                state_w = state_r;
            end
        end
        S_IMG5: begin
            if (counter_r == 1'b1) begin
                if (x_cnt_r == 7'd127 && y_cnt_r == 7'd127) begin
                    state_w = S_COMP;
                end
                else begin
                    state_w = S_SRC;
                end
            end
            else begin
                state_w = S_IMG5;
            end
        end
        S_COMP: begin
            state_w = S_DONE;
        end
        S_DONE: begin
            state_w = S_DONE;
        end
        default: begin
            state_w = S_IDLE;
        end
    endcase
end

// counter
always_comb begin
    case (state_r)
        S_SRC, S_IMG1, S_IMG2, S_IMG3, S_IMG4, S_IMG5: begin
            counter_w = counter_r + 1'b1;
        end
        default: begin
            counter_w = 1'b0;
        end
    endcase
end

// x_cnt, y_cnt
always_comb begin
    case (state_r)
        S_IMG5: begin
            if (counter_r == 1'b1) begin
                if (x_cnt_r == 7'd127) begin
                    x_cnt_w = 7'd0;
                    y_cnt_w = y_cnt_r + 1'b1;
                end
                else begin
                    x_cnt_w = x_cnt_r + 1'b1;
                    y_cnt_w = y_cnt_r;
                end
            end
            else begin
                x_cnt_w = x_cnt_r;
                y_cnt_w = y_cnt_r;
            end
        end
        default: begin
            x_cnt_w = x_cnt_r;
            y_cnt_w = y_cnt_r;
        end
    endcase
end

// source pixel storage
always_comb begin
    if (state_r == S_SRC) begin
        source_pixel_w = source_pixel_r;
        if (counter_r == 1'b0) begin
            source_pixel_w[23:8] = i_SRAM_data;
        end
        else begin
            source_pixel_w[7:0] = i_SRAM_data[15:8];
        end
    end
    else begin
        source_pixel_w = source_pixel_r;
    end
end

// sad calculation
always_comb begin
    case (state_r)
        S_IMG1: begin
            if (counter_r == 1'b0) begin
                IMG1_sad_w = IMG1_sad_r + R_diff + G_diff;
            end
            else begin
                IMG1_sad_w = IMG1_sad_r + B_diff;
            end
            IMG2_sad_w = IMG2_sad_r;
            IMG3_sad_w = IMG3_sad_r;
            IMG4_sad_w = IMG4_sad_r;
            IMG5_sad_w = IMG5_sad_r;
        end
        S_IMG2: begin
            if (counter_r == 1'b0) begin
                IMG2_sad_w = IMG2_sad_r + R_diff + G_diff;
            end
            else begin
                IMG2_sad_w = IMG2_sad_r + B_diff;
            end
            IMG1_sad_w = IMG1_sad_r;
            IMG3_sad_w = IMG3_sad_r;
            IMG4_sad_w = IMG4_sad_r;
            IMG5_sad_w = IMG5_sad_r;
        end
        S_IMG3: begin
            if (counter_r == 1'b0) begin
                IMG3_sad_w = IMG3_sad_r + R_diff + G_diff;
            end
            else begin
                IMG3_sad_w = IMG3_sad_r + B_diff;
            end
            IMG1_sad_w = IMG1_sad_r;
            IMG2_sad_w = IMG2_sad_r;
            IMG4_sad_w = IMG4_sad_r;
            IMG5_sad_w = IMG5_sad_r;
        end
        S_IMG4: begin
            if (counter_r == 1'b0) begin
                IMG4_sad_w = IMG4_sad_r + R_diff + G_diff;
            end
            else begin
                IMG4_sad_w = IMG4_sad_r + B_diff;
            end
            IMG1_sad_w = IMG1_sad_r;
            IMG2_sad_w = IMG2_sad_r;
            IMG3_sad_w = IMG3_sad_r;
            IMG5_sad_w = IMG5_sad_r;
        end
        S_IMG5: begin
            if (counter_r == 1'b0) begin
                IMG5_sad_w = IMG5_sad_r + R_diff + G_diff;
            end
            else begin
                IMG5_sad_w = IMG5_sad_r + B_diff;
            end
            IMG1_sad_w = IMG1_sad_r;
            IMG2_sad_w = IMG2_sad_r;
            IMG3_sad_w = IMG3_sad_r;
            IMG4_sad_w = IMG4_sad_r;
        end
        S_IDLE: begin
            IMG1_sad_w = 24'd0;
            IMG2_sad_w = 24'd0;
            IMG3_sad_w = 24'd0;
            IMG4_sad_w = 24'd0;
            IMG5_sad_w = 24'd0;
        end
        S_SRC: begin
            IMG1_sad_w = IMG1_sad_r;
            IMG2_sad_w = IMG2_sad_r;
            IMG3_sad_w = IMG3_sad_r;
            IMG4_sad_w = IMG4_sad_r;
            IMG5_sad_w = IMG5_sad_r;
        end
        S_DONE: begin
            IMG1_sad_w = IMG1_sad_r;
            IMG2_sad_w = IMG2_sad_r;
            IMG3_sad_w = IMG3_sad_r;
            IMG4_sad_w = IMG4_sad_r;
            IMG5_sad_w = IMG5_sad_r;
        end
        default: begin
            IMG1_sad_w = IMG1_sad_r;
            IMG2_sad_w = IMG2_sad_r;
            IMG3_sad_w = IMG3_sad_r;
            IMG4_sad_w = IMG4_sad_r;
            IMG5_sad_w = IMG5_sad_r;
        end
    endcase
end

// compare
always_comb begin
    if (state_r == S_COMP) begin
        if (IMG1_sad_r <= IMG2_sad_r && IMG1_sad_r <= IMG3_sad_r && IMG1_sad_r <= IMG4_sad_r && IMG1_sad_r <= IMG5_sad_r) begin
            result_w = 3'd0;
        end
        else if (IMG2_sad_r <= IMG1_sad_r && IMG2_sad_r <= IMG3_sad_r && IMG2_sad_r <= IMG4_sad_r && IMG2_sad_r <= IMG5_sad_r) begin
            result_w = 3'd1;
        end
        else if (IMG3_sad_r <= IMG1_sad_r && IMG3_sad_r <= IMG2_sad_r && IMG3_sad_r <= IMG4_sad_r && IMG3_sad_r <= IMG5_sad_r) begin
            result_w = 3'd2;
        end
        else if (IMG4_sad_r <= IMG1_sad_r && IMG4_sad_r <= IMG2_sad_r && IMG4_sad_r <= IMG3_sad_r && IMG4_sad_r <= IMG5_sad_r) begin
            result_w = 3'd3;
        end
        else begin
            result_w = 3'd4;
        end
        done_w = 1'b1;
    end
    else begin
        result_w = result_r;
        done_w = 1'b0;
    end
end

// SRAM address and enable
always_comb begin
    case (state_r)
        S_SRC: begin
            SRAM_enable_w = 1'b1;
            o_SRAM_addr = {13'd0, y_cnt_r, x_cnt_r, counter_r};
        end
        S_IMG1: begin
            SRAM_enable_w = 1'b1;
            o_SRAM_addr = {13'd1, y_cnt_r, x_cnt_r, counter_r};
        end
        S_IMG2: begin
            SRAM_enable_w = 1'b1;
            o_SRAM_addr = {13'd2, y_cnt_r, x_cnt_r, counter_r};
        end
        S_IMG3: begin
            SRAM_enable_w = 1'b1;
            o_SRAM_addr = {13'd3, y_cnt_r, x_cnt_r, counter_r};
        end
        S_IMG4: begin
            SRAM_enable_w = 1'b1;
            o_SRAM_addr = {13'd4, y_cnt_r, x_cnt_r, counter_r};
        end
        S_IMG5: begin
            SRAM_enable_w = 1'b1;
            o_SRAM_addr = {13'd5, y_cnt_r, x_cnt_r, counter_r};
        end
        default: begin
            SRAM_enable_w = 1'b0;
            o_SRAM_addr = 20'd0;
        end
    endcase
end

// sequential
always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state_r         <= S_IDLE;
        counter_r       <= 1'b0;
        x_cnt_r        <= 7'd0;
        y_cnt_r        <= 7'd0;
        source_pixel_r  <= 24'd0;
        IMG1_sad_r      <= 25'd0;
        IMG2_sad_r      <= 25'd0;
        IMG3_sad_r      <= 25'd0;
        IMG4_sad_r      <= 25'd0;
        IMG5_sad_r      <= 25'd0;
        result_r        <= 3'd0;
        done_r          <= 1'b0;
        SRAM_enable_r   <= 1'b0;
        addr_r          <= 20'd0;
    end
    else begin
        state_r         <= state_w;
        counter_r       <= counter_w;
        x_cnt_r        <= x_cnt_w;
        y_cnt_r        <= y_cnt_w;
        source_pixel_r  <= source_pixel_w;
        IMG1_sad_r      <= IMG1_sad_w;
        IMG2_sad_r      <= IMG2_sad_w;
        IMG3_sad_r      <= IMG3_sad_w;
        IMG4_sad_r      <= IMG4_sad_w;
        IMG5_sad_r      <= IMG5_sad_w;
        result_r        <= result_w;
        done_r          <= done_w;
        SRAM_enable_r   <= SRAM_enable_w;
        addr_r          <= o_SRAM_addr;
    end
end

endmodule