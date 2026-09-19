//------------------------------------------------------------------------------
// Multi-output serializer/PA boundary for the existing MASH 1-1 core.
//
// It preserves both one-bit stage streams and the exact {-3,-1,+1,+3}
// combiner code.  It is a research interface for a multi-PA transmitter and
// deliberately does not hard-limit the combiner into the legacy raw-GTH path.
// This wrapper is not the Xu CRFB-SMASH architecture.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module mash11_multipa_tx #(
  parameter int W = 16,
  parameter int ACC_W = 28,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] if_sample,
  output logic out_valid,
  output wire logic pa_stage1_bit,
  output wire logic pa_stage2_bit,
  output wire logic signed [2:0] combined_level
);
  logic y_bit_unused;
  logic signed [ACC_W-1:0] v1_unused, v2_unused;

  dsm_core_mash11 #(
    .W_IN(W), .ACC_W(ACC_W), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)
  ) u_mash11 (
    .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(if_sample),
    .y_bit(y_bit_unused), .y1_bit(pa_stage1_bit), .y2_bit(pa_stage2_bit),
    .y_mash_signed(combined_level), .v1_state(v1_unused), .v2_state(v2_unused)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 1'b0;
    else out_valid <= in_valid;
  end
endmodule

`default_nettype wire
