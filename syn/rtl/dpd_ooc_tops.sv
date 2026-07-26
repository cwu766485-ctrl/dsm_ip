`timescale 1ns/1ps
`default_nettype none

// Fixed-function OOC tops.  They intentionally avoid the runtime DPD mux so
// each report measures the selected implementation only.
module dpd_bypass_ooc_top #(
  parameter integer W = 16
) (
  input wire clk, input wire rst_n, input wire signed [W-1:0] i_in,
  input wire signed [W-1:0] q_in, input wire in_valid,
  output reg signed [W-1:0] i_out, output reg signed [W-1:0] q_out,
  output reg out_valid
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin i_out <= '0; q_out <= '0; out_valid <= 1'b0; end
    else begin i_out <= i_in; q_out <= q_in; out_valid <= in_valid; end
  end
endmodule

module dpd_poly_ooc_top #(
  parameter integer POLY_ORDER = 5
) (
  input wire clk, input wire rst_n, input wire signed [15:0] i_in,
  input wire signed [15:0] q_in, input wire in_valid,
  output wire signed [15:0] i_out, output wire signed [15:0] q_out,
  output wire out_valid
);
  dpd_poly #(.POLY_ORDER(POLY_ORDER)) u_dut (
    .clk(clk), .rst_n(rst_n), .enable(1'b1),
    .c1_re(16'sd16384), .c1_im(16'sd0), .c3_re(16'sd0), .c3_im(16'sd0),
    .c5_re(16'sd0), .c5_im(16'sd0), .c7_re(16'sd0), .c7_im(16'sd0),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(1'b1),
    .sample_count(), .saturation_count()
  );
endmodule

module dpd_lut_ooc_top #(
  parameter integer LUT_AW = 4
) (
  input wire clk, input wire rst_n, input wire signed [15:0] i_in,
  input wire signed [15:0] q_in,
  output wire signed [15:0] i_out, output wire signed [15:0] q_out
);
  dpd_lut #(.LUT_AW(LUT_AW)) u_dut (
    .clk(clk), .rst_n(rst_n), .lut_we(1'b0), .lut_commit(1'b0),
    .lut_waddr('0), .lut_wgain_re(16'sd16384), .lut_wgain_im(16'sd0),
    .lut_raddr('0), .lut_rgain_re(), .lut_rgain_im(), .active_bank(),
    .i_in(i_in), .q_in(q_in), .i_out(i_out), .q_out(q_out), .sat()
  );
endmodule

module dpd_memory_poly_ooc_top #(
  parameter integer MAX_TAPS = 4
) (
  input wire clk, input wire rst_n, input wire signed [15:0] i_in,
  input wire signed [15:0] q_in, input wire in_valid,
  output wire signed [15:0] i_out, output wire signed [15:0] q_out,
  output wire out_valid
);
  localparam integer CW = MAX_TAPS * 16;
  localparam [2:0] ACTIVE_TAPS = MAX_TAPS;
  dpd_memory_poly #(.MAX_TAPS(MAX_TAPS)) u_dut (
    .clk(clk), .rst_n(rst_n), .active_taps(ACTIVE_TAPS),
    .c1_re({{(MAX_TAPS-1){16'sd0}},16'sd16384}), .c1_im('0),
    .c3_re('0), .c3_im('0), .c5_re('0), .c5_im('0),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(1'b1),
    .sample_count(), .saturation_count()
  );
endmodule

`default_nettype wire
