//------------------------------------------------------------------------------
// Combinational group of eight consecutive BP EFDSM2 samples.
//
// This block is used as one stage of the pipelined 64-sample implementation.
// It evaluates only eight feedback updates; the next group receives the
// resulting state through a pipeline register.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module bp_ef2_group8_comb #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic signed [8*W_IN-1:0] x_vec,
  input  wire logic signed [ACC_W-1:0] e1_in,
  input  wire logic signed [ACC_W-1:0] e2_in,
  output logic [7:0] y_vec,
  output logic signed [8*W_IN-1:0] y_signed_vec,
  output logic signed [ACC_W-1:0] e1_out,
  output logic signed [ACC_W-1:0] e2_out,
  output logic signed [ACC_W-1:0] v_state
);

  localparam int SUM_W = ACC_W + 2;
  localparam logic signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam logic signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam logic signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] e1_work [0:7];
  logic signed [ACC_W-1:0] e2_work [0:7];
  logic signed [ACC_W-1:0] y_work [0:7];
  logic signed [ACC_W-1:0] e_work [0:7];
  logic signed [ACC_W-1:0] x_ext;
  logic signed [ACC_W-1:0] q_ext;
  logic signed [SUM_W-1:0] y_sum;
  integer k;

  function automatic logic signed [ACC_W-1:0] sat_acc(
    input logic signed [SUM_W-1:0] value
  );
    begin
      if (!SATURATE) begin
        sat_acc = value[ACC_W-1:0];
      end else if (value > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) begin
        sat_acc = V_MAX;
      end else if (value < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN})) begin
        sat_acc = V_MIN;
      end else begin
        sat_acc = value[ACC_W-1:0];
      end
    end
  endfunction

  always_comb begin
    y_vec = '0;
    y_signed_vec = '0;
    e1_work[0] = e1_in;
    e2_work[0] = e2_in;
    for (k = 0; k < 8; k = k + 1) begin
      x_ext = {{(ACC_W-W_IN){x_vec[k*W_IN+W_IN-1]}}, x_vec[k*W_IN +: W_IN]};
      y_sum = $signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) -
              $signed({{(SUM_W-ACC_W){e2_work[k][ACC_W-1]}}, e2_work[k]});
      y_work[k] = sat_acc(y_sum);
      y_vec[k] = (y_work[k] >= 0);
      y_signed_vec[k*W_IN +: W_IN] = y_vec[k] ? Y_POS : Y_NEG;
      q_ext = {{(ACC_W-W_IN){y_signed_vec[k*W_IN+W_IN-1]}},
               y_signed_vec[k*W_IN +: W_IN]};
      e_work[k] = y_work[k] - q_ext;
      if (k < 7) begin
        e1_work[k+1] = e_work[k];
        e2_work[k+1] = e1_work[k];
      end
    end
    e1_out = e_work[7];
    e2_out = e1_work[7];
    v_state = y_work[7];
  end

endmodule

`default_nettype wire
