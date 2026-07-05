`timescale 1ns/1ps
`default_nettype none

module dsm_interp_frontend #(
  parameter int W_IN = 16,
  parameter int W_OUT = 16,
  parameter int INTERP_MODE = 0
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

  generate
    if (INTERP_MODE == 0) begin : g_bypass
      assign in_ready = out_ready;
      assign i_out = i_in;
      assign q_out = q_in;
      assign out_valid = enable && in_valid;
    end else if (INTERP_MODE == 4) begin : g_mode4
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
        (INTERP_MODE == 1) ? 2 :
        (INTERP_MODE == 2) ? 3 :
        (INTERP_MODE == 3) ? 4 : 0;

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
