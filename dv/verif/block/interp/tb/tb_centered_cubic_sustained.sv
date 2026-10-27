`timescale 1ns/1ps
`default_nettype none

// Sustained block-level throughput contract for the centered-cubic x2 FIR.
// The source presents 1024 contiguous vectors and the sink is permanently ready.
module tb_centered_cubic_sustained;
  localparam int LANES = 8;
  localparam int WORDS = 1024;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b1;
  logic in_valid = 1'b0;
  logic in_frame_start = 1'b0;
  logic in_frame_end = 1'b0;
  logic in_tail = 1'b0;
  logic signed [LANES*16-1:0] in_i_vec = '0;
  logic signed [LANES*16-1:0] in_q_vec = '0;
  logic out_ready = 1'b1;
  wire in_ready;
  wire out_valid;
  wire out_frame_start, out_frame_end, out_tail;
  wire signed [2*LANES*16-1:0] out_i_vec, out_q_vec;

  integer cycle_count = 0;
  integer accepted = 0;
  integer received = 0;
  integer output_bubbles = 0;
  integer first_output_cycle = -1;
  integer last_output_cycle = -1;

  always #2.5 clk = ~clk;

  dsm_interp_x2_centered_cubic_vector #(
    .W(16), .LANES(LANES), .APPEND_TAIL_VECTOR(1'b0)
  ) dut (.*);

  always @(posedge clk) begin
    if (!rst_n) begin
      cycle_count = 0;
      accepted = 0;
      received = 0;
      output_bubbles = 0;
      first_output_cycle = -1;
      last_output_cycle = -1;
    end else begin
      cycle_count = cycle_count + 1;
      if (cycle_count > 10000)
        $fatal(1, "centered-cubic sustained test timed out");

      if (in_valid && in_ready)
        accepted = accepted + 1;

      if (out_valid && out_ready) begin
        if ((out_i_vec !== '0) || (out_q_vec !== '0))
          $fatal(1, "zero-input arithmetic mismatch at output %0d", received);
        if ((received == 0) && !out_frame_start)
          $fatal(1, "first output is missing frame-start");
        if ((received != 0) && out_frame_start)
          $fatal(1, "unexpected frame-start at output %0d", received);
        if ((received == WORDS-1) && !out_frame_end)
          $fatal(1, "last real output is missing frame-end");
        if ((received != WORDS-1) && out_frame_end)
          $fatal(1, "unexpected frame-end at output %0d", received);
        if (received == 0)
          first_output_cycle = cycle_count;
        if ((last_output_cycle >= 0) &&
            (cycle_count != last_output_cycle + 1))
          output_bubbles = output_bubbles +
                           (cycle_count - last_output_cycle - 1);
        last_output_cycle = cycle_count;
        received = received + 1;
      end
    end
  end

  initial begin : p_source
    repeat (4) @(negedge clk);
    rst_n = 1'b1;

    // The final synthetic tail vector supplies look-ahead for the last real
    // vector; the later interpolation stage consumes/drops this tail.
    for (integer word_index = 0; word_index <= WORDS; word_index = word_index + 1) begin
      @(negedge clk);
      in_valid = 1'b1;
      in_frame_start = (word_index == 0);
      in_frame_end = (word_index == WORDS-1);
      in_tail = (word_index == WORDS);
      in_i_vec = '0;
      in_q_vec = '0;
      do @(posedge clk); while (in_ready !== 1'b1);
    end

    @(negedge clk);
    in_valid = 1'b0;
    in_frame_start = 1'b0;
    in_frame_end = 1'b0;

    wait (received == WORDS);
    @(negedge clk);
    if (accepted != WORDS+1)
      $fatal(1, "accepted %0d/%0d input vectors including tail", accepted, WORDS+1);
    if (output_bubbles != 0)
      $fatal(1, "sustained output had %0d bubbles after its first word", output_bubbles);
    $display("CENTERED_CUBIC_SUSTAINED_PASS inputs=%0d outputs=%0d bubbles=%0d output_cycles=%0d",
             accepted, received, output_bubbles, last_output_cycle-first_output_cycle);
    $finish;
  end
endmodule

`default_nettype wire
