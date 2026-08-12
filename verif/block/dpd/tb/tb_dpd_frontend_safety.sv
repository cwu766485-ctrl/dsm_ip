`timescale 1ns/1ps
`default_nettype none

module tb_dpd_frontend_safety;
  localparam int W = 16;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [1:0] mode = 2'd3;
  logic mp_coeff_we = 1'b0;
  logic mp_commit = 1'b0;
  logic [2:0] mp_coeff_tap = 3'd0;
  logic [1:0] mp_coeff_order = 2'd0;
  logic signed [15:0] mp_coeff_re = 16'sd0;
  logic signed [15:0] mp_coeff_im = 16'sd0;
  wire mp_active_bank;
  wire mp_commit_rejected;
  wire safety_fault;

  always #5 clk = ~clk;

  dpd_frontend #(.W(W), .COEFF_W(16), .COEFF_FRAC(14), .LUT_AW(4)) dut (
    .clk(clk), .rst_n(rst_n), .mode(mode),
    .c1_re(16'sd16384), .c1_im(16'sd0),
    .c3_re(16'sd0), .c3_im(16'sd0),
    .c5_re(16'sd0), .c5_im(16'sd0),
    .c7_re(16'sd0), .c7_im(16'sd0),
    .mp_active_taps(3'd2), .mp_coeff_we(mp_coeff_we),
    .mp_commit(mp_commit), .mp_coeff_tap(mp_coeff_tap),
    .mp_coeff_order(mp_coeff_order), .mp_coeff_re(mp_coeff_re),
    .mp_coeff_im(mp_coeff_im), .mp_coeff_rdata_re(), .mp_coeff_rdata_im(),
    .mp_active_bank(mp_active_bank),
    .lut_we(1'b0), .lut_commit(1'b0), .lut_waddr(4'd0),
    .lut_wgain_re(16'sd0), .lut_wgain_im(16'sd0), .lut_raddr(4'd0),
    .lut_rgain_re(), .lut_rgain_im(), .lut_active_bank(),
    .safety_enable(1'b1), .safety_clear(1'b0),
    .safety_fault(safety_fault), .mp_commit_rejected(mp_commit_rejected),
    .lut_commit_rejected(),
    .i_in(16'sd0), .q_in(16'sd0), .in_valid(1'b0), .in_ready(),
    .i_out(), .q_out(), .out_valid(), .out_ready(1'b1),
    .sample_count(), .saturation_count()
  );

  initial begin
    repeat (3) @(posedge clk);
    rst_n <= 1'b1;
    @(posedge clk);
    mp_coeff_re <= 16'sd30000;
    mp_coeff_we <= 1'b1;
    @(posedge clk);
    mp_coeff_we <= 1'b0;
    mp_commit <= 1'b1;
    @(posedge clk);
    mp_commit <= 1'b0;
    @(posedge clk);
    if (!mp_commit_rejected) $fatal(1, "unsafe memory-DPD commit was not rejected");
    if (mp_active_bank !== 1'b0) $fatal(1, "unsafe commit changed active bank");
    if (safety_fault !== 1'b0) $fatal(1, "unexpected saturation safety fault");
    $display("DPD safety PASS");
    $finish;
  end
endmodule

`default_nettype wire
