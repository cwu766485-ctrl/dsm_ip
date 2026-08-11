//------------------------------------------------------------------------------
// Full-precision Fs/4 I/Q-to-real-IF mixer for the BPDSM route.
//
// The mixer runs before quantization.  Unlike duc_fs4_merge, it never selects
// an already one-bit low-pass DSM stream, so low-pass quantization noise cannot
// be translated into the desired IF band.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module bp_fs4_iq_mixer #(
  parameter int W = 16
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_in,
  input  wire logic signed [W-1:0] q_in,
  output logic out_valid,
  output logic signed [W-1:0] if_out,
  output logic [1:0] phase
);

  logic [1:0] phase_reg;
  logic [1:0] phase_out_reg;
  logic signed [W-1:0] if_next;

  always_comb begin
    unique case (phase_reg)
      2'd0: if_next = i_in;
      2'd1: if_next = q_in;
      2'd2: if_next = -i_in;
      2'd3: if_next = -q_in;
      default: if_next = '0;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      phase_reg <= 2'd0;
      phase_out_reg <= 2'd0;
      out_valid <= 1'b0;
      if_out <= '0;
    end else begin
      out_valid <= in_valid;
      if (in_valid) begin
        if_out <= if_next;
        // Keep the phase that generated if_out. phase_reg advances to the
        // next Fs/4 slot and must not be used to label this transaction.
        phase_out_reg <= phase_reg;
        phase_reg <= phase_reg + 2'd1;
      end
    end
  end

  assign phase = phase_out_reg;

endmodule

`default_nettype wire
