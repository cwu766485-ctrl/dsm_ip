`timescale 1ns/1ps
`default_nettype none

module tb_dpd_frontend_protocol;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [1:0] mode = 2'd1;
  logic signed [15:0] i_in = '0, q_in = '0;
  logic in_valid = 1'b0, out_ready = 1'b1;
  logic mp_coeff_we = 1'b0, mp_commit = 1'b0;
  logic [2:0] mp_coeff_tap = '0;
  logic [1:0] mp_coeff_order = '0;
  logic signed [15:0] mp_coeff_re = '0, mp_coeff_im = '0;
  logic safety_clear = 1'b0;
  wire in_ready, out_valid, mp_active_bank, safety_fault, mp_commit_rejected;
  wire signed [15:0] i_out, q_out;

  always #5 clk = ~clk;

  dpd_frontend dut (
    .clk(clk), .rst_n(rst_n), .mode(mode),
    .c1_re(16'sd16384), .c1_im(16'sd0), .c3_re(16'sd0), .c3_im(16'sd0),
    .c5_re(16'sd0), .c5_im(16'sd0), .c7_re(16'sd0), .c7_im(16'sd0),
    .mp_active_taps(3'd2), .mp_coeff_we(mp_coeff_we), .mp_commit(mp_commit),
    .mp_coeff_tap(mp_coeff_tap), .mp_coeff_order(mp_coeff_order),
    .mp_coeff_re(mp_coeff_re), .mp_coeff_im(mp_coeff_im),
    .mp_coeff_rdata_re(), .mp_coeff_rdata_im(), .mp_active_bank(mp_active_bank),
    .lut_we(1'b0), .lut_commit(1'b0), .lut_waddr('0),
    .lut_wgain_re('0), .lut_wgain_im('0), .lut_raddr('0),
    .lut_rgain_re(), .lut_rgain_im(), .lut_active_bank(),
    .safety_enable(1'b1), .safety_clear(safety_clear), .safety_fault(safety_fault),
    .mp_commit_rejected(mp_commit_rejected), .lut_commit_rejected(),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(in_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(out_ready),
    .sample_count(), .saturation_count()
  );

  property p_backpressure_stable;
    @(posedge clk) disable iff (!rst_n)
      out_valid && !out_ready |=> out_valid && $stable(i_out) && $stable(q_out);
  endproperty
  assert property (p_backpressure_stable)
    else $fatal(1, "output changed while backpressured");
  cover property (@(posedge clk) disable iff (!rst_n) out_valid && !out_ready);
  cover property (@(posedge clk) disable iff (!rst_n) mp_commit_rejected);
  cover property (@(posedge clk) disable iff (!rst_n) safety_fault);

  task automatic send_sample(input logic signed [15:0] i, input logic signed [15:0] q);
    begin
      @(posedge clk);
      while (!in_ready) @(posedge clk);
      i_in <= i; q_in <= q; in_valid <= 1'b1;
      @(posedge clk);
      in_valid <= 1'b0;
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n <= 1'b1;
    @(posedge clk);
    if (out_valid !== 1'b0 || safety_fault !== 1'b0 || mp_active_bank !== 1'b0)
      $fatal(1, "reset state is not deterministic");

    send_sample(16'sd4096, -16'sd2048);
    wait (out_valid);
    out_ready <= 1'b0;
    repeat (2) @(posedge clk);
    out_ready <= 1'b1;
    @(posedge clk);

    // An unsafe shadow coefficient must not cross the active-bank boundary.
    mp_coeff_re <= 16'sd30000;
    mp_coeff_we <= 1'b1;
    @(posedge clk);
    mp_coeff_we <= 1'b0;
    mp_commit <= 1'b1;
    @(posedge clk);
    mp_commit <= 1'b0;
    @(posedge clk);
    if (!mp_commit_rejected || mp_active_bank !== 1'b0)
      $fatal(1, "unsafe bank commit was accepted");

    // Explicitly abandon the invalid shadow bank before reloading it.
    safety_clear <= 1'b1;
    @(posedge clk);
    safety_clear <= 1'b0;

    // A safe write and commit is allowed and changes the active bank exactly once.
    mp_coeff_re <= 16'sd16384;
    mp_coeff_we <= 1'b1;
    @(posedge clk);
    mp_coeff_we <= 1'b0;
    mp_commit <= 1'b1;
    @(posedge clk);
    mp_commit <= 1'b0;
    @(posedge clk);
    if (mp_active_bank !== 1'b1) $fatal(1, "safe bank commit was not applied");
    $display("DPD protocol and safety PASS");
    $finish;
  end
endmodule

`default_nettype wire
