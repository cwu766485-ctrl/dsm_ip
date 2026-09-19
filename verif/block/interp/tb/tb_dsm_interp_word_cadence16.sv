`timescale 1ns/1ps
`default_nettype none

module tb_dsm_interp_word_cadence16;
  logic clk = 1'b0, rst_n = 1'b0, enable = 1'b0, in_valid = 1'b0;
  logic signed [255:0] in_i_vec = '0, in_q_vec = '0;
  wire in_ready, source_word_valid, underflow;
  wire [4:0] output_word_phase;
  wire signed [255:0] source_i_vec, source_q_vec;
  integer accepted = 0;

  dsm_interp_word_cadence16 #(.WORD_PERIOD(32)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .in_valid(in_valid), .in_ready(in_ready),
    .in_i_vec(in_i_vec), .in_q_vec(in_q_vec), .source_word_valid(source_word_valid),
    .output_word_phase(output_word_phase), .source_i_vec(source_i_vec),
    .source_q_vec(source_q_vec), .underflow(underflow)
  );
  always #5 clk = ~clk;

  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1'b1; enable = 1'b1; in_valid = 1'b1;
    in_i_vec = {240'd0, 16'hbeef};
    for (int cycle = 0; cycle < 96; cycle++) begin
      @(negedge clk);
      in_valid = in_ready;
      in_i_vec = {240'd0, cycle[15:0]};
      in_q_vec = {240'd0, cycle + 1};
      if (in_ready) accepted = accepted + 1;
      @(posedge clk); #1;
      if (underflow) $fatal(1, "unexpected cadence underflow");
    end
    if (accepted < 3) $fatal(1, "accepted=%0d expected at least 3", accepted);
    $display("INTERP_WORD_CADENCE16_PASS accepted=%0d", accepted);
    $finish;
  end
endmodule

`default_nettype wire
