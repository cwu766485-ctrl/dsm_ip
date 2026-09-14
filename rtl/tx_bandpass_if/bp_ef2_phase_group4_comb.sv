// Four-sample combinational group for one polyphase of BP EFDSM2.
//
// For the frozen Fs/4 recurrence v[n] = x[n] - e[n-2], even and odd samples
// form two independent first-order recurrences. This block evaluates four
// samples of one phase and carries the phase error from one sample to the
// next.
`timescale 1ns/1ps
`default_nettype none

module bp_ef2_phase_group4_comb #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic signed [4*W_IN-1:0] x_vec,
  input  wire logic signed [ACC_W-1:0] state_in,
  output logic [3:0] y_vec,
  output logic signed [4*W_IN-1:0] y_signed_vec,
  output logic signed [ACC_W-1:0] state_out,
  output logic signed [ACC_W-1:0] v_state
);

  localparam int SUM_W = ACC_W + 1;
  localparam logic signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam logic signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam logic signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] state_work [0:3];
  logic signed [ACC_W-1:0] x_ext;
  logic signed [ACC_W-1:0] q_ext;
  logic signed [SUM_W-1:0] v_sum;
  logic signed [ACC_W-1:0] v_work [0:3];
  logic signed [ACC_W-1:0] e_work [0:3];
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
    state_work[0] = state_in;
    for (k = 0; k < 4; k = k + 1) begin
      x_ext = {{(ACC_W-W_IN){x_vec[k*W_IN+W_IN-1]}}, x_vec[k*W_IN +: W_IN]};
      v_sum = $signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) -
              $signed({{(SUM_W-ACC_W){state_work[k][ACC_W-1]}}, state_work[k]});
      v_work[k] = sat_acc(v_sum);
      y_vec[k] = (v_work[k] >= 0);
      y_signed_vec[k*W_IN +: W_IN] = y_vec[k] ? Y_POS : Y_NEG;
      q_ext = {{(ACC_W-W_IN){y_signed_vec[k*W_IN+W_IN-1]}},
               y_signed_vec[k*W_IN +: W_IN]};
      e_work[k] = v_work[k] - q_ext;
      if (k < 3) state_work[k+1] = e_work[k];
    end
    state_out = e_work[3];
    v_state = v_work[3];
  end
endmodule

`default_nettype wire
