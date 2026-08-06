//------------------------------------------------------------------------------
// Digital-IF BPDSM transmitter route.
//
// Complex baseband has already passed DPD and interpolation.  This block makes
// a full-precision real Fs/4 IF sample and only then applies one-bit BPDSM.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module tx_bp_if_top #(
  parameter int W = 16,
  parameter int ACC_W = 28,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1,
  parameter int BP_ALGORITHM = 1
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_in,
  input  wire logic signed [W-1:0] q_in,
  output wire logic if_valid,
  output wire logic signed [W-1:0] if_sample,
  output wire logic rf_valid,
  output wire logic rf_bit,
  output wire logic signed [W-1:0] rf_signed,
  output wire logic [1:0] if_phase
);

  logic signed [W-1:0] if_sample_reg;
  logic bp_valid;

  bp_fs4_iq_mixer #(.W(W)) u_mixer (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .i_in(i_in),
    .q_in(q_in),
    .out_valid(if_valid),
    .if_out(if_sample_reg),
    .phase(if_phase)
  );

  generate
    if (BP_ALGORITHM == 0) begin : g_bp_single
      logic signed [ACC_W-1:0] s1_state;
      logic signed [ACC_W-1:0] s2_state;
      dsm_core_bp_single #(
        .W_IN(W), .ACC_W(ACC_W), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)
      ) u_bp_dsm (
        .clk(clk), .rst_n(rst_n), .enable(if_valid), .x_in(if_sample_reg),
        .y_bit(rf_bit), .y_signed(rf_signed),
        .s1_state(s1_state), .s2_state(s2_state)
      );
    end else begin : g_bp_ef2
      logic signed [ACC_W-1:0] bp_state;
      dsm_core_bp_ef2 #(
        .W_IN(W), .ACC_W(ACC_W), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)
      ) u_bp_dsm (
        .clk(clk), .rst_n(rst_n), .enable(if_valid), .x_in(if_sample_reg),
        .y_bit(rf_bit), .y_signed(rf_signed), .v_state(bp_state)
      );
    end
  endgenerate

  // BPDSM consumes the registered IF sample on the following edge, so valid
  // follows the same one-cycle boundary as the registered one-bit output.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bp_valid <= 1'b0;
    end else begin
      bp_valid <= if_valid;
    end
  end

  assign if_sample = if_sample_reg;
  assign rf_valid = bp_valid;

endmodule

`default_nettype wire
