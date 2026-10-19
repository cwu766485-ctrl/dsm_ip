`timescale 1ns/1ps
// Reset synchronizer properties. Runtime reset requests change on the
// inactive edge; active-edge collisions are outside this proof model.
module thermo5_reset_gap_harness(input logic clk, boot_n, reset_request);
  logic arst_n;
  wire srst_n;
  always @(negedge clk or negedge boot_n)
    if (!boot_n) arst_n <= 1'b0;
    else arst_n <= !reset_request;
  dsm_reset_sync dut(.clk(clk),.arst_n(arst_n),.srst_n(srst_n));
  default clocking cb @(posedge clk); endclocking
  a_reset_low_clears_stage0: assert property (!arst_n |-> !dut.sync_q[0]);
  a_reset_low_clears_output: assert property (!arst_n |-> !srst_n);
  a_stage0_required_for_output: assert property (srst_n |-> dut.sync_q[0]);
  c_reset_held: cover property (!arst_n && !dut.sync_q[0]);
  c_first_release_sample: cover property (arst_n && !dut.sync_q[0]);
  c_released: cover property (arst_n && srst_n);
  c_runtime_reassert: cover property (srst_n ##1 !arst_n ##1 arst_n ##2 srst_n);
  // Expected unreachable: the red URG 1/0 operand combination.
  c_collision_bin: cover property (!arst_n && dut.sync_q[0]);
endmodule
