`timescale 1ns/100ps
`define CYCLE       20  // 50MHz
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   5000

module tb_Top ();
  logic rst_n, clk;
  logic key1, key2;
  logic vga_done, 
  logic camera_start, camera_end;
  logic classifier_start, classifier_done;
  logic obamify_epoch_start, obamify_epoch_finished;
  logic memory_start;
  logic obamify_start, obamify_finished;
  parameter N = 5; 
            
  Top top0(
    .i_clk(clk),
    .i_rst_n(rst_n),
    .i_key_1(key1),
    .i_key_2(key2),
    .i_vga_done(vga_done),
    .i_classifier_done(classifier_done),
    .i_obamify_finished(obamify_finished),
    .i_obamify_epoch_finished(obamify_epoch_finished),

    .o_camera_start(camera_start),
    .o_camera_end(camera_end),
    .o_classifier_start(classifier_start),
    .o_obamify_start(obamify_start),
    .o_obamify_epoch_start(obamify_epoch_start),
    .o_memory_start(memory_start)
  );

  always begin
    #(`HCYCLE)
    clk = ~clk;
  end

  initial begin
    clk = 1'b0;
    $fsdbDumpfile("vga.fsdb");
    $fsdbDumpvars(0, tb_VGA, "+mda");
    rst_n = 1'b1;
    # (1.2 * `CYCLE);
    rst_n = 1'b0;
    # (2.1 * `CYCLE);
    rst_n = 1'b1;
    // ========== Test Sequence ==========
    # (3 * `CYCLE);
    key1 = 1'b1;
    # (1 * `CYCLE);
    key1 = 1'b0;

    # (3 * `CYCLE);
    key2 = 1'b1;
    # (1 * `CYCLE);
    key2 = 1'b0;

    # (3 * `CYCLE);
    key1 = 1'b1;
    # (1 * `CYCLE);
    key1 = 1'b0;

    test_classifier_done(classifier_start, classifier_done);
    
    test_obamify_finished(obamify_start, obamify_epoch_start, obamify_finished, obamify_epoch_finished);

    # (`CYCLE * `MAX_CYCLE);
    $finish;
  end

  task test_classifier_done;
    input start;
    output done;
    begin
      wait (start == 1);     
      #(5 * `CYCLE);
      done = 1'b1;
    end
  endtask

  task test_obamify_finished;
    input start;
    input epoch_start;
    output finished;
    output epoch_finished;

    begin
      integer i;
      wait (start == 1);
      for (i = 0; i < N; i = i + 1) begin
        #(10 * `CYCLE);

        epoch_finished = 1'b1;
        # (1 * `CYCLE);
        epoch_finished = 1'b0;

        wait (vga_done == 1);
        #(5 * `CYCLE);
        
        epoch_start = 1'b1;
        #(5 * `CYCLE);
        epoch_start = 1'b0;
      end
      finished = 1'b1;
      # (1 * `CYCLE);
      finished = 1'b0;
    end
  endtask

endmodule