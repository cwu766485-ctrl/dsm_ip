`timescale 1ns/1ps
`default_nettype none

module tb_dsm_iq_analog_top;
  localparam int W = 16;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic in_valid = 1'b0;
  logic signed [W-1:0] i_in = '0;
  logic signed [W-1:0] q_in = '0;
  logic in_ready;
  logic dsm_valid;
  logic i_bit;
  logic q_bit;
  logic signed [7:0] i_yout;
  logic signed [7:0] q_yout;
  int valid_count;
  int i_toggle_count;
  int q_toggle_count;
  logic prev_i;
  logic prev_q;

  dsm_iq_analog_top #(
    .W(W), .DSM_OUT_W(8), .ALGORITHM(1), .INTERP_MODE(0)
  ) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_in(i_in), .q_in(q_in),
    .in_ready(in_ready), .dsm_valid(dsm_valid), .i_bit(i_bit), .q_bit(q_bit),
    .i_yout(i_yout), .q_yout(q_yout)
  );

  always #5 clk = ~clk;

  initial begin
    repeat (4) @(posedge clk);
    rst_n <= 1'b1;
    for (int n = 0; n < 256; n++) begin
      @(posedge clk);
      if (!in_ready) $fatal(1, "Analog-IQ wrapper unexpectedly backpressured mode 0 input");
      in_valid <= 1'b1;
      i_in <= (n[4:0] < 16) ? 16'sd8192 : -16'sd8192;
      q_in <= (n[5:0] < 32) ? 16'sd4096 : -16'sd4096;
    end
    @(posedge clk);
    in_valid <= 1'b0;
    repeat (3) @(posedge clk);
    if (valid_count != 256) $fatal(1, "Expected 256 I/Q DSM samples, got %0d", valid_count);
    if (i_toggle_count == 0 || q_toggle_count == 0) $fatal(1, "Analog-IQ DSM outputs did not toggle");
    $display("Analog-IQ smoke PASS: valid=%0d i_toggle=%0d q_toggle=%0d", valid_count, i_toggle_count, q_toggle_count);
    $finish;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      valid_count <= 0;
      i_toggle_count <= 0;
      q_toggle_count <= 0;
      prev_i <= 1'b1;
      prev_q <= 1'b1;
    end else if (dsm_valid) begin
      valid_count <= valid_count + 1;
      if (i_bit != prev_i) i_toggle_count <= i_toggle_count + 1;
      if (q_bit != prev_q) q_toggle_count <= q_toggle_count + 1;
      prev_i <= i_bit;
      prev_q <= q_bit;
    end
  end
endmodule

`default_nettype wire
