// Exact two-phase polyphase implementation of the Fs/4 BP EFDSM2 recurrence.
//
// The frozen BP EFDSM2 equation is:
//   v[n] = x[n] - e[n-2]
//   q[n] = sign(v[n]) * (2^(W_IN-1)-1)
//   e[n] = v[n] - q[n]
//
// Since the feedback delay is two samples, the even and odd subsequences are
// independent first-order recurrences. The outputs are interleaved back into
// the original temporal order. This is an exact temporal transform, unlike
// instantiating independent DSMs with unrelated input contexts.
`timescale 1ns/1ps
`default_nettype none

module bp_ef2_polyphase2 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         enable,
  input  wire logic [64*W_IN-1:0]            x_vec,
  output logic [63:0]                       y_vec,
  output logic signed [64*W_IN-1:0]         y_signed_vec,
  output logic                              out_valid,
  output logic signed [ACC_W-1:0]           v_state
);

  localparam int PHASE_SAMPLES = 32;
  localparam int SUM_W = ACC_W + 1;
  localparam logic signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam logic signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam logic signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] even_state;
  logic signed [ACC_W-1:0] odd_state;
  logic signed [ACC_W-1:0] even_work [0:PHASE_SAMPLES-1];
  logic signed [ACC_W-1:0] odd_work [0:PHASE_SAMPLES-1];
  logic signed [ACC_W-1:0] even_v [0:PHASE_SAMPLES-1];
  logic signed [ACC_W-1:0] odd_v [0:PHASE_SAMPLES-1];
  logic signed [ACC_W-1:0] even_error [0:PHASE_SAMPLES-1];
  logic signed [ACC_W-1:0] odd_error [0:PHASE_SAMPLES-1];
  logic signed [ACC_W-1:0] even_x [0:PHASE_SAMPLES-1];
  logic signed [ACC_W-1:0] odd_x [0:PHASE_SAMPLES-1];
  logic signed [ACC_W-1:0] even_q [0:PHASE_SAMPLES-1];
  logic signed [ACC_W-1:0] odd_q [0:PHASE_SAMPLES-1];
  logic even_bit [0:PHASE_SAMPLES-1];
  logic odd_bit [0:PHASE_SAMPLES-1];
  logic signed [SUM_W-1:0] even_sum;
  logic signed [SUM_W-1:0] odd_sum;
  logic [63:0] y_vec_c;
  logic signed [64*W_IN-1:0] y_signed_vec_c;
  logic signed [ACC_W-1:0] even_state_c;
  logic signed [ACC_W-1:0] odd_state_c;
  logic signed [ACC_W-1:0] v_state_c;

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

  integer p;
  always_comb begin
    y_vec_c = '0;
    y_signed_vec_c = '0;
    even_work[0] = even_state;
    odd_work[0] = odd_state;

    for (p = 0; p < PHASE_SAMPLES; p = p + 1) begin
      even_x[p] = {{(ACC_W-W_IN){x_vec[(2*p)*W_IN+W_IN-1]}},
                   x_vec[(2*p)*W_IN +: W_IN]};
      odd_x[p] = {{(ACC_W-W_IN){x_vec[(2*p+1)*W_IN+W_IN-1]}},
                  x_vec[(2*p+1)*W_IN +: W_IN]};

      even_sum = $signed({{(SUM_W-ACC_W){even_x[p][ACC_W-1]}}, even_x[p]}) -
                 $signed({{(SUM_W-ACC_W){even_work[p][ACC_W-1]}}, even_work[p]});
      odd_sum = $signed({{(SUM_W-ACC_W){odd_x[p][ACC_W-1]}}, odd_x[p]}) -
                $signed({{(SUM_W-ACC_W){odd_work[p][ACC_W-1]}}, odd_work[p]});
      even_v[p] = sat_acc(even_sum);
      odd_v[p] = sat_acc(odd_sum);
      even_bit[p] = (even_v[p] >= 0);
      odd_bit[p] = (odd_v[p] >= 0);
      even_q[p] = even_bit[p] ? {{(ACC_W-W_IN){Y_POS[W_IN-1]}}, Y_POS} :
                                {{(ACC_W-W_IN){Y_NEG[W_IN-1]}}, Y_NEG};
      odd_q[p] = odd_bit[p] ? {{(ACC_W-W_IN){Y_POS[W_IN-1]}}, Y_POS} :
                              {{(ACC_W-W_IN){Y_NEG[W_IN-1]}}, Y_NEG};
      even_error[p] = even_v[p] - even_q[p];
      odd_error[p] = odd_v[p] - odd_q[p];
      y_vec_c[2*p] = even_bit[p];
      y_vec_c[2*p+1] = odd_bit[p];
      y_signed_vec_c[(2*p)*W_IN +: W_IN] = even_bit[p] ? Y_POS : Y_NEG;
      y_signed_vec_c[(2*p+1)*W_IN +: W_IN] = odd_bit[p] ? Y_POS : Y_NEG;
      if (p < PHASE_SAMPLES-1) begin
        even_work[p+1] = even_error[p];
        odd_work[p+1] = odd_error[p];
      end
    end
    even_state_c = even_error[PHASE_SAMPLES-1];
    odd_state_c = odd_error[PHASE_SAMPLES-1];
    v_state_c = odd_v[PHASE_SAMPLES-1];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      even_state <= '0;
      odd_state <= '0;
      y_vec <= {64{1'b1}};
      y_signed_vec <= {64{Y_POS}};
      v_state <= '0;
      out_valid <= 1'b0;
    end else if (enable) begin
      even_state <= even_state_c;
      odd_state <= odd_state_c;
      y_vec <= y_vec_c;
      y_signed_vec <= y_signed_vec_c;
      v_state <= v_state_c;
      out_valid <= 1'b1;
    end else begin
      out_valid <= 1'b0;
    end
  end
endmodule

`default_nettype wire
