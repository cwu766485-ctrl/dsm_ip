`timescale 1ns/1ps
`default_nettype none

// Focused reset synchronizer audit. The instance path intentionally matches
// the frozen thermo5 DUT's u_cdc.u_{s,c}_reset hierarchy so URG reports the
// same reset synchronizer instances while this top exercises only the exact
// shared RTL block.
module thermo5_sku_uvm_tb;
  logic s_clk = 1'b0;
  logic c_clk = 1'b0;
  logic s_arst_n = 1'b0;
  logic c_arst_n = 1'b0;
  logic s_srst_n;
  logic c_srst_n;
  int s_reset_low_stage0_samples = 0;
  int c_reset_low_stage0_samples = 0;

  always #4.000 s_clk = ~s_clk;
  always #2.286 c_clk = ~c_clk;

  thermo5_reset_audit_dut dut (
    .s_clk(s_clk), .s_arst_n(s_arst_n), .s_srst_n(s_srst_n),
    .c_clk(c_clk), .c_arst_n(c_arst_n), .c_srst_n(c_srst_n)
  );

  // Sample the exact condition operands in the same active region as the
  // RTL assertion. A legal asynchronous assertion clears stage 0 before the
  // next local rising edge, so the open 1/0 pair should remain unsampled.
  always @(posedge s_clk)
    if (!s_arst_n && dut.u_cdc.u_s_reset.sync_q[0])
      s_reset_low_stage0_samples++;
  always @(posedge c_clk)
    if (!c_arst_n && dut.u_cdc.u_c_reset.sync_q[0])
      c_reset_low_stage0_samples++;

  task automatic check_async_assertion(input string label);
    #0.100;
    if (s_srst_n !== 1'b0 || c_srst_n !== 1'b0 ||
        dut.u_cdc.u_s_reset.sync_q !== 2'b00 ||
        dut.u_cdc.u_c_reset.sync_q !== 2'b00)
      $fatal(1, "%s: asynchronous assertion did not clear both reset epochs", label);
  endtask

  initial begin
    // Initial asserted epoch; each synchronizer must hold reset active.
    repeat (3) @(posedge s_clk);
    repeat (3) @(posedge c_clk);
    check_async_assertion("initial");

    // Release away from either active edge and verify each local clock's
    // first edge shifts stage 0 only, while the second releases srst_n.
    @(negedge s_clk); #0.500; s_arst_n = 1'b1;
    @(posedge s_clk); #0.100;
    if (dut.u_cdc.u_s_reset.sync_q !== 2'b01 || s_srst_n !== 1'b0)
      $fatal(1, "source reset released before its second local edge");
    @(posedge s_clk); #0.100;
    if (dut.u_cdc.u_s_reset.sync_q !== 2'b11 || s_srst_n !== 1'b1)
      $fatal(1, "source reset did not release on its second local edge");

    @(negedge c_clk); #0.500; c_arst_n = 1'b1;
    @(posedge c_clk); #0.100;
    if (dut.u_cdc.u_c_reset.sync_q !== 2'b01 || c_srst_n !== 1'b0)
      $fatal(1, "core reset released before its second local edge");
    @(posedge c_clk); #0.100;
    if (dut.u_cdc.u_c_reset.sync_q !== 2'b11 || c_srst_n !== 1'b1)
      $fatal(1, "core reset did not release on its second local edge");

    // Reassert asynchronously between local edges after both stage-0 bits
    // have reached one. Verify both outputs assert before another clock edge.
    @(negedge s_clk); #0.500; s_arst_n = 1'b0;
    @(negedge c_clk); #0.500; c_arst_n = 1'b0;
    check_async_assertion("reassertion");
    repeat (3) @(posedge s_clk);
    repeat (3) @(posedge c_clk);
    #0.100;
    if (s_reset_low_stage0_samples != 0 || c_reset_low_stage0_samples != 0)
      $fatal(1, "sampled reset-low/stage0-high condition; reset scheduling must be reviewed");

    $display("RESET_SYNC_AUDIT_PASS source_epochs=2 core_epochs=2 source_release_edges=2 core_release_edges=2 source_1_0_samples=%0d core_1_0_samples=%0d",
      s_reset_low_stage0_samples, c_reset_low_stage0_samples);
    $finish;
  end
endmodule

module thermo5_reset_audit_dut (
  input wire logic s_clk, s_arst_n,
  output wire logic s_srst_n,
  input wire logic c_clk, c_arst_n,
  output wire logic c_srst_n
);
  thermo5_reset_audit_cdc u_cdc (
    .s_clk(s_clk), .s_arst_n(s_arst_n), .s_srst_n(s_srst_n),
    .c_clk(c_clk), .c_arst_n(c_arst_n), .c_srst_n(c_srst_n)
  );
endmodule

module thermo5_reset_audit_cdc (
  input wire logic s_clk, s_arst_n,
  output wire logic s_srst_n,
  input wire logic c_clk, c_arst_n,
  output wire logic c_srst_n
);
  dsm_reset_sync u_s_reset (.clk(s_clk), .arst_n(s_arst_n), .srst_n(s_srst_n));
  dsm_reset_sync u_c_reset (.clk(c_clk), .arst_n(c_arst_n), .srst_n(c_srst_n));
endmodule

`default_nettype wire
