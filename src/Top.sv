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
  output o_inv_memory_start,
  output o_memory_start,
  output [2:0] o_state
);
  logic [2:0] state_nxt           , state;
  logic o_camera_start_nxt        , o_camera_start_reg;
  logic o_camera_end_nxt          , o_camera_end_reg;
  logic o_classifier_start_nxt    , o_classifier_start_reg;
  logic o_obamify_start_nxt       , o_obamify_start_reg;
  logic o_obamify_epoch_start_nxt , o_obamify_epoch_start_reg;
  logic o_memory_start_nxt        , o_memory_start_reg;
  logic o_inv_memory_start_nxt    , o_inv_memory_start_reg;
  logic dsp_flag_nxt              , dsp_flag_reg;

  assign o_camera_start        = o_camera_start_reg;
  assign o_camera_end          = o_camera_end_reg;
  assign o_classifier_start    = o_classifier_start_reg;
  assign o_obamify_start       = o_obamify_start_reg;
  assign o_obamify_epoch_start = o_obamify_epoch_start_reg;
  assign o_inv_memory_start    = o_inv_memory_start_reg;
  assign o_memory_start        = o_memory_start_reg;
  assign o_state               = state;
  
  parameter IDLE = 3'b001;
  parameter FIX  = 3'b010;
  parameter CLA  = 3'b011;
  parameter DSP  = 3'b100;
  parameter TRA  = 3'b101;
  parameter FIN  = 3'b110;

//output: camera switch, dsp switch, classifier switch, 
  always_comb begin
    case (state) 
      IDLE: begin
        if (i_key_1) begin
          state_nxt = FIX;
          o_camera_end_nxt        = 1'b1;
          o_inv_memory_start_nxt  = 1'b1;
        end
        else begin
          state_nxt = state;
          o_camera_end_nxt        = 1'b0;
          o_inv_memory_start_nxt  = 1'b0;
        end
        o_camera_start_nxt        = 1'b1;
        o_memory_start_nxt        = 1'b0;
        o_classifier_start_nxt    = 1'b0;
        o_obamify_start_nxt       = 1'b0;
        o_obamify_epoch_start_nxt = 1'b0;
        dsp_flag_nxt              = 1'b0;
      end
      FIX: begin
        if (i_key_1)      begin
          state_nxt = CLA;
          o_classifier_start_nxt    = 1'b1;
        end
        else if (i_key_2) begin
          state_nxt = IDLE; //camera start again
          o_classifier_start_nxt    = 1'b0;
        end
        else begin
          state_nxt = state;
          o_classifier_start_nxt    = 1'b0;
        end
        o_inv_memory_start_nxt      = 1'b0;
        o_camera_start_nxt          = 1'b0;
        o_camera_end_nxt            = 1'b1;
        o_memory_start_nxt          = 1'b0;
        o_obamify_start_nxt         = 1'b0;
        o_obamify_epoch_start_nxt   = 1'b0;
        dsp_flag_nxt                = 1'b0;
      end
      CLA: begin //classifier -> dsp
        if (i_classifier_done) begin
          state_nxt = DSP;
          o_obamify_start_nxt       = 1'b1;
          o_obamify_epoch_start_nxt = 1'b1; 
        end
        else begin
          state_nxt = state;
          o_obamify_start_nxt       = 1'b0;
          o_obamify_epoch_start_nxt = 1'b0; 
        end
        o_inv_memory_start_nxt      = 1'b0;
        o_camera_start_nxt          = 1'b0;
        o_camera_end_nxt            = 1'b1;
        o_classifier_start_nxt      = 1'b0;
        o_memory_start_nxt          = 1'b0;
        dsp_flag_nxt                = 1'b0;
      end
      DSP: begin
        if (i_obamify_epoch_finished)
          o_memory_start_nxt = 1'b1;
        else
          o_memory_start_nxt = 1'b0;

        case ({i_obamify_finished, i_obamify_epoch_finished})
          2'b00: begin
            state_nxt = state;
            dsp_flag_nxt              = 1'b0;
          end
          2'b01: begin
            state_nxt = TRA;
            dsp_flag_nxt              = 1'b0;
          end
          // 2'b10: begin //not happening
          //   o_obamify_start_nxt       = 1'b0;
          //   o_obamify_epoch_start_nxt = o_obamify_epoch_start_reg;
          // end
          2'b11: begin
            state_nxt = TRA;
            dsp_flag_nxt              = 1'b1;
          end
          default: begin
            state_nxt = state;
            dsp_flag_nxt              = 1'b0;
          end
        endcase
        o_inv_memory_start_nxt   = 1'b0;
        o_camera_start_nxt       = 1'b0;
        o_camera_end_nxt         = 1'b1;
        o_obamify_start_nxt = 1'b0;
        o_obamify_epoch_start_nxt = 1'b0;
        o_classifier_start_nxt = 1'b0;
      end
      TRA: begin
        if (i_vga_done) begin
          if (dsp_flag_reg == 1'b1) begin
            state_nxt = FIN; //change to the done of file transfer
            o_obamify_epoch_start_nxt = 1'b0;
          end
          else begin
            state_nxt = DSP; //change to the done of file transfer
            o_obamify_epoch_start_nxt = 1'b1;
          end
        end
        else begin
          state_nxt = state;
          o_obamify_epoch_start_nxt = 1'b0;
        end
        o_inv_memory_start_nxt    = 1'b0;
        o_camera_start_nxt        = 1'b0;
        o_camera_end_nxt          = 1'b1;
        o_memory_start_nxt        = 1'b0;
        o_classifier_start_nxt    = 1'b0;
        o_obamify_start_nxt       = 1'b0;
        dsp_flag_nxt              = dsp_flag_reg;
      end
      FIN: begin
        if (i_key_2) state_nxt = IDLE; //camera start again
        else         state_nxt = state;
        o_inv_memory_start_nxt    = 1'b0;
        o_camera_start_nxt        = 1'b0;
        o_camera_end_nxt          = 1'b1;
        o_memory_start_nxt        = 1'b0;
        o_classifier_start_nxt    = 1'b0;
        o_obamify_start_nxt       = 1'b0;
        o_obamify_epoch_start_nxt = 1'b0;
        dsp_flag_nxt              = 1'b0;
      end
      default: begin
        state_nxt = IDLE;
        o_inv_memory_start_nxt    = 1'b0;
        o_camera_start_nxt        = 1'b1;
        o_camera_end_nxt          = 1'b0;
        o_memory_start_nxt        = o_memory_start_reg;
        o_classifier_start_nxt    = o_classifier_start_reg;
        o_obamify_start_nxt       = o_obamify_start_reg;
        o_obamify_epoch_start_nxt = o_obamify_epoch_start_reg;
        dsp_flag_nxt              = 1'b0;
      end
    endcase
  end

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      state                     <= IDLE;
      o_inv_memory_start_reg    <= 1'b0;
      o_camera_start_reg        <= 1'b0;
      o_camera_end_reg          <= 1'b0;
      o_classifier_start_reg    <= 1'b0;
      o_obamify_start_reg       <= 1'b0;
      o_obamify_epoch_start_reg <= 1'b0;
      o_memory_start_reg        <= 1'b0;
      dsp_flag_reg              <= 1'b0;
    end
    else begin
      state                     <= state_nxt;
      o_inv_memory_start_reg    <= o_inv_memory_start_nxt;
      o_camera_start_reg        <= o_camera_start_nxt;
      o_camera_end_reg          <= o_camera_end_nxt;
      o_classifier_start_reg    <= o_classifier_start_nxt;
      o_obamify_start_reg       <= o_obamify_start_nxt;
      o_obamify_epoch_start_reg <= o_obamify_epoch_start_nxt;
      o_memory_start_reg        <= o_memory_start_nxt;
      dsp_flag_reg              <= dsp_flag_nxt;
    end
  end
endmodule