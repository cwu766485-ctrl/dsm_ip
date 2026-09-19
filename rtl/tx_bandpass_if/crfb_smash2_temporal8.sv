// Exact eight-sample composition of the fixed-point CRFB-SMASH2 transition.
// Lane 0 is the earliest sample and occupies x_word[W_IN-1:0].  This module
// is an 8-step state-map prototype, not a claim of a timing-safe 64-step core.
`timescale 1ns/1ps
`default_nettype none

module crfb_smash2_temporal8 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  // A synthesis-only depth knob used to measure exact causal-chain cost.
  // The normal temporal8 contract keeps STEPS=8.
  parameter int STEPS = 8
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic signed [8*W_IN-1:0] x_word,
  output logic [7:0] y1_word,
  output logic [7:0] y2_word,
  output logic signed [9*ACC_W-1:0] state_word
);
  localparam logic signed [ACC_W-1:0] ACC_MAX = {1'b0,{(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] ACC_MIN = {1'b1,{(ACC_W-1){1'b0}}};
  localparam logic signed [ACC_W-1:0] Q_POS = 28'sd32767;
  localparam logic signed [ACC_W-1:0] Q_NEG = -28'sd32767;

  logic signed [ACC_W-1:0] re1_r, kv1_r, re2_r;
  logic signed [ACC_W-1:0] e1d1_r, e1d2_r, e2d1_r, e2d2_r, v2d1_r, v2d2_r;
  logic signed [ACC_W-1:0] re1_n, kv1_n, re2_n;
  logic signed [ACC_W-1:0] e1d1_n, e1d2_n, e2d1_n, e2d2_n, v2d1_n, v2d2_n;
  logic [7:0] y1_n, y2_n;

  function automatic logic signed [ACC_W-1:0] sat_acc(
    input logic signed [ACC_W+2:0] value
  );
    logic signed [ACC_W+2:0] vmax, vmin;
    begin
      vmax = {{3{ACC_MAX[ACC_W-1]}},ACC_MAX};
      vmin = {{3{ACC_MIN[ACC_W-1]}},ACC_MIN};
      if (value > vmax) sat_acc = ACC_MAX;
      else if (value < vmin) sat_acc = ACC_MIN;
      else sat_acc = value[ACC_W-1:0];
    end
  endfunction

  always_comb begin : compose_eight_steps
    logic signed [ACC_W-1:0] re1, kv1, re2, e1d1, e1d2, e2d1, e2d2, v2d1, v2d2;
    logic signed [ACC_W-1:0] x, u1, u2, q1, q2, e1, e2, v2;
    logic signed [ACC_W+2:0] wide;
    re1=re1_r; kv1=kv1_r; re2=re2_r; e1d1=e1d1_r; e1d2=e1d2_r;
    e2d1=e2d1_r; e2d2=e2d2_r; v2d1=v2d1_r; v2d2=v2d2_r;
    y1_n='0; y2_n='0;
    for (int lane=0; lane<STEPS; lane++) begin
      x = {{(ACC_W-W_IN){x_word[lane*W_IN+W_IN-1]}},x_word[lane*W_IN +: W_IN]};
      // g=2,a=-1 => d=0 and a+1=0 in the checked MATLAB transition.
      wide = -$signed(e1d2); re1 = sat_acc(wide);
      wide = -$signed(v2d2); kv1 = sat_acc(wide);
      wide = $signed(x) - $signed(re1) + $signed(kv1); u1 = sat_acc(wide);
      y1_n[lane] = (u1 >= 0); q1 = y1_n[lane] ? Q_POS : Q_NEG;
      e1 = q1 - u1; // deliberate ACC_W wrap, matching the CRFB oracle
      wide = -$signed(e2d2); re2 = sat_acc(wide);
      wide = $signed(e1) - $signed(re2); u2 = sat_acc(wide);
      y2_n[lane] = (u2 >= 0); q2 = y2_n[lane] ? Q_POS : Q_NEG;
      e2 = q2 - u2; // deliberate ACC_W wrap, matching the CRFB oracle
      v2 = q2;
      e1d2=e1d1; e1d1=e1; e2d2=e2d1; e2d1=e2; v2d2=v2d1; v2d1=v2;
    end
    re1_n=re1; kv1_n=kv1; re2_n=re2; e1d1_n=e1d1; e1d2_n=e1d2;
    e2d1_n=e2d1; e2d2_n=e2d2; v2d1_n=v2d1; v2d2_n=v2d2;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      re1_r<='0; kv1_r<='0; re2_r<='0; e1d1_r<='0; e1d2_r<='0;
      e2d1_r<='0; e2d2_r<='0; v2d1_r<='0; v2d2_r<='0; y1_word<='0; y2_word<='0;
    end else if (enable) begin
      re1_r<=re1_n; kv1_r<=kv1_n; re2_r<=re2_n; e1d1_r<=e1d1_n; e1d2_r<=e1d2_n;
      e2d1_r<=e2d1_n; e2d2_r<=e2d2_n; v2d1_r<=v2d1_n; v2d2_r<=v2d2_n;
      y1_word<=y1_n; y2_word<=y2_n;
    end
  end

  always_comb state_word={re1_r,kv1_r,re2_r,e1d1_r,e1d2_r,e2d1_r,e2d2_r,v2d1_r,v2d2_r};
endmodule

`default_nettype wire
