`timescale 1ns/1ps
`default_nettype none

module dpd_memory_poly_ooc_top (
  input  wire                         clk,
  input  wire                         rst_n,
  input  wire [2:0]                   active_taps,
  input  wire signed [63:0]           c1_re,
  input  wire signed [63:0]           c1_im,
  input  wire signed [63:0]           c3_re,
  input  wire signed [63:0]           c3_im,
  input  wire signed [63:0]           c5_re,
  input  wire signed [63:0]           c5_im,
  input  wire signed [15:0]           i_in,
  input  wire signed [15:0]           q_in,
  input  wire                         in_valid,
  output wire                         in_ready,
  output wire signed [15:0]           i_out,
  output wire signed [15:0]           q_out,
  output wire                         out_valid,
  input  wire                         out_ready,
  output wire [31:0]                  sample_count,
  output wire [31:0]                  saturation_count
);

  dpd_memory_poly #(
    .W(16), .COEFF_W(16), .COEFF_FRAC(14), .MAX_TAPS(4)
  ) u_memory_poly (
    .clk(clk), .rst_n(rst_n), .active_taps(active_taps),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .i_in(i_in), .q_in(q_in),
    .in_valid(in_valid), .in_ready(in_ready), .i_out(i_out), .q_out(q_out),
    .out_valid(out_valid), .out_ready(out_ready), .sample_count(sample_count),
    .saturation_count(saturation_count)
  );
endmodule

`default_nettype wire
