`timescale 1ns/1ps
`default_nettype none

module tb_dsm_core_bp_single;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic enable = 1'b0;
  logic signed [15:0] x_in = '0;
  logic y_bit;
  logic signed [15:0] y_signed;
  logic signed [27:0] s1_state;
  logic signed [27:0] s2_state;
  int count;
  int ones;
  int zeros;

  dsm_core_bp_single dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .x_in(x_in),
    .y_bit(y_bit), .y_signed(y_signed), .s1_state(s1_state), .s2_state(s2_state)
  );

  always #5 clk = ~clk;

  initial begin
    repeat (4) @(posedge clk);
    rst_n <= 1'b1;
    for (int n = 0; n < 256; n++) begin
      @(posedge clk);
      enable <= 1'b1;
      x_in <= (n[3:0] < 8) ? 16'sd8192 : -16'sd8192;
    end
    @(posedge clk);
    enable <= 1'b0;
    repeat (2) @(posedge clk);
    if (count != 256) $fatal(1, "Expected 256 samples, got %0d", count);
    if (ones == 0 || zeros == 0) $fatal(1, "BP single-loop output did not toggle");
    $display("BP single-loop smoke PASS: samples=%0d ones=%0d zeros=%0d", count, ones, zeros);
    $finish;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      count <= 0; ones <= 0; zeros <= 0;
    end else if (enable) begin
      count <= count + 1;
      if (y_bit) ones <= ones + 1; else zeros <= zeros + 1;
      if (y_signed != (y_bit ? 16'sh7fff : -16'sh7fff)) $fatal(1, "signed output mismatch");
    end
  end
endmodule

`default_nettype wire
