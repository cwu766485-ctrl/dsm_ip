//------------------------------------------------------------------------------
// File: duc_nco_mix_signed.v  (Verilog-2001)
// Description:
//   NCO-based complex upconversion (arbitrary IF) to a single real signed stream.
//
//   rf[n] = I[n]*cos(phase[n]) - Q[n]*sin(phase[n])
//   phase[n+1] = phase[n] + phase_inc
//
// Notes:
//   - LUT is auto-generated in simulation (guarded by `ifndef SYNTHESIS).
//   - For synthesis/ASIC, replace LUT init with ROM or CORDIC.
//   - in_valid is delayed by 1 cycle internally to align with registered upstream,
//     mirroring duc_fs4_merge(_signed) behavior.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module duc_nco_mix_signed #(
  parameter integer W_IN   = 4,
  parameter integer W_OUT  = 16,
  parameter integer PHASE_W = 24,
  parameter integer LUT_AW  = 10,   // 2^LUT_AW entries
  parameter integer TW_W    = 16,   // sin/cos twiddle width (Q1.(TW_W-1))
  parameter         HOLD_LAST_WHEN_INVALID = 1'b1
) (
  input  wire                     clk,
  input  wire                     rst_n,
  input  wire                     in_valid,
  input  wire [PHASE_W-1:0]       phase_inc,
  input  wire signed [W_IN-1:0]   i_data,
  input  wire signed [W_IN-1:0]   q_data,

  output reg                      rf_valid,
  output reg signed [W_OUT-1:0]   rf_signed,
  output wire [PHASE_W-1:0]       phase_acc_dbg
);

  localparam integer LUT_DEPTH = (1 << LUT_AW);
  localparam integer MULT_W = W_IN + TW_W;
  localparam integer MIX_W  = MULT_W + 1;

  reg in_valid_d1;
  reg [PHASE_W-1:0] phase_acc;
  wire [LUT_AW-1:0] lut_addr;

  reg signed [TW_W-1:0] cos_lut [0:LUT_DEPTH-1];
  reg signed [TW_W-1:0] sin_lut [0:LUT_DEPTH-1];
  wire signed [TW_W-1:0] c;
  wire signed [TW_W-1:0] s;

  reg signed [MULT_W-1:0] i_mul_c;
  reg signed [MULT_W-1:0] q_mul_s;
  reg signed [MIX_W-1:0]  mix_full;
  reg signed [MIX_W-1:0]  mix_scaled;
  wire signed [W_OUT-1:0] mix_out;

`ifndef SYNTHESIS
  integer ii;
  real ang;
  real cs;
  real sn;
  initial begin
    for (ii = 0; ii < LUT_DEPTH; ii = ii + 1) begin
      ang = 2.0 * 3.14159265358979323846 * (ii * 1.0) / (LUT_DEPTH * 1.0);
      cs = $cos(ang);
      sn = $sin(ang);
      cos_lut[ii] = $rtoi(cs * ((1 << (TW_W-1)) - 1));
      sin_lut[ii] = $rtoi(sn * ((1 << (TW_W-1)) - 1));
    end
  end
`endif

  assign lut_addr = phase_acc[PHASE_W-1:PHASE_W-LUT_AW];
  assign c = cos_lut[lut_addr];
  assign s = sin_lut[lut_addr];

  always @* begin
    i_mul_c = i_data * c;
    q_mul_s = q_data * s;
    mix_full = $signed({1'b0, i_mul_c}) - $signed({1'b0, q_mul_s});
    mix_scaled = mix_full >>> (TW_W-1);
  end

  generate
    if (W_OUT >= MIX_W) begin : gen_mix_extend
      assign mix_out = {{(W_OUT-MIX_W){mix_scaled[MIX_W-1]}}, mix_scaled};
    end else begin : gen_mix_trunc
      assign mix_out = mix_scaled[W_OUT-1:0];
    end
  endgenerate

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_valid_d1 <= 1'b0;
      rf_valid    <= 1'b0;
      rf_signed   <= {W_OUT{1'b0}};
      phase_acc   <= {PHASE_W{1'b0}};
    end else begin
      in_valid_d1 <= in_valid;
      rf_valid    <= in_valid_d1;

      if (in_valid_d1) begin
        rf_signed <= mix_out;
        phase_acc <= phase_acc + phase_inc;
      end else if (!HOLD_LAST_WHEN_INVALID) begin
        rf_signed <= {W_OUT{1'b0}};
      end
    end
  end

  assign phase_acc_dbg = phase_acc;

endmodule

`default_nettype wire

