module Top(
  input i_clk,
  input i_rst_n,
  input i_key_1,
  input i_key_2,
  input i_vga_done,
  input i_classifier_done,
  input i_obamify_finished,
  input i_obamify_epoch_finished,

  output o_camera_start,
  output o_camera_end,
  output o_classifier_start,
  output o_obamify_start,
  output o_obamify_epoch_start,
  output o_memory_start
);
  logic [2:0] state_nxt           , state;
  logic o_camera_start_nxt        , o_camera_start_reg;
  logic o_camera_end_nxt          , o_camera_end_reg;
  logic o_classifier_start_nxt    , o_classifier_start_reg;
  logic o_obamify_start_nxt       , o_obamify_start_reg;
  logic o_obamify_epoch_start_nxt , o_obamify_epoch_start_reg;
  logic o_memory_start_nxt        , o_memory_start_reg;

  assign o_camera_start        = o_camera_start_reg;
  assign o_camera_end          = o_camera_end_reg;
  assign o_classifier_start    = o_classifier_start_reg;
  assign o_obamify_start       = o_obamify_start_reg;
  assign o_obamify_epoch_start = o_obamify_epoch_start_reg;
  assign o_memory_start        = o_memory_start_reg;

  parameter INIT_I2C = 3'b000;
  parameter INIT_FLA = 3'b001;
  parameter IDLE = 3'b010;
  parameter FIX  = 3'b011;
  parameter CLA  = 3'b100;
  parameter DSP  = 3'b101;
  parameter FIN  = 3'b110;
  
//output: camera switch, dsp switch, classifier switch, 
  always_comb begin
    case (state) 
      IDLE: begin
        if (i_key_1) begin
          state_nxt = FIX;
          o_camera_end_nxt         = 1'b1;
        end
        else begin
          state_nxt = IDLE;
          o_camera_end_nxt         = 1'b0;
        end
        o_camera_start_nxt        = 1'b1;
        o_memory_start_nxt        = 1'b0;
        o_classifier_start_nxt    = 1'b0;
        o_obamify_start_nxt       = 1'b0;
        o_obamify_epoch_start_nxt = 1'b0;
      end
      FIX: begin
        if (i_key_1)      state_nxt = CLA;
        else if (i_key_2) state_nxt = IDLE; //camera start again
        else              state_nxt = state;
        o_camera_start_nxt       = 1'b0;
        o_camera_end_nxt         = 1'b1;
        o_memory_start_nxt        = 1'b0;
        o_classifier_start_nxt    = 1'b0;
        o_obamify_start_nxt       = 1'b0;
        o_obamify_epoch_start_nxt = 1'b0;
      end
      CLA: begin //classifier -> dsp
        if (i_classifier_done) begin
          state_nxt = DSP;
          o_obamify_start_nxt       = 1'b1;
          o_obamify_epoch_start_nxt = 1'b1; 
        end
        else begin
          state_nxt = state;
          o_obamify_start_nxt       = o_obamify_start_reg;
          o_obamify_epoch_start_nxt = o_obamify_epoch_start_reg; 
        end
        o_camera_start_nxt       = 1'b0;
        o_camera_end_nxt         = 1'b1;
        o_classifier_start_nxt = 1'b0;
        o_memory_start_nxt     = 1'b0;
      end
      DSP: begin
        if (i_obamify_finished) state_nxt = FIN; //change to the done of file transfer
        else                    state_nxt = state;

        if (i_obamify_epoch_finished)
          o_memory_start_nxt = 1'b1;
        else
          o_memory_start_nxt = 1'b0;

        if (i_vga_done)
          o_obamify_epoch_start_nxt = 1'b1;
        else
          o_obamify_epoch_start_nxt = 1'b0;
        o_camera_start_nxt       = 1'b0;
        o_camera_end_nxt         = 1'b1;
        o_obamify_start_nxt = 1'b0;
        o_classifier_start_nxt = 1'b0;
      end
      FIN: begin
        if (i_key_2) state_nxt = IDLE; //camera start again
        else         state_nxt = state;
        o_camera_start_nxt       = 1'b0;
        o_camera_end_nxt         = 1'b1;
        o_memory_start_nxt        = 1'b0;
        o_classifier_start_nxt    = 1'b0;
        o_obamify_start_nxt       = 1'b0;
        o_obamify_epoch_start_nxt = 1'b0;
      end
      default: begin
        state_nxt = IDLE;
        o_camera_start_nxt       = 1'b1;
        o_camera_end_nxt         = 1'b0;
        o_memory_start_nxt        = o_memory_start_reg;
        o_classifier_start_nxt    = o_classifier_start_reg;
        o_obamify_start_nxt       = o_obamify_start_reg;
        o_obamify_epoch_start_nxt = o_obamify_epoch_start_reg;
      end
    endcase
  end

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      state                     <= IDLE;
      o_camera_start_reg        <= 1'b0;
      o_camera_end_reg          <= 1'b0;
      o_classifier_start_reg    <= 1'b0;
      o_obamify_start_reg       <= 1'b0;
      o_obamify_epoch_start_reg <= 1'b0;
      o_memory_start_reg        <= 1'b0;
    end
    else begin
      state                     <= state_nxt;
      o_camera_start_reg        <= o_camera_start_nxt;
      o_camera_end_reg          <= o_camera_end_nxt;
      o_classifier_start_reg    <= o_classifier_start_nxt;
      o_obamify_start_reg       <= o_obamify_start_nxt;
      o_obamify_epoch_start_reg <= o_obamify_epoch_start_nxt;
      o_memory_start_reg        <= o_memory_start_nxt;
    end
  end
endmodule