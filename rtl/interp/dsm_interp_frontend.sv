`timescale 1ns/1ps
`default_nettype none

module dsm_interp_frontend #(
  parameter int W_IN = 16,
  parameter int W_OUT = 16,
  parameter int INTERP_MODE = 0,
  // x32 only: 0=I0 staged CIC-equivalent FIR, 1=I1 direct CIC,
  // 2=I2 monolithic x32 FIR, 3=I3 polyphase CIC-equivalent FIR.
  parameter int INTERP_IMPL = 0
) (
  input  wire                     clk,
  input  wire                     rst_n,
  input  wire                     enable,
  input  wire signed [W_IN-1:0]   i_in,
  input  wire signed [W_IN-1:0]   q_in,
  input  wire                     in_valid,
  output wire                     in_ready,
  output wire signed [W_OUT-1:0]  i_out,
  output wire signed [W_OUT-1:0]  q_out,
  output wire                     out_valid,
  input  wire                     out_ready
);

  // Compile-time interpolation modes. These values are part of the public IP
  // configuration contract and must remain stable.
  localparam integer INTERP_MODE_BYPASS = 0;
  localparam integer INTERP_MODE_X4     = 1;
  localparam integer INTERP_MODE_X8     = 2;
  localparam integer INTERP_MODE_X16    = 3;
  localparam integer INTERP_MODE_X32    = 4;

  // x32 implementation alternatives selected only with INTERP_MODE_X32.
  localparam integer INTERP_IMPL_CIC_EQ_FIR = 0;
  localparam integer INTERP_IMPL_DIRECT_CIC = 1;
  localparam integer INTERP_IMPL_X32_POLY   = 2;
  localparam integer INTERP_IMPL_X8_POLY    = 3;

  generate
    if (INTERP_MODE == INTERP_MODE_BYPASS) begin : g_bypass
      assign in_ready = out_ready;
      assign i_out = i_in;
      assign q_out = q_in;
      assign out_valid = enable && in_valid;
    end else if ((INTERP_MODE == INTERP_MODE_X32) &&
                 (INTERP_IMPL == INTERP_IMPL_X32_POLY)) begin : g_i2_mode4
      dsm_interp_fir_i2_polyphase #(
        .W_IN(W_IN), .W_OUT(W_OUT)
      ) u_i2_i (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .in_data(i_in), .in_valid(in_valid), .in_ready(in_ready),
        .out_data(i_out), .out_valid(out_valid), .out_ready(out_ready)
      );
      dsm_interp_fir_i2_polyphase #(
        .W_IN(W_IN), .W_OUT(W_OUT)
      ) u_i2_q (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .in_data(q_in), .in_valid(in_valid), .in_ready(),
        .out_data(q_out), .out_valid(), .out_ready(out_ready)
      );
    end else if (INTERP_MODE == INTERP_MODE_X32) begin : g_mode4
      wire signed [W_OUT-1:0] si [0:4];
      wire signed [W_OUT-1:0] sq [0:4];
      wire                    sv [0:4];
      wire                    sr [0:4];

      assign si[0] = i_in;
      assign sq[0] = q_in;
      assign sv[0] = in_valid;
      assign in_ready = sr[0];

      for (genvar s = 0; s < 2; s = s + 1) begin : g_hb_stage
        dsm_interp2_halfband #(.W_IN(W_OUT), .W_OUT(W_OUT)) u_i (
          .clk(clk), .rst_n(rst_n), .enable(enable),
          .in_data(si[s]), .in_valid(sv[s]), .in_ready(sr[s]),
          .out_data(si[s+1]), .out_valid(sv[s+1]), .out_ready(sr[s+1])
        );
        dsm_interp2_halfband #(.W_IN(W_OUT), .W_OUT(W_OUT)) u_q (
          .clk(clk), .rst_n(rst_n), .enable(enable),
          .in_data(sq[s]), .in_valid(sv[s]), .in_ready(),
          .out_data(sq[s+1]), .out_valid(), .out_ready(sr[s+1])
        );
      end

      if (INTERP_IMPL == INTERP_IMPL_DIRECT_CIC) begin : g_i1_direct_cic
        dsm_interp_cic_direct #(
          .W_IN(W_OUT), .W_OUT(W_OUT), .RATE(8), .ORDER(4)
        ) u_cic_i (
          .clk(clk), .rst_n(rst_n), .enable(enable),
          .in_data(si[2]), .in_valid(sv[2]), .in_ready(sr[2]),
          .out_data(si[3]), .out_valid(sv[3]), .out_ready(sr[3])
        );
        dsm_interp_cic_direct #(
          .W_IN(W_OUT), .W_OUT(W_OUT), .RATE(8), .ORDER(4)
        ) u_cic_q (
          .clk(clk), .rst_n(rst_n), .enable(enable),
          .in_data(sq[2]), .in_valid(sv[2]), .in_ready(),
          .out_data(sq[3]), .out_valid(), .out_ready(sr[3])
        );
      end else if (INTERP_IMPL == INTERP_IMPL_X8_POLY) begin : g_i3_polyphase
        dsm_interp_fir_polyphase #(
          .W_IN(W_OUT), .W_OUT(W_OUT), .NTAPS(29), .INTERP(8)
        ) u_cic_i (
          .clk(clk), .rst_n(rst_n), .enable(enable),
          .in_data(si[2]), .in_valid(sv[2]), .in_ready(sr[2]),
          .out_data(si[3]), .out_valid(sv[3]), .out_ready(sr[3])
        );
        dsm_interp_fir_polyphase #(
          .W_IN(W_OUT), .W_OUT(W_OUT), .NTAPS(29), .INTERP(8)
        ) u_cic_q (
          .clk(clk), .rst_n(rst_n), .enable(enable),
          .in_data(sq[2]), .in_valid(sv[2]), .in_ready(),
          .out_data(sq[3]), .out_valid(), .out_ready(sr[3])
        );
      end else begin : g_i0_cic_equiv
        dsm_interp_fir_fixed #(
          .W_IN(W_OUT), .W_OUT(W_OUT), .NTAPS(29), .INTERP(8), .COEFF_SET(2)
        ) u_cic_i (
          .clk(clk), .rst_n(rst_n), .enable(enable),
          .in_data(si[2]), .in_valid(sv[2]), .in_ready(sr[2]),
          .out_data(si[3]), .out_valid(sv[3]), .out_ready(sr[3])
        );
        dsm_interp_fir_fixed #(
          .W_IN(W_OUT), .W_OUT(W_OUT), .NTAPS(29), .INTERP(8), .COEFF_SET(2)
        ) u_cic_q (
          .clk(clk), .rst_n(rst_n), .enable(enable),
          .in_data(sq[2]), .in_valid(sv[2]), .in_ready(),
          .out_data(sq[3]), .out_valid(), .out_ready(sr[3])
        );
      end

      dsm_interp_fir_fixed #(
        .W_IN(W_OUT), .W_OUT(W_OUT), .NTAPS(63), .INTERP(1), .COEFF_SET(3)
      ) u_comp_i (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .in_data(si[3]), .in_valid(sv[3]), .in_ready(sr[3]),
        .out_data(si[4]), .out_valid(sv[4]), .out_ready(sr[4])
      );
      dsm_interp_fir_fixed #(
        .W_IN(W_OUT), .W_OUT(W_OUT), .NTAPS(63), .INTERP(1), .COEFF_SET(3)
      ) u_comp_q (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .in_data(sq[3]), .in_valid(sv[3]), .in_ready(),
        .out_data(sq[4]), .out_valid(), .out_ready(sr[4])
      );

      assign sr[4] = out_ready;
      assign i_out = si[4];
      assign q_out = sq[4];
      assign out_valid = sv[4];
    end else begin : g_hb
      localparam int NSTAGES =
        (INTERP_MODE == INTERP_MODE_X4)  ? 2 :
        (INTERP_MODE == INTERP_MODE_X8)  ? 3 :
        (INTERP_MODE == INTERP_MODE_X16) ? 4 : 0;

      wire signed [W_OUT-1:0] si [0:NSTAGES];
      wire signed [W_OUT-1:0] sq [0:NSTAGES];
      wire                    sv [0:NSTAGES];
      wire                    sr [0:NSTAGES];

      assign si[0] = i_in;
      assign sq[0] = q_in;
      assign sv[0] = in_valid;
      assign in_ready = sr[0];

      for (genvar s = 0; s < NSTAGES; s = s + 1) begin : g_stage
        dsm_interp2_halfband #(
          .W_IN(W_OUT),
          .W_OUT(W_OUT)
        ) u_i (
          .clk(clk),
          .rst_n(rst_n),
          .enable(enable),
          .in_data(si[s]),
          .in_valid(sv[s]),
          .in_ready(sr[s]),
          .out_data(si[s+1]),
          .out_valid(sv[s+1]),
          .out_ready(sr[s+1])
        );

        dsm_interp2_halfband #(
          .W_IN(W_OUT),
          .W_OUT(W_OUT)
        ) u_q (
          .clk(clk),
          .rst_n(rst_n),
          .enable(enable),
          .in_data(sq[s]),
          .in_valid(sv[s]),
          .in_ready(),
          .out_data(sq[s+1]),
          .out_valid(),
          .out_ready(sr[s+1])
        );
      end

      assign sr[NSTAGES] = out_ready;
      assign i_out = si[NSTAGES];
      assign q_out = sq[NSTAGES];
      assign out_valid = sv[NSTAGES];
    end
  endgenerate
endmodule

`default_nettype wire
