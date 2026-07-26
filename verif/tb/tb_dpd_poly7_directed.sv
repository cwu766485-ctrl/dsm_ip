`timescale 1ns/1ps
`default_nettype none

module tb_dpd_poly7_directed;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic in_valid = 1'b0;
  logic signed [15:0] i_in = 16'sd0;
  logic signed [15:0] q_in = 16'sd0;
  wire in_ready, out_valid;
  wire signed [15:0] i_out, q_out;

  always #5 clk = ~clk;

  dpd_poly #(.POLY_ORDER(7)) dut (
    .clk(clk), .rst_n(rst_n), .enable(1'b1),
    .c1_re(16'sd16384), .c1_im(16'sd0),
    .c3_re(16'sd0), .c3_im(16'sd0), .c5_re(16'sd0), .c5_im(16'sd0),
    .c7_re(16'sd16384), .c7_im(16'sd0),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(in_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(1'b1),
    .sample_count(), .saturation_count()
  );

  initial begin
    repeat (4) @(posedge clk);
    rst_n <= 1'b1;
    @(posedge clk);
    if (!in_ready) $fatal(1, "input was not ready");
    i_in <= 16'sd16384;
    in_valid <= 1'b1;
    @(posedge clk);
    in_valid <= 1'b0;
    wait (out_valid);
    if (i_out !== 16'sd16640 || q_out !== 16'sd0) begin
      $fatal(1, "C7 datapath mismatch: got %0d,%0d", i_out, q_out);
    end
    $display("DPD seventh-order directed PASS");
    $finish;
  end
endmodule

`default_nettype wire
