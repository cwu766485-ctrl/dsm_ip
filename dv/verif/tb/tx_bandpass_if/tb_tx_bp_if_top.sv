`timescale 1ns/1ps
`default_nettype none

module tb_tx_bp_if_top;
  localparam int W = 16;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic in_valid = 1'b0;
  logic signed [W-1:0] i_in = '0;
  logic signed [W-1:0] q_in = '0;
  logic if_valid;
  logic signed [W-1:0] if_sample;
  logic rf_valid;
  logic rf_bit;
  logic signed [W-1:0] rf_signed;
  logic [1:0] if_phase;
  int valid_count;
  int one_count;
  int zero_count;

  tx_bp_if_top #(.W(W)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .i_in(i_in), .q_in(q_in),
    .if_valid(if_valid), .if_sample(if_sample), .rf_valid(rf_valid),
    .rf_bit(rf_bit), .rf_signed(rf_signed), .if_phase(if_phase)
  );

  always #5 clk = ~clk;

  initial begin
    repeat (4) @(posedge clk);
    rst_n <= 1'b1;
    for (int n = 0; n < 256; n++) begin
      @(posedge clk);
      in_valid <= 1'b1;
      i_in <= (n[4:0] < 16) ? 16'sd8192 : -16'sd8192;
      q_in <= (n[5:0] < 32) ? 16'sd4096 : -16'sd4096;
    end
    @(posedge clk);
    in_valid <= 1'b0;
    repeat (4) @(posedge clk);
    if (valid_count != 256) $fatal(1, "Expected 256 BPDSM output samples, got %0d", valid_count);
    if (one_count == 0 || zero_count == 0) $fatal(1, "BPDSM output did not toggle");
    $display("BP IF smoke PASS: valid=%0d one=%0d zero=%0d", valid_count, one_count, zero_count);
    $finish;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      valid_count <= 0;
      one_count <= 0;
      zero_count <= 0;
    end else if (rf_valid) begin
      valid_count <= valid_count + 1;
      if (rf_bit) one_count <= one_count + 1;
      else zero_count <= zero_count + 1;
      if (rf_signed != (rf_bit ? 16'sh7fff : -16'sh7fff)) $fatal(1, "rf_signed/bit mismatch");
    end
  end
endmodule

`default_nettype wire
